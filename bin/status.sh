#!/bin/bash
# Fub Status Dashboard
# Real-time system health monitoring for Ubuntu
# Inspired by Mole's mo status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ============================================================================
# System Metrics Collection Functions
# ============================================================================

# Get CPU usage percentage
get_cpu_usage() {
    local idle=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print $8}' | cut -d'%' -f1)
    if [[ -n "$idle" ]]; then
        awk "BEGIN {printf \"%.1f\", 100 - $idle}"
    else
        echo "0.0"
    fi
}

# Get load averages
get_load_average() {
    cat /proc/loadavg | awk '{print $1, $2, $3}'
}

# Get CPU core count
get_cpu_cores() {
    grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
}

# Get CPU temperature
get_cpu_temp() {
    local temp=""
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
        temp=$(awk "BEGIN {printf \"%.1f\", $temp_raw / 1000}")
    elif command -v sensors &>/dev/null; then
        temp=$(sensors 2>/dev/null | grep -i "Core 0" | awk '{print $3}' | sed 's/+//;s/°C//' | head -1)
    fi

    if [[ -n "$temp" && "$temp" != "0.0" ]]; then
        echo "${temp}°C"
    else
        echo "N/A"
    fi
}

# Get memory information
get_memory_info() {
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_used=$((mem_total - mem_available))
    local mem_percent=$(awk "BEGIN {printf \"%.1f\", ($mem_used / $mem_total) * 100}")

    local mem_total_gb=$(awk "BEGIN {printf \"%.1f\", $mem_total / 1024 / 1024}")
    local mem_used_gb=$(awk "BEGIN {printf \"%.1f\", $mem_used / 1024 / 1024}")
    local mem_available_gb=$(awk "BEGIN {printf \"%.1f\", $mem_available / 1024 / 1024}")

    echo "$mem_used_gb|$mem_available_gb|$mem_total_gb|$mem_percent"
}

# Get swap information
get_swap_info() {
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    local swap_used=$((swap_total - swap_free))

    if [[ $swap_total -eq 0 ]]; then
        echo "0.0|0.0|0.0"
        return
    fi

    local swap_percent=$(awk "BEGIN {printf \"%.1f\", ($swap_used / $swap_total) * 100}")
    local swap_total_gb=$(awk "BEGIN {printf \"%.1f\", $swap_total / 1024 / 1024}")
    local swap_used_gb=$(awk "BEGIN {printf \"%.1f\", $swap_used / 1024 / 1024}")

    echo "$swap_used_gb|$swap_total_gb|$swap_percent"
}

# Get disk usage information
get_disk_info() {
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')
    local disk_percent=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')

    echo "$disk_used|$disk_available|$disk_total|$disk_percent"
}

# Get disk I/O statistics
get_disk_io() {
    if [[ ! -f /proc/diskstats ]]; then
        echo "0|0"
        return
    fi

    local disk=$(lsblk -ndo NAME,TYPE | grep disk | head -1 | awk '{print $1}')
    if [[ -z "$disk" ]]; then
        echo "0|0"
        return
    fi

    local stats1=$(grep -w "$disk" /proc/diskstats)
    local read1=$(echo "$stats1" | awk '{print $6}')
    local write1=$(echo "$stats1" | awk '{print $10}')

    sleep 1

    local stats2=$(grep -w "$disk" /proc/diskstats)
    local read2=$(echo "$stats2" | awk '{print $6}')
    local write2=$(echo "$stats2" | awk '{print $10}')

    local read_sectors=$((read2 - read1))
    local write_sectors=$((write2 - write1))

    local read_mb=$(awk "BEGIN {printf \"%.2f\", ($read_sectors * 512) / 1024 / 1024}")
    local write_mb=$(awk "BEGIN {printf \"%.2f\", ($write_sectors * 512) / 1024 / 1024}")

    echo "$read_mb|$write_mb"
}

# Get network statistics
get_network_info() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)

    if [[ -z "$interface" ]]; then
        echo "N/A|0.0|0.0"
        return
    fi

    local rx1=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx1=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")

    sleep 1

    local rx2=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx2=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")

    local rx_bytes=$((rx2 - rx1))
    local tx_bytes=$((tx2 - tx1))

    local download_mb=$(awk "BEGIN {printf \"%.2f\", $rx_bytes / 1024 / 1024}")
    local upload_mb=$(awk "BEGIN {printf \"%.2f\", $tx_bytes / 1024 / 1024}")

    echo "$interface|$download_mb|$upload_mb"
}

