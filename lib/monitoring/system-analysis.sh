#!/usr/bin/env bash

# FUB System Analysis Module
# Provides comprehensive pre and post-cleanup system analysis

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "${FUB_SCRIPT_DIR}/lib/common.sh"
    source "${FUB_SCRIPT_DIR}/lib/ui.sh"
    source "${FUB_SCRIPT_DIR}/lib/config.sh"
fi

# System analysis constants
readonly SYSTEM_ANALYSIS_VERSION="1.0.0"
readonly SYSTEM_ANALYSIS_CACHE_DIR="${FUB_CACHE_DIR}/system-analysis"
readonly SYSTEM_ANALYSIS_STATE_FILE="${SYSTEM_ANALYSIS_CACHE_DIR}/current-state.json"

# Initialize system analysis
init_system_analysis() {
    mkdir -p "$SYSTEM_ANALYSIS_CACHE_DIR"
    log_debug "System analysis initialized"
}

# Capture system resource usage
capture_system_resources() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # CPU usage (average over 5 seconds)
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")

    # Memory usage
    local memory_info
    memory_info=$(free -m 2>/dev/null || echo "Mem: 0 0 0 0 0 0")
    local total_mem
    local used_mem
    local free_mem
    read -r _ total_mem used_mem free_mem _ <<< "$memory_info"

    # Disk usage
    local disk_info
    disk_info=$(df -h / 2>/dev/null | tail -1 || echo "/ 0 0 0 0% /")
    local disk_total
    local disk_used
    local disk_avail
    local disk_percent
    read -r disk_total disk_used disk_avail disk_percent _ <<< "$disk_info"
    disk_percent=${disk_percent%\%}

    # Network usage
    local network_stats
    network_stats=$(cat /proc/net/dev 2>/dev/null | grep -E "(eth|enp|wlan|wlp)" | head -1 || echo "")
    local network_rx
    local network_tx
    if [[ -n "$network_stats" ]]; then
        read -r _ network_rx _ network_tx _ <<< "$network_stats"
    else
        network_rx="0"
        network_tx="0"
    fi

    # Load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' 2>/dev/null || echo "0, 0, 0")

    # Process count
    local process_count
    process_count=$(ps aux | wc -l 2>/dev/null || echo "0")

    cat << EOF
{
  "timestamp": "$timestamp",
  "cpu": {
    "usage_percent": $(echo "$cpu_usage" | awk '{printf "%.2f", $1}'),
    "load_average": "$load_avg",
    "processes": $process_count
  },
  "memory": {
    "total_mb": ${total_mem:-0},
    "used_mb": ${used_mem:-0},
    "free_mb": ${free_mem:-0},
    "usage_percent": $(echo "${total_mem:-0} ${used_mem:-0}" | awk '{if($1 > 0) printf "%.2f", ($2/$1)*100; else print "0"}')
  },
  "disk": {
    "total": "$disk_total",
    "used": "$disk_used",
    "available": "$disk_avail",
    "usage_percent": ${disk_percent:-0}
  },
  "network": {
    "rx_bytes": "$network_rx",
    "tx_bytes": "$network_tx"
  }
}
EOF
}

# Analyze package state
analyze_package_state() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Package counts by manager
    local apt_count=0
    local snap_count=0
    local flatpak_count=0
    local npm_count=0

    # Count packages
    if command -v apt >/dev/null 2>&1; then
        apt_count=$(apt list --installed 2>/dev/null | wc -l || echo "0")
    fi

    if command -v snap >/dev/null 2>&1; then
        snap_count=$(snap list 2>/dev/null | wc -l || echo "0")
    fi

    if command -v flatpak >/dev/null 2>&1; then
        flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo "0")
    fi

    if command -v npm >/dev/null 2>&1; then
        npm_count=$(npm list -g --depth=0 2>/dev/null | wc -l || echo "0")
    fi

    # Package updates available
    local apt_updates=0
    if command -v apt >/dev/null 2>&1; then
        apt_updates=$(apt list --upgradable 2>/dev/null | wc -l || echo "0")
    fi

    cat << EOF
{
  "timestamp": "$timestamp",
  "packages": {
    "apt": {
      "installed": $apt_count,
      "updates_available": $apt_updates
    },
    "snap": {
      "installed": $snap_count
    },
    "flatpak": {
      "installed": $flatpak_count
    },
    "npm": {
      "global": $npm_count
    }
  }
}
EOF
}

# Analyze service status
analyze_service_status() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local active_services=0
    local failed_services=0
    local enabled_services=0

    if command -v systemctl >/dev/null 2>&1; then
        active_services=$(systemctl list-units --type=service --state=running 2>/dev/null | wc -l || echo "0")
        failed_services=$(systemctl list-units --type=service --state=failed 2>/dev/null | wc -l || echo "0")
        enabled_services=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null | wc -l || echo "0")
    fi

    cat << EOF
{
  "timestamp": "$timestamp",
  "services": {
    "active": $active_services,
    "failed": $failed_services,
    "enabled": $enabled_services
  }
}
EOF
}

