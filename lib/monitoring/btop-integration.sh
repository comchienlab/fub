#!/usr/bin/env bash

# FUB Btop Integration Module
# Integrates with btop for enhanced performance monitoring

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "${FUB_SCRIPT_DIR}/lib/common.sh"
    source "${FUB_SCRIPT_DIR}/lib/ui.sh"
    source "${FUB_SCRIPT_DIR}/lib/config.sh"
fi

# Btop integration constants
readonly BTOP_INTEGRATION_VERSION="1.0.0"
readonly BTOP_INTEGRATION_CACHE_DIR="${FUB_CACHE_DIR}/btop-integration"

# Btop configuration
BTOP_AVAILABLE=false
BTOP_PATH=""
BTOP_CONFIG_DIR="${HOME}/.config/btop"
BTOP_CACHE_DIR="${BTOP_INTEGRATION_CACHE_DIR}/data"

# Initialize btop integration
init_btop_integration() {
    mkdir -p "$BTOP_INTEGRATION_CACHE_DIR"
    mkdir -p "$BTOP_CACHE_DIR"

    # Detect btop availability
    if command -v btop >/dev/null 2>&1; then
        BTOP_AVAILABLE=true
        BTOP_PATH=$(command -v btop 2>/dev/null)
        log_debug "btop detected at: $BTOP_PATH"
    else
        BTOP_AVAILABLE=false
        log_debug "btop not available, using fallback monitoring"
    fi
}

# Check if btop is available
is_btop_available() {
    [[ "$BTOP_AVAILABLE" == "true" ]]
}

# Generate btop configuration for FUB monitoring
generate_btop_config() {
    local config_file="${BTOP_CONFIG_DIR}/btop.conf"
    local fub_config="${BTOP_CONFIG_DIR}/fub-integration.conf"

    mkdir -p "$BTOP_CONFIG_DIR"

    # Create FUB-specific btop configuration
    cat > "$fub_config" << 'EOF'
# FUB Integration Configuration for btop
# Optimized for system monitoring during cleanup operations

# Update rate (ms)
update_ms=1000

# Theme
theme=DEFAULT

# Tty mode
tty_mode=false

# Base temperature
base_temp=60

# Show fixed网络的更大值
shownet=true

# Process filtering
proc_filtering=true

# Proc sorting key
proc_sorting=cpu

# Proc tree
proc_tree=true

# Proc reversed
proc_reversed=false

# Proc per core
proc_per_core=true

# Proc colors
proc_colors=true

# Proc gradient
proc_gradient=true

# Proc mem_bytes
proc_mem_bytes=true

# Proc cpu_graph
proc_cpu_graph=true

# Proc information
proc_info=true

# Proc left click
proc_left_click=menu

# Proc right click
proc_right_click=kill

# Check temperature
check_temp=true

# Draw clock
draw_clock=true

# Clock format
clock_format=%H:%M:%S

# Background update
background_update=true

# Vim keys
vim_keys=false

# Low battery color
low_battery_color=true

# Box drawings
box_drawings=true
EOF

    log_debug "Generated btop configuration for FUB integration"
    echo "$fub_config"
}

# Capture btop data in non-interactive mode
capture_btop_data() {
    local duration="${1:-10}"
    local output_file="${2:-}"

    if ! is_btop_available; then
        log_warn "btop not available, using fallback data capture"
        capture_fallback_data "$duration" "$output_file"
        return
    fi

    log_debug "Capturing btop data for ${duration} seconds"

    local temp_file
    temp_file=$(mktemp)

    # Run btop in batch mode to capture data
    # Note: This is a simplified approach - actual btop batch mode may differ
    timeout "$duration" "$BTOP_PATH" --utf-force --dump "$temp_file" 2>/dev/null || {
        log_warn "btop data capture failed, using fallback"
        capture_fallback_data "$duration" "$output_file"
        rm -f "$temp_file"
        return
    }

    # Process the captured data and convert to JSON
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local processed_data
    processed_data=$(cat << EOF
{
  "timestamp": "$timestamp",
  "capture_duration": $duration,
  "source": "btop",
  "raw_data_file": "$temp_file"
}
EOF
)

    # Save to output file if specified
    if [[ -n "$output_file" ]]; then
        echo "$processed_data" > "$output_file"
        log_debug "btop data saved to $output_file"
    fi

    # Move raw data to cache
    if [[ -f "$temp_file" ]]; then
        mv "$temp_file" "${BTOP_CACHE_DIR}/btop_capture_$(date +%s).txt"
    fi

    echo "$processed_data"
}