# Get system information
get_system_info() {
    local os_info=$(lsb_release -ds 2>/dev/null | tr -d '"' || echo "Ubuntu Linux")
    local kernel=$(uname -r)
    local uptime=$(uptime -p | sed 's/up //')
    local process_count=$(ps aux | wc -l)

    echo "$os_info|$kernel|$uptime|$process_count"
}

# ============================================================================
# Health Score Calculation
# ============================================================================

calculate_health_score() {
    local cpu_usage=$1
    local mem_percent=$2
    local disk_percent=$3
    local load_avg=$4
    local cpu_cores=$5

    local load_normalized=$(awk "BEGIN {printf \"%.1f\", ($load_avg / $cpu_cores) * 100}")

    local cpu_score=$(awk "BEGIN {printf \"%.0f\", 100 - $cpu_usage}")
    local mem_score=$(awk "BEGIN {printf \"%.0f\", 100 - $mem_percent}")
    local disk_score=$(awk "BEGIN {printf \"%.0f\", 100 - $disk_percent}")
    local load_score=$(awk "BEGIN {printf \"%.0f\", 100 - ($load_normalized > 100 ? 100 : $load_normalized)}")

    local health_score=$(awk "BEGIN {printf \"%.0f\", ($cpu_score * 0.3) + ($mem_score * 0.3) + ($disk_score * 0.2) + ($load_score * 0.2)}")

    echo "$health_score"
}