# Analyze development environment
analyze_dev_environment() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Check development tools
    local docker_running=false
    local dev_projects=0
    local container_count=0

    if command -v docker >/dev/null 2>&1; then
        docker_running=$(docker info >/dev/null 2>&1 && echo "true" || echo "false")
        container_count=$(docker ps -a 2>/dev/null | wc -l || echo "0")
    fi

    # Count development projects (look for common indicators)
    local project_dirs=(
        "$HOME/Projects"
        "$HOME/projects"
        "$HOME/dev"
        "$HOME/Development"
        "$HOME/workspace"
    )

    for dir in "${project_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            dev_projects=$((dev_projects + $(find "$dir" -maxdepth 1 -type d 2>/dev/null | wc -l)))
        fi
    done

    cat << EOF
{
  "timestamp": "$timestamp",
  "development": {
    "docker_running": $docker_running,
    "container_count": $container_count,
    "project_directories": $dev_projects,
    "tools": {
        "git": $(command -v git >/dev/null 2>&1 && echo "true" || echo "false"),
        "node": $(command -v node >/dev/null 2>&1 && echo "true" || echo "false"),
        "python": $(command -v python3 >/dev/null 2>&1 && echo "true" || echo "false"),
        "docker": $(command -v docker >/dev/null 2>&1 && echo "true" || echo "false"),
        "vscode": $(command -v code >/dev/null 2>&1 && echo "true" || echo "false")
    }
  }
}
EOF
}

# Perform comprehensive system analysis
perform_system_analysis() {
    local analysis_type="${1:-full}"
    local output_file="${2:-}"

    log_info "Starting system analysis ($analysis_type)"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local system_resources
    local package_state
    local service_status
    local dev_environment

    # Capture system state
    system_resources=$(capture_system_resources)
    package_state=$(analyze_package_state)
    service_status=$(analyze_service_status)
    dev_environment=$(analyze_dev_environment)

    # Combine into comprehensive analysis
    local full_analysis
    full_analysis=$(cat << EOF
{
  "timestamp": "$timestamp",
  "analysis_type": "$analysis_type",
  "system_resources": $system_resources,
  "package_state": $package_state,
  "service_status": $service_status,
  "development_environment": $dev_environment
}
EOF
)

    # Save to file if specified
    if [[ -n "$output_file" ]]; then
        echo "$full_analysis" > "$output_file"
        log_debug "System analysis saved to $output_file"
    fi

    # Always save to state file
    echo "$full_analysis" > "$SYSTEM_ANALYSIS_STATE_FILE"

    log_info "System analysis completed"
    echo "$full_analysis"
}

# Get system score (0-100)
get_system_score() {
    local analysis_file="${1:-$SYSTEM_ANALYSIS_STATE_FILE}"

    if [[ ! -f "$analysis_file" ]]; then
        echo "50"
        return
    fi

    # Extract metrics using grep and awk for compatibility
    local cpu_usage
    local memory_usage
    local disk_usage
    local failed_services

    cpu_usage=$(grep -o '"usage_percent": [0-9.]*' "$analysis_file" | head -1 | cut -d: -f2 | tr -d ' ')
    memory_usage=$(grep -A2 '"memory":' "$analysis_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    disk_usage=$(grep -A4 '"disk":' "$analysis_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    failed_services=$(grep -A3 '"services":' "$analysis_file" | grep '"failed":' | cut -d: -f2 | tr -d ' ,')

    # Calculate score (100 is best)
    local resource_score
    resource_score=$(echo "$cpu_usage $memory_usage $disk_usage" | awk '{
        cpu = $1; mem = $2; disk = $3;
        score = 100 - ((cpu + mem + disk) / 3);
        if (score < 0) score = 0;
        if (score > 100) score = 100;
        printf "%.0f", score;
    }')

    local service_score
    if [[ "${failed_services:-0}" -gt 0 ]]; then
        service_score=70
    else
        service_score=100
    fi

    local final_score
    final_score=$(echo "$resource_score $service_score" | awk '{printf "%.0f", ($1 + $2) / 2}')

    echo "$final_score"
}

# Compare two system analyses
compare_analyses() {
    local before_file="$1"
    local after_file="$2"

    if [[ ! -f "$before_file" || ! -f "$after_file" ]]; then
        log_error "Both analysis files must exist for comparison"
        return 1
    fi

    # Extract key metrics for comparison
    local before_cpu
    local after_cpu
    local before_memory
    local after_memory
    local before_disk
    local after_disk

    before_cpu=$(grep -o '"usage_percent": [0-9.]*' "$before_file" | head -1 | cut -d: -f2 | tr -d ' ')
    after_cpu=$(grep -o '"usage_percent": [0-9.]*' "$after_file" | head -1 | cut -d: -f2 | tr -d ' ')

    before_memory=$(grep -A2 '"memory":' "$before_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    after_memory=$(grep -A2 '"memory":' "$after_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')

    before_disk=$(grep -A4 '"disk":' "$before_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    after_disk=$(grep -A4 '"disk":' "$after_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')

    local cpu_change
    local memory_change
    local disk_change

    cpu_change=$(echo "$before_cpu $after_cpu" | awk '{printf "%.1f", $2 - $1}')
    memory_change=$(echo "$before_memory $after_memory" | awk '{printf "%.1f", $2 - $1}')
    disk_change=$(echo "$before_disk $after_disk" | awk '{printf "%.1f", $2 - $1}')

    cat << EOF
{
  "comparison": {
    "cpu_change_percent": $cpu_change,
    "memory_change_percent": $memory_change,
    "disk_change_percent": $disk_change
  }
}
EOF
}

# Initialize module
init_system_analysis