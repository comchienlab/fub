#!/usr/bin/env bash

# FUB Performance Monitor Module
# Real-time performance monitoring and trend analysis

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "${FUB_SCRIPT_DIR}/lib/common.sh"
    source "${FUB_SCRIPT_DIR}/lib/ui.sh"
    source "${FUB_SCRIPT_DIR}/lib/config.sh"
    source "${FUB_SCRIPT_DIR}/lib/monitoring/system-analysis.sh"
fi

# Performance monitor constants
readonly PERFORMANCE_MONITOR_VERSION="1.0.0"
readonly PERFORMANCE_MONITOR_CACHE_DIR="${FUB_CACHE_DIR}/performance-monitor"
readonly PERFORMANCE_MONITOR_HISTORY_FILE="${PERFORMANCE_MONITOR_CACHE_DIR}/history.json"
readonly PERFORMANCE_MONITOR_STATE_FILE="${PERFORMANCE_MONITOR_CACHE_DIR}/current-state.json"

# Performance thresholds (configurable)
PERFORMANCE_CPU_THRESHOLD=${PERFORMANCE_CPU_THRESHOLD:-80}
PERFORMANCE_MEMORY_THRESHOLD=${PERFORMANCE_MEMORY_THRESHOLD:-85}
PERFORMANCE_DISK_THRESHOLD=${PERFORMANCE_DISK_THRESHOLD:-90}

# Initialize performance monitor
init_performance_monitor() {
    mkdir -p "$PERFORMANCE_MONITOR_CACHE_DIR"

    # Initialize history file if it doesn't exist
    if [[ ! -f "$PERFORMANCE_MONITOR_HISTORY_FILE" ]]; then
        echo '{"history": []}' > "$PERFORMANCE_MONITOR_HISTORY_FILE"
    fi

    log_debug "Performance monitor initialized"
}

# Get current performance metrics
get_current_metrics() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # CPU usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")

    # Memory usage
    local memory_info
    memory_info=$(free -m 2>/dev/null || echo "Mem: 0 0 0 0 0 0")
    local total_mem
    local used_mem
    read -r _ total_mem used_mem _ <<< "$memory_info"
    local memory_usage=0
    if [[ ${total_mem:-0} -gt 0 ]]; then
        memory_usage=$(echo "$total_mem $used_mem" | awk '{printf "%.1f", ($2/$1)*100}')
    fi

    # Disk usage
    local disk_usage
    disk_usage=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")

    # Load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/,.*//' 2>/dev/null || echo "0")

    # I/O wait
    local io_wait
    io_wait=$(top -bn1 | grep "Cpu(s)" | sed 's/.* \([0-9.]*\)%wa.*/\1/' 2>/dev/null || echo "0")

    cat << EOF
{
  "timestamp": "$timestamp",
  "cpu": {
    "usage_percent": $(echo "$cpu_usage" | awk '{printf "%.1f", $1}'),
    "load_average": "$load_avg"
  },
  "memory": {
    "usage_percent": $memory_usage
  },
  "disk": {
    "usage_percent": ${disk_usage:-0}
  },
  "io": {
    "wait_percent": $(echo "$io_wait" | awk '{printf "%.1f", $1}')
  }
}
EOF
}

# Record performance metrics
record_metrics() {
    local operation="${1:-general}"
    local metrics
    metrics=$(get_current_metrics)

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Add operation info to metrics
    local enhanced_metrics
    enhanced_metrics=$(cat << EOF
{
  "timestamp": "$timestamp",
  "operation": "$operation",
  "metrics": $metrics
}
EOF
)

    # Append to history (keep last 1000 entries)
    local temp_file
    temp_file=$(mktemp)

    # Read existing history and add new entry
    if [[ -f "$PERFORMANCE_MONITOR_HISTORY_FILE" ]]; then
        # Keep only last 1000 entries
        tail -n 1000 "$PERFORMANCE_MONITOR_HISTORY_FILE" > "$temp_file"

        # Remove the closing bracket and comma
        sed -i '' '$ s/}$/,/' "$temp_file" 2>/dev/null || true

        # Add new entry
        echo "$enhanced_metrics" >> "$temp_file"
        echo ']}' >> "$temp_file"
    else
        echo '{"history": [' > "$temp_file"
        echo "$enh_metrics" >> "$temp_file"
        echo ']}' >> "$temp_file"
    fi

    mv "$temp_file" "$PERFORMANCE_MONITOR_HISTORY_FILE"

    # Save current state
    echo "$metrics" > "$PERFORMANCE_MONITOR_STATE_FILE"

    log_debug "Performance metrics recorded for operation: $operation"
}