get_health_color() {
    local score=$1
    if (( score >= 80 )); then
        echo "$GREEN"
    elif (( score >= 60 )); then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

get_health_status() {
    local score=$1
    if (( score >= 80 )); then
        echo "Excellent"
    elif (( score >= 60 )); then
        echo "Good"
    elif (( score >= 40 )); then
        echo "Fair"
    else
        echo "Poor"
    fi
}

# ============================================================================
# Grid Display Functions
# ============================================================================

# Print a metric card (left or right column)
print_metric_card() {
    local title=$1
    local value=$2
    local status=$3
    local color=${4:-$NC}
    local column=${5:-left}  # left or right

    if [[ "$column" == "left" ]]; then
        printf "%-38s" "$(echo -e "  ${PURPLE}${title}${NC}")"
    else
        echo -e "  ${PURPLE}${title}${NC}"
    fi

    if [[ "$column" == "left" ]]; then
        printf "%-38s" "$(echo -e "    ${color}${value}${NC}")"
    else
        echo -e "    ${color}${value}${NC}"
    fi

    if [[ -n "$status" ]]; then
        if [[ "$column" == "left" ]]; then
            printf "%-38s\n" "$(echo -e "    ${GRAY}${status}${NC}")"
        else
            echo -e "    ${GRAY}${status}${NC}"
        fi
    fi
}

# Print grid row with 2 columns
print_grid_row() {
    local left_title=$1
    local left_value=$2
    local left_status=$3
    local left_color=${4:-$NC}
    local right_title=$5
    local right_value=$6
    local right_status=$7
    local right_color=${8:-$NC}

    # Left column
    printf "  %-17s %-18s" "$(echo -e "${PURPLE}${left_title}${NC}")" "$(echo -e "${left_color}${left_value}${NC}")"

    # Right column
    if [[ -n "$right_title" ]]; then
        printf "  %-17s %-18s\n" "$(echo -e "${PURPLE}${right_title}${NC}")" "$(echo -e "${right_color}${right_value}${NC}")"
    else
        echo ""
    fi

    # Status lines if present
    if [[ -n "$left_status" || -n "$right_status" ]]; then
        if [[ -n "$left_status" ]]; then
            printf "    ${GRAY}%-33s${NC}" "$left_status"
        else
            printf "    %-33s" ""
        fi

        if [[ -n "$right_status" ]]; then
            printf "    ${GRAY}%-33s${NC}\n" "$right_status"
        else
            echo ""
        fi
    fi
}

display_status() {
    echo -e "${BLUE}Collecting system metrics...${NC}"

    # Collect all metrics
    local cpu_usage=$(get_cpu_usage)
    local load_avg=$(get_load_average)
    local cpu_cores=$(get_cpu_cores)
    local cpu_temp=$(get_cpu_temp)

    IFS='|' read -r mem_used mem_available mem_total mem_percent <<< "$(get_memory_info)"
    IFS='|' read -r swap_used swap_total swap_percent <<< "$(get_swap_info)"
    IFS='|' read -r disk_used disk_available disk_total disk_percent <<< "$(get_disk_info)"
    IFS='|' read -r disk_read disk_write <<< "$(get_disk_io)"
    IFS='|' read -r net_interface net_download net_upload <<< "$(get_network_info)"
    IFS='|' read -r os_info kernel uptime process_count <<< "$(get_system_info)"

    # Calculate health score
    local load_1min=$(echo "$load_avg" | awk '{print $1}')
    local health_score=$(calculate_health_score "$cpu_usage" "$mem_percent" "$disk_percent" "$load_1min" "$cpu_cores")
    local health_status=$(get_health_status "$health_score")
    local health_color=$(get_health_color "$health_score")

    # Clear screen and display dashboard
    clear

    # Header with health score
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                      ${PURPLE}Fub System Status Dashboard${NC}                       ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  Health Score: ${health_color}${health_score}/100${NC} (${health_status})                                              ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # System Info Grid (2 columns)
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${PURPLE}SYSTEM INFORMATION${NC}                                                      ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
    print_grid_row "OS" "$os_info" "" "$NC" "Kernel" "$kernel" "" "$NC"
    print_grid_row "Uptime" "$uptime" "" "$CYAN" "Processes" "$process_count" "" "$CYAN"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # CPU & Memory Grid (2 columns)
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${PURPLE}CPU & MEMORY${NC}                                                            ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────────────┤${NC}"

    local cpu_color=$GREEN
    [[ $(echo "$cpu_usage > 80" | bc -l) -eq 1 ]] && cpu_color=$RED
    [[ $(echo "$cpu_usage > 60" | bc -l) -eq 1 ]] && [[ $(echo "$cpu_usage <= 80" | bc -l) -eq 1 ]] && cpu_color=$YELLOW

    local mem_color=$GREEN
    [[ $(echo "$mem_percent > 80" | bc -l) -eq 1 ]] && mem_color=$RED
    [[ $(echo "$mem_percent > 60" | bc -l) -eq 1 ]] && [[ $(echo "$mem_percent <= 80" | bc -l) -eq 1 ]] && mem_color=$YELLOW

    print_grid_row "CPU Usage" "${cpu_usage}%" "" "$cpu_color" "Memory Usage" "${mem_percent}%" "" "$mem_color"
    print_grid_row "CPU Cores" "$cpu_cores" "" "$NC" "RAM" "${mem_used}GB / ${mem_total}GB" "" "$NC"
    print_grid_row "Load Avg" "$load_avg" "" "$CYAN" "Available" "${mem_available}GB" "" "$GREEN"
    print_grid_row "Temperature" "$cpu_temp" "" "$YELLOW" "Swap" "${swap_used}GB / ${swap_total}GB" "(${swap_percent}%)" "$GRAY"

    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Disk & Network Grid (2 columns)
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${PURPLE}DISK & NETWORK${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────────────┤${NC}"

    local disk_color=$GREEN
    [[ $disk_percent -gt 80 ]] && disk_color=$RED
    [[ $disk_percent -gt 60 ]] && [[ $disk_percent -le 80 ]] && disk_color=$YELLOW

    print_grid_row "Disk Usage" "${disk_percent}%" "" "$disk_color" "Network If" "$net_interface" "" "$CYAN"
    print_grid_row "Used / Free" "${disk_used} / ${disk_available}" "" "$NC" "Download" "${net_download} MB/s" "" "$GREEN"
    print_grid_row "Total Space" "$disk_total" "" "$NC" "Upload" "${net_upload} MB/s" "" "$GREEN"
    print_grid_row "Read Speed" "${disk_read} MB/s" "" "$YELLOW" "Write Speed" "${disk_write} MB/s" "" "$YELLOW"

    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Controls
    echo -e "${GRAY}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}Press Q to exit, R to refresh (auto-refresh every 5s)${NC}"
    echo ""
}

# ============================================================================
# Interactive Mode
# ============================================================================

interactive_status() {
    display_status

    while true; do
        if read -rsn1 -t 5 key; then
            case "$key" in
                q|Q)
                    clear
                    echo -e "${GREEN}${ICON_SUCCESS}${NC} Status dashboard closed"
                    echo ""
                    exit 0
                    ;;
                r|R)
                    display_status
                    ;;
            esac
        else
            display_status
        fi
    done
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Check dependencies
    local missing_deps=()

    command -v bc &>/dev/null || missing_deps+=("bc")
    command -v mpstat &>/dev/null || missing_deps+=("sysstat")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Installing required dependencies...${NC}"
        sudo apt-get update -qq 2>/dev/null
        for dep in "${missing_deps[@]}"; do
            if [[ "$dep" == "mpstat" ]]; then
                sudo apt-get install -y -qq sysstat 2>/dev/null
            else
                sudo apt-get install -y -qq "$dep" 2>/dev/null
            fi
        done
    fi

    interactive_status
}

main "$@"
