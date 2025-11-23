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
    # Use top to get CPU idle percentage, then calculate usage
    local idle=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print $8}' | cut -d'%' -f1)
    if [[ -n "$idle" ]]; then
        local usage=$(awk "BEGIN {printf \"%.1f\", 100 - $idle}")
        echo "$usage"
    else
        echo "0.0"
    fi
}

# Get load averages
get_load_average() {
    local load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo "$load"
}

# Get CPU core count
get_cpu_cores() {
    grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
}

# Get CPU temperature (if available)
get_cpu_temp() {
    local temp=""

    # Try different methods to get CPU temperature
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

# Get per-core CPU usage
get_per_core_usage() {
    mpstat -P ALL 1 1 2>/dev/null | grep -E "Average:.*[0-9]+" | grep -v "Average:.*all" | awk '{printf "%s:%.1f%% ", $2, 100-$NF}' || echo "N/A"
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
        echo "0.0|0.0|0.0|0.0"
        return
    fi

    local swap_percent=$(awk "BEGIN {printf \"%.1f\", ($swap_used / $swap_total) * 100}")
    local swap_total_gb=$(awk "BEGIN {printf \"%.1f\", $swap_total / 1024 / 1024}")
    local swap_used_gb=$(awk "BEGIN {printf \"%.1f\", $swap_used / 1024 / 1024}")
    local swap_free_gb=$(awk "BEGIN {printf \"%.1f\", $swap_free / 1024 / 1024}")

    echo "$swap_used_gb|$swap_free_gb|$swap_total_gb|$swap_percent"
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

    # Get primary disk (usually sda, nvme0n1, vda)
    local disk=$(lsblk -ndo NAME,TYPE | grep disk | head -1 | awk '{print $1}')

    if [[ -z "$disk" ]]; then
        echo "0|0"
        return
    fi

    # Read initial stats
    local stats1=$(grep -w "$disk" /proc/diskstats)
    local read1=$(echo "$stats1" | awk '{print $6}')
    local write1=$(echo "$stats1" | awk '{print $10}')

    sleep 1

    # Read stats again after 1 second
    local stats2=$(grep -w "$disk" /proc/diskstats)
    local read2=$(echo "$stats2" | awk '{print $6}')
    local write2=$(echo "$stats2" | awk '{print $10}')

    # Calculate sectors per second (each sector is 512 bytes)
    local read_sectors=$((read2 - read1))
    local write_sectors=$((write2 - write1))

    # Convert to MB/s
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

    # Read initial stats
    local rx1=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx1=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")

    sleep 1

    # Read stats again
    local rx2=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx2=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")

    # Calculate bytes per second
    local rx_bytes=$((rx2 - rx1))
    local tx_bytes=$((tx2 - tx1))

    # Convert to MB/s
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

# Get top processes by CPU
get_top_cpu_processes() {
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "%-20s %5s%%\n", substr($11,1,20), $3}'
}

# Get top processes by memory
get_top_mem_processes() {
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "%-20s %5s%%\n", substr($11,1,20), $4}'
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

    # Normalize load average against CPU cores
    local load_normalized=$(awk "BEGIN {printf \"%.1f\", ($load_avg / $cpu_cores) * 100}")

    # Calculate individual scores (higher is better)
    local cpu_score=$(awk "BEGIN {printf \"%.0f\", 100 - $cpu_usage}")
    local mem_score=$(awk "BEGIN {printf \"%.0f\", 100 - $mem_percent}")
    local disk_score=$(awk "BEGIN {printf \"%.0f\", 100 - $disk_percent}")
    local load_score=$(awk "BEGIN {printf \"%.0f\", 100 - ($load_normalized > 100 ? 100 : $load_normalized)}")

    # Weighted average (CPU and memory are more important)
    local health_score=$(awk "BEGIN {printf \"%.0f\", ($cpu_score * 0.3) + ($mem_score * 0.3) + ($disk_score * 0.2) + ($load_score * 0.2)}")

    echo "$health_score"
}

# Get health color based on score
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

# Get health status text
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
# Display Functions
# ============================================================================