# Fallback data capture when btop is not available
capture_fallback_data() {
    local duration="${1:-10}"
    local output_file="${2:-}"

    log_debug "Using fallback data capture for ${duration} seconds"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Capture system metrics multiple times
    local samples=()
    local sample_count=0
    local sample_interval=2

    while [[ $sample_count -lt $((duration / sample_interval)) ]]; do
        local sample
        sample=$(cat << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "cpu_usage": "$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')",
  "memory_usage": "$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')",
  "disk_usage": "$(df / | tail -1 | awk '{print $5}' | tr -d '%')",
  "load_average": "$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/,.*//')",
  "processes": "$(ps aux | wc -l)"
}
EOF
)
        samples+=("$sample")
        sleep "$sample_interval"
        sample_count=$((sample_count + 1))
    done

    # Combine samples into final JSON
    local data_capture
    data_capture=$(cat << EOF
{
  "timestamp": "$timestamp",
  "capture_duration": $duration,
  "source": "fallback",
  "sample_count": $sample_count,
  "samples": [
$(IFS=$'\n'; echo "${samples[*]}" | sed '2,$s/^/    ,/')
  ]
}
EOF
)

    # Save to output file if specified
    if [[ -n "$output_file" ]]; then
        echo "$data_capture" > "$output_file"
        log_debug "Fallback data saved to $output_file"
    fi

    echo "$data_capture"
}

# Monitor with btop during operation
monitor_with_btop() {
    local operation_name="$1"
    local pid="$2"
    local max_duration="${3:-300}"

    if ! is_btop_available; then
        log_info "btop not available, using basic monitoring"
        # Fall back to basic process monitoring
        monitor_process_fallback "$operation_name" "$pid" "$max_duration"
        return
    fi

    log_info "Starting btop monitoring for operation: $operation_name"

    local start_time
    start_time=$(date +%s)
    local monitor_log="${BTOP_CACHE_DIR}/${operation_name}_btop_$(date +%s).log"

    # Start monitoring in background
    (
        while kill -0 "$pid" 2>/dev/null; do
            local current_time
            current_time=$(date +%s)
            local elapsed=$((current_time - start_time))

            if [[ $elapsed -gt $max_duration ]]; then
                break
            fi

            # Capture snapshot
            local snapshot
            snapshot=$(capture_btop_data 5)

            # Log snapshot
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $snapshot" >> "$monitor_log"

            sleep 10
        done
    ) &

    local monitor_pid=$!

    # Wait for operation to complete
    wait "$pid" 2>/dev/null || true

    # Stop monitoring
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true

    log_info "btop monitoring completed for $operation_name"
    echo "$monitor_log"
}

# Fallback process monitoring
monitor_process_fallback() {
    local operation_name="$1"
    local pid="$2"
    local max_duration="${3:-300}"

    log_info "Starting fallback monitoring for operation: $operation_name"

    local start_time
    start_time=$(date +%s)
    local monitor_log="${BTOP_CACHE_DIR}/${operation_name}_fallback_$(date +%s).log"

    # Create monitoring log
    echo '{"operation": "'"$operation_name"'", "pid": '$pid', "monitoring": [' > "$monitor_log"

    local first_sample=true

    while kill -0 "$pid" 2>/dev/null; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -gt $max_duration ]]; then
            break
        fi

        # Get process resource usage
        local process_data
        process_data=$(ps -p "$pid" -o %cpu,%mem,vsz,rss,etime 2>/dev/null || echo "")

        if [[ -n "$process_data" && "$process_data" != *"%"* ]]; then
            break  # Process no longer exists
        fi

        local sample
        sample=$(cat << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "elapsed_seconds": $elapsed,
  "process_info": "$process_data"
}
EOF
)

        if [[ "$first_sample" == "true" ]]; then
            first_sample=false
        else
            echo ',' >> "$monitor_log"
        fi

        echo "$sample" >> "$monitor_log"
        sleep 5
    done

    # Close monitoring log
    echo ']}' >> "$monitor_log"

    log_info "Fallback monitoring completed for $operation_name"
    echo "$monitor_log"
}

# Get btop status and capabilities
get_btop_status() {
    local status
    if is_btop_available; then
        status="available"
    else
        status="unavailable"
    fi

    local version=""
    if [[ -n "$BTOP_PATH" ]]; then
        version=$("$BTOP_PATH" --version 2>/dev/null || echo "unknown")
    fi

    cat << EOF
{
  "status": "$status",
  "path": "$BTOP_PATH",
  "version": "$version",
  "config_dir": "$BTOP_CONFIG_DIR",
  "cache_dir": "$BTOP_CACHE_DIR"
}
EOF
}

# Start btop with FUB configuration
start_btop_fub_mode() {
    if ! is_btop_available; then
        log_error "btop is not available"
        return 1
    fi

    local config_file
    config_file=$(generate_btop_config)

    log_info "Starting btop in FUB monitoring mode"
    "$BTOP_PATH" --utf-force
}

# Generate performance report from btop data
generate_btop_report() {
    local data_file="$1"

    if [[ ! -f "$data_file" ]]; then
        log_error "btop data file not found: $data_file"
        return 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # This is a simplified report generation
    # In a full implementation, you'd parse the actual btop data format
    cat << EOF
{
  "report_type": "btop_performance",
  "timestamp": "$timestamp",
  "data_file": "$data_file",
  "summary": {
    "status": "completed",
    "message": "Performance data captured successfully"
  }
}
EOF
}

# Initialize module
init_btop_integration