# Get performance trends over time period
get_performance_trends() {
    local hours="${1:-24}"
    local since_timestamp
    since_timestamp=$(date -d "$hours hours ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${hours}H -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ ! -f "$PERFORMANCE_MONITOR_HISTORY_FILE" ]]; then
        echo '{"error": "No performance history available"}'
        return
    fi

    # Extract metrics within time range
    local relevant_data
    relevant_data=$(mktemp)

    # This is a simplified approach - in a real implementation you might use jq
    grep -A10 "$since_timestamp" "$PERFORMANCE_MONITOR_HISTORY_FILE" > "$relevant_data" 2>/dev/null || true

    # Calculate averages and trends
    local avg_cpu
    local avg_memory
    local avg_disk
    local peak_cpu
    local peak_memory
    local peak_disk

    # Extract values (simplified approach)
    avg_cpu=$(grep '"usage_percent":' "$relevant_data" | awk '{sum+=$2} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' 2>/dev/null || echo "0")
    avg_memory=$(grep -A2 '"memory":' "$relevant_data" | grep '"usage_percent":' | awk '{sum+=$2} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' 2>/dev/null || echo "0")
    avg_disk=$(grep -A4 '"disk":' "$relevant_data" | grep '"usage_percent":' | awk '{sum+=$2} END {if(NR>0) printf "%.1f", sum/NR; else print "0"}' 2>/dev/null || echo "0")

    peak_cpu=$(grep '"usage_percent":' "$relevant_data" | awk '{if($2>max) max=$2} END {printf "%.1f", max}' 2>/dev/null || echo "0")
    peak_memory=$(grep -A2 '"memory":' "$relevant_data" | grep '"usage_percent":' | awk '{if($2>max) max=$2} END {printf "%.1f", max}' 2>/dev/null || echo "0")
    peak_disk=$(grep -A4 '"disk":' "$relevant_data" | grep '"usage_percent":' | awk '{if($2>max) max=$2} END {printf "%.1f", max}' 2>/dev/null || echo "0")

    rm -f "$relevant_data"

    cat << EOF
{
  "time_period_hours": $hours,
  "averages": {
    "cpu_percent": $avg_cpu,
    "memory_percent": $avg_memory,
    "disk_percent": $avg_disk
  },
  "peaks": {
    "cpu_percent": $peak_cpu,
    "memory_percent": $peak_memory,
    "disk_percent": $peak_disk
  }
}
EOF
}

# Check for performance alerts
check_performance_alerts() {
    local metrics
    metrics=$(get_current_metrics)

    local alerts="[]"
    local alert_count=0

    # Extract values for checking
    local cpu_usage
    local memory_usage
    local disk_usage
    local io_wait

    cpu_usage=$(echo "$metrics" | grep '"usage_percent":' | head -1 | cut -d: -f2 | tr -d ' ,')
    memory_usage=$(echo "$metrics" | grep -A2 '"memory":' | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    disk_usage=$(echo "$metrics" | grep -A4 '"disk":' | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    io_wait=$(echo "$metrics" | grep -A6 '"io":' | grep '"wait_percent":' | cut -d: -f2 | tr -d ' ,')

    # Check thresholds
    local temp_alerts=$(mktemp)
    echo '[' > "$temp_alerts"

    if (( $(echo "$cpu_usage > $PERFORMANCE_CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        if [[ $alert_count -gt 0 ]]; then echo ',' >> "$temp_alerts"; fi
        cat << EOF >> "$temp_alerts"
{
  "type": "cpu_high",
  "severity": "warning",
  "message": "High CPU usage: ${cpu_usage}%",
  "threshold": $PERFORMANCE_CPU_THRESHOLD,
  "recommendation": "Check for CPU-intensive processes or consider upgrading"
}
EOF
        alert_count=$((alert_count + 1))
    fi

    if (( $(echo "$memory_usage > $PERFORMANCE_MEMORY_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        if [[ $alert_count -gt 0 ]]; then echo ',' >> "$temp_alerts"; fi
        cat << EOF >> "$temp_alerts"
{
  "type": "memory_high",
  "severity": "warning",
  "message": "High memory usage: ${memory_usage}%",
  "threshold": $PERFORMANCE_MEMORY_THRESHOLD,
  "recommendation": "Close memory-intensive applications or add more RAM"
}
EOF
        alert_count=$((alert_count + 1))
    fi

    if (( $(echo "$disk_usage > $PERFORMANCE_DISK_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        if [[ $alert_count -gt 0 ]]; then echo ',' >> "$temp_alerts"; fi
        cat << EOF >> "$temp_alerts"
{
  "type": "disk_high",
  "severity": "critical",
  "message": "High disk usage: ${disk_usage}%",
  "threshold": $PERFORMANCE_DISK_THRESHOLD,
  "recommendation": "Clean up disk space immediately or expand storage"
}
EOF
        alert_count=$((alert_count + 1))
    fi

    if (( $(echo "$io_wait > 20" | bc -l 2>/dev/null || echo "0") )); then
        if [[ $alert_count -gt 0 ]]; then echo ',' >> "$temp_alerts"; fi
        cat << EOF >> "$temp_alerts"
{
  "type": "io_high",
  "severity": "warning",
  "message": "High I/O wait: ${io_wait}%",
  "threshold": 20,
  "recommendation": "Check for disk bottlenecks or failing storage devices"
}
EOF
        alert_count=$((alert_count + 1))
    fi

    echo ']' >> "$temp_alerts"
    alerts=$(cat "$temp_alerts")
    rm -f "$temp_alerts"

    # Return alerts as JSON
    echo "$alerts"
}

# Monitor performance during operation
monitor_operation() {
    local operation_name="$1"
    local pid="$2"
    local sample_interval="${3:-5}"
    local max_samples="${4:-60}"

    log_info "Starting performance monitoring for operation: $operation_name (PID: $pid)"

    local sample_count=0
    local start_time
    start_time=$(date +%s)

    # Create operation-specific log
    local operation_log="${PERFORMANCE_MONITOR_CACHE_DIR}/${operation_name}_$(date +%s).json"
    echo '{"operation": "'"$operation_name"'", "pid": '$pid', "samples": [' > "$operation_log"

    while [[ $sample_count -lt $max_samples ]] && kill -0 "$pid" 2>/dev/null; do
        local metrics
        metrics=$(get_current_metrics)

        # Add sample to log
        if [[ $sample_count -gt 0 ]]; then echo ',' >> "$operation_log"; fi
        echo "$metrics" >> "$operation_log"

        sample_count=$((sample_count + 1))
        sleep "$sample_interval"
    done

    # Close the log
    echo ']}' >> "$operation_log"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Performance monitoring completed for $operation_name (${duration}s, ${sample_count} samples)"

    # Return summary
    cat << EOF
{
  "operation": "$operation_name",
  "duration_seconds": $duration,
  "samples_collected": $sample_count,
  "log_file": "$operation_log"
}
EOF
}

# Get performance summary
get_performance_summary() {
    local period_hours="${1:-1}"

    local trends
    trends=$(get_performance_trends "$period_hours")

    local current_metrics
    current_metrics=$(get_current_metrics)

    local alerts
    alerts=$(check_performance_alerts)

    cat << EOF
{
  "period_hours": $period_hours,
  "current_metrics": $current_metrics,
  "trends": $trends,
  "alerts": $alerts,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Initialize module
init_performance_monitor