print_header() {
    local health_score=$1
    local health_status=$2
    local health_color=$3

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                         ${PURPLE}Fub System Status Dashboard${GREEN}                        ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  ${NC}Health Score: ${health_color}${health_score}/100${NC} (${health_status})                                             ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_metric_section() {
    local title=$1
    echo ""
    echo -e "${BLUE}▸ ${title}${NC}"
    echo -e "${GRAY}────────────────────────────────────────${NC}"
}

print_metric() {
    local label=$1
    local value=$2
    local color=${3:-$NC}

    printf "  %-25s ${color}%s${NC}\n" "$label:" "$value"
}

display_status() {
    # Collect all metrics
    echo -e "${BLUE}Collecting system metrics...${NC}"

    local cpu_usage=$(get_cpu_usage)
    local load_avg=$(get_load_average)
    local cpu_cores=$(get_cpu_cores)
    local cpu_temp=$(get_cpu_temp)

    IFS='|' read -r mem_used mem_available mem_total mem_percent <<< "$(get_memory_info)"
    IFS='|' read -r swap_used swap_free swap_total swap_percent <<< "$(get_swap_info)"
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
    print_header "$health_score" "$health_status" "$health_color"

    # System Information
    print_metric_section "System Information"
    print_metric "OS" "$os_info"
    print_metric "Kernel" "$kernel"
    print_metric "Uptime" "$uptime"
    print_metric "Processes" "$process_count"

    # CPU Metrics
    print_metric_section "CPU Performance"
    local cpu_color=$GREEN
    [[ $(echo "$cpu_usage > 80" | bc -l) -eq 1 ]] && cpu_color=$RED
    [[ $(echo "$cpu_usage > 60" | bc -l) -eq 1 ]] && [[ $(echo "$cpu_usage <= 80" | bc -l) -eq 1 ]] && cpu_color=$YELLOW
    print_metric "CPU Usage" "${cpu_usage}%" "$cpu_color"
    print_metric "CPU Cores" "$cpu_cores"
    print_metric "Load Average (1,5,15)" "$load_avg"
    print_metric "Temperature" "$cpu_temp"

    # Memory Metrics
    print_metric_section "Memory Usage"
    local mem_color=$GREEN
    [[ $(echo "$mem_percent > 80" | bc -l) -eq 1 ]] && mem_color=$RED
    [[ $(echo "$mem_percent > 60" | bc -l) -eq 1 ]] && [[ $(echo "$mem_percent <= 80" | bc -l) -eq 1 ]] && mem_color=$YELLOW
    print_metric "RAM Used / Available" "${mem_used}GB / ${mem_available}GB" "$mem_color"
    print_metric "Total RAM" "${mem_total}GB"
    print_metric "Memory Usage" "${mem_percent}%" "$mem_color"

    if [[ $(echo "$swap_total > 0" | bc -l) -eq 1 ]]; then
        print_metric "Swap Used / Free" "${swap_used}GB / ${swap_free}GB"
        print_metric "Total Swap" "${swap_total}GB"
        print_metric "Swap Usage" "${swap_percent}%"
    fi

    # Disk Metrics
    print_metric_section "Disk Space & I/O"
    local disk_color=$GREEN
    [[ $disk_percent -gt 80 ]] && disk_color=$RED
    [[ $disk_percent -gt 60 ]] && [[ $disk_percent -le 80 ]] && disk_color=$YELLOW
    print_metric "Used / Available" "${disk_used} / ${disk_available}" "$disk_color"
    print_metric "Total Space" "$disk_total"
    print_metric "Disk Usage" "${disk_percent}%" "$disk_color"
    print_metric "Read Speed" "${disk_read} MB/s"
    print_metric "Write Speed" "${disk_write} MB/s"

    # Network Metrics
    print_metric_section "Network Activity"
    print_metric "Active Interface" "$net_interface"
    print_metric "Download Speed" "${net_download} MB/s" "$CYAN"
    print_metric "Upload Speed" "${net_upload} MB/s" "$CYAN"

    # Top Processes
    print_metric_section "Top CPU Processes"
    echo -e "${GRAY}  Process                  CPU%${NC}"
    get_top_cpu_processes

    print_metric_section "Top Memory Processes"
    echo -e "${GRAY}  Process                  MEM%${NC}"
    get_top_mem_processes

    echo ""
    echo -e "${GRAY}────────────────────────────────────────${NC}"
    echo -e "${BLUE}Press Q to exit, R to refresh${NC}"
    echo ""
}

# ============================================================================
# Interactive Mode
# ============================================================================

interactive_status() {
    # Display initial status
    display_status

    # Interactive loop
    while true; do
        # Read key with timeout
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
            # Auto-refresh after timeout
            display_status
        fi
    done
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Check if required commands are available
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

    # Run interactive status dashboard
    interactive_status
}

main "$@"
