#!/usr/bin/env bash

# FUB Background Operations Library
# Handles non-interactive execution with proper resource limits and safety checks

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Background operations constants
readonly FUB_BG_STATE_DIR="${HOME}/.local/share/fub/background"
readonly FUB_BG_LOCK_DIR="${HOME}/.local/share/fub/locks"
readonly FUB_BG_LOG_DIR="${FUB_LOG_DIR}/background"
readonly FUB_BG_PID_FILE="${FUB_BG_STATE_DIR}/current.pid"
readonly FUB_BG_STATUS_FILE="${FUB_BG_STATE_DIR}/status.json"

# Background operations state
FUB_BG_INITIALIZED=false
FUB_BG_CURRENT_PID=""
FUB_BG_RESOURCE_LIMITS_SET=false

# Default resource limits
readonly FUB_BG_DEFAULT_MEMORY_LIMIT="512M"
readonly FUB_BG_DEFAULT_CPU_LIMIT="50%"
readonly FUB_BG_DEFAULT_IO_PRIORITY="7"
readonly FUB_BG_DEFAULT_NICE_LEVEL="10"
readonly FUB_BG_DEFAULT_TIMEOUT="1800"  # 30 minutes

# Initialize background operations system
init_background_ops() {
    if [[ "$FUB_BG_INITIALIZED" == true ]]; then
        return 0
    fi

    log_debug "Initializing background operations system"

    # Create necessary directories
    mkdir -p "$FUB_BG_STATE_DIR"
    mkdir -p "$FUB_BG_LOCK_DIR"
    mkdir -p "$FUB_BG_LOG_DIR"

    # Clean up stale lock files and PIDs
    cleanup_stale_background_processes

    FUB_BG_INITIALIZED=true
    log_debug "Background operations system initialized"
}

# Set resource limits for background operations
set_background_resource_limits() {
    local memory_limit="${1:-$FUB_BG_DEFAULT_MEMORY_LIMIT}"
    local cpu_limit="${2:-$FUB_BG_DEFAULT_CPU_LIMIT}"
    local io_priority="${3:-$FUB_BG_DEFAULT_IO_PRIORITY}"
    local nice_level="${4:-$FUB_BG_DEFAULT_NICE_LEVEL}"

    log_debug "Setting background resource limits: memory=$memory_limit, cpu=$cpu_limit, io=$io_priority, nice=$nice_level"

    # Set memory limit if supported
    if command -v ulimit >/dev/null 2>&1; then
        # Convert memory limit to KB for ulimit -v
        local memory_kb
        case "$memory_limit" in
            *G|*g)
                memory_kb=$(echo "$memory_limit" | sed 's/[Gg]//' | awk '{print $1 * 1024 * 1024}')
                ;;
            *M|m)
                memory_kb=$(echo "$memory_limit" | sed 's/[Mm]//' | awk '{print $1 * 1024}')
                ;;
            *K|k)
                memory_kb=$(echo "$memory_limit" | sed 's/[Kk]//')
                ;;
            *)
                memory_kb=$((memory_limit / 1024))
                ;;
        esac

        ulimit -v "$memory_kb" 2>/dev/null || log_warn "Could not set memory limit"
    fi

    # Set CPU nice level
    if command -v renice >/dev/null 2>&1; then
        renice "$nice_level" $$ >/dev/null 2>&1 || log_warn "Could not set nice level"
    fi

    # Set I/O scheduling priority if ionice is available
    if command -v ionice >/dev/null 2>&1; then
        ionice -c "$io_priority" -p $$ >/dev/null 2>&1 || log_warn "Could not set I/O priority"
    fi

    # Set file descriptor limit
    ulimit -n 4096 2>/dev/null || log_warn "Could not set file descriptor limit"

    FUB_BG_RESOURCE_LIMITS_SET=true
    log_debug "Resource limits applied"
}

# Check system conditions for background operation
check_background_conditions() {
    local conditions="${1:-}"

    log_debug "Checking background operation conditions"

    # Default conditions if none specified
    if [[ -z "$conditions" ]]; then
        conditions="ac_power,system_load,idle_time"
    fi

    # Parse conditions
    for condition in $(echo "$conditions" | tr ',' ' '); do
        case "$condition" in
            "ac_power")
                if ! check_ac_power; then
                    log_warn "Not on AC power - skipping background operation"
                    return 1
                fi
                ;;
            "system_load")
                if ! check_system_load; then
                    log_warn "System load too high - skipping background operation"
                    return 1
                fi
                ;;
            "idle_time")
                if ! check_idle_time; then
                    log_warn "System not idle - skipping background operation"
                    return 1
                fi
                ;;
            "disk_space")
                if ! check_disk_space; then
                    log_warn "Insufficient disk space - skipping background operation"
                    return 1
                fi
                ;;
            "battery_level")
                if ! check_battery_level; then
                    log_warn "Battery level too low - skipping background operation"
                    return 1
                fi
                ;;
        esac
    done

    log_debug "All background conditions met"
    return 0
}

# Check if system is on AC power
check_ac_power() {
    # Check for AC power using various methods
    if command -v upower >/dev/null 2>&1; then
        local on_battery
        on_battery=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "state:" | grep -c "discharging" || echo "0")
        [[ "$on_battery" == "0" ]]
    elif [[ -f /sys/class/power_supply/AC/online ]]; then
        [[ "$(cat /sys/class/power_supply/AC/online)" == "1" ]]
    elif command -v pmset >/dev/null 2>&1; then
        # macOS fallback
        pmset -g batt | grep -q "AC Power"
    else
        # Assume on AC power if we can't determine
        return 0
    fi
}

# Check system load average
check_system_load() {
    local load_threshold="${1:-0.8}"
    local current_load

    if [[ -f /proc/loadavg ]]; then
        current_load=$(awk '{print $1}' /proc/loadavg)
    else
        # Fallback for systems without /proc/loadavg
        current_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    fi

    # Compare with threshold (using bc for floating point)
    if command -v bc >/dev/null 2>&1; then
        local comparison
        comparison=$(echo "$current_load < $load_threshold" | bc 2>/dev/null || echo "1")
        [[ "$comparison" == "1" ]]
    else
        # Integer fallback
        local load_int
        load_int=$(echo "$current_load" | cut -d. -f1)
        local threshold_int
        threshold_int=$(echo "$load_threshold" | cut -d. -f1)
        [[ $load_int -lt $threshold_int ]]
    fi
}

# Check if system has been idle
check_idle_time() {
    local idle_threshold="${1:-300}"  # 5 minutes default

    if command -v xprintidle >/dev/null 2>&1; then
        # X11 systems
        local idle_ms
        idle_ms=$(xprintidle 2>/dev/null || echo "0")
        [[ $idle_ms -gt $((idle_threshold * 1000)) ]]
    elif command -v systemd-idle >/dev/null 2>&1; then
        # systemd-idle
        systemd-idle --query >/dev/null 2>&1
    else
        # Fallback - assume system is idle
        return 0
    fi
}

# Check available disk space
check_disk_space() {
    local min_space_gb="${1:-1}"  # 1GB minimum
    local available_space

    # Get available space in GB
    available_space=$(df / 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || echo "0")

    [[ $available_space -ge $min_space_gb ]]
}

# Check battery level
check_battery_level() {
    local min_battery_percent="${1:-20}"  # 20% minimum

    if command -v upower >/dev/null 2>&1; then
        local battery_percent
        battery_percent=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "percentage:" | awk '{print $2}' | sed 's/%//' || echo "100")
        [[ $battery_percent -ge $min_battery_percent ]]
    elif command -v pmset >/dev/null 2>&1; then
        # macOS fallback
        local battery_percent
        battery_percent=$(pmset -g batt | grep -o '[0-9]*%' | sed 's/%//' | head -1)
        [[ $battery_percent -ge $min_battery_percent ]]
    else
        # Assume battery level is OK if we can't check
        return 0
    fi
}

# Create background operation lock
create_background_lock() {
    local operation_name="$1"
    local lock_file="${FUB_BG_LOCK_DIR}/${operation_name}.lock"

    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")

        # Check if the process is still running
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_warn "Background operation '$operation_name' is already running (PID: $lock_pid)"
            return 1
        else
            # Stale lock file - remove it
            rm -f "$lock_file"
            log_debug "Removed stale lock file for '$operation_name'"
        fi
    fi

    # Create new lock file with current PID
    echo $$ > "$lock_file"
    FUB_BG_CURRENT_PID="$lock_file"

    log_debug "Created background lock for '$operation_name' (PID: $$)"
    return 0
}

# Release background operation lock
release_background_lock() {
    local operation_name="$1"
    local lock_file="${FUB_BG_LOCK_DIR}/${operation_name}.lock"

    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")

        # Only remove if it's our lock
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$lock_file"
            log_debug "Released background lock for '$operation_name'"
        else
            log_warn "Attempted to release lock owned by another process (PID: $lock_pid)"
            return 1
        fi
    fi

    FUB_BG_CURRENT_PID=""
}

# Execute background operation
execute_background_operation() {
    local operation_name="$1"
    local command="$2"
    local conditions="${3:-ac_power,system_load}"
    local memory_limit="${4:-$FUB_BG_DEFAULT_MEMORY_LIMIT}"
    local timeout="${5:-$FUB_BG_DEFAULT_TIMEOUT}"

    log_info "Executing background operation: $operation_name"

    init_background_ops

    # Create lock
    if ! create_background_lock "$operation_name"; then
        return 1
    fi

    # Set resource limits
    set_background_resource_limits "$memory_limit"

    # Check conditions
    if ! check_background_conditions "$conditions"; then
        release_background_lock "$operation_name"
        return 1
    ]

    # Update status
    update_background_status "$operation_name" "running" "Operation started at $(date)"

    # Create operation log file
    local operation_log="${FUB_BG_LOG_DIR}/${operation_name}.$(date +%Y%m%d_%H%M%S).log"

    # Execute command with timeout
    local start_time
    start_time=$(date +%s)
    local exit_code=0

    log_info "Starting background operation: $command"
    echo "Background operation started at $(date)" > "$operation_log"
    echo "Command: $command" >> "$operation_log"
    echo "Conditions: $conditions" >> "$operation_log"
    echo "Resource limits: memory=$memory_limit, timeout=${timeout}s" >> "$operation_log"
    echo "---" >> "$operation_log"

    # Execute with timeout and capture output
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout" bash -c "$command" >> "$operation_log" 2>&1 || exit_code=$?
    else
        # Fallback without timeout
        bash -c "$command" >> "$operation_log" 2>&1 || exit_code=$?
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo "---" >> "$operation_log"
    echo "Operation completed at $(date)" >> "$operation_log"
    echo "Duration: ${duration} seconds" >> "$operation_log"
    echo "Exit code: $exit_code" >> "$operation_log"

    # Update status
    if [[ $exit_code -eq 0 ]]; then
        update_background_status "$operation_name" "completed" "Operation completed successfully in ${duration}s"
        log_info "Background operation '$operation_name' completed successfully (${duration}s)"
    else
        update_background_status "$operation_name" "failed" "Operation failed with exit code $exit_code after ${duration}s"
        log_error "Background operation '$operation_name' failed with exit code $exit_code (${duration}s)"
    fi

    # Release lock
    release_background_lock "$operation_name"

    return $exit_code
}

# Update background operation status
update_background_status() {
    local operation_name="$1"
    local status="$2"
    local message="$3"
    local timestamp
    timestamp=$(date -Iseconds)

    # Create status entry
    local status_entry
    status_entry=$(cat << EOF
{
  "operation": "$operation_name",
  "status": "$status",
  "message": "$message",
  "timestamp": "$timestamp",
  "pid": "$$"
}
EOF
)

    # Append to status file
    echo "$status_entry" >> "${FUB_BG_STATUS_FILE}.new"

    # Simple rotation - keep only last 100 entries
    tail -n 100 "${FUB_BG_STATUS_FILE}.new" > "$FUB_BG_STATUS_FILE" 2>/dev/null || true
    rm -f "${FUB_BG_STATUS_FILE}.new"
}

# Get background operation status
get_background_status() {
    local operation_name="${1:-}"

    if [[ ! -f "$FUB_BG_STATUS_FILE" ]]; then
        echo "No background operation history found"
        return 0
    fi

    if [[ -n "$operation_name" ]]; then
        # Filter for specific operation
        grep "\"operation\": \"$operation_name\"" "$FUB_BG_STATUS_FILE" | tail -1
    else
        # Show all recent operations
        tail -10 "$FUB_BG_STATUS_FILE"
    fi
}

# List running background operations
list_running_operations() {
    log_info "Running background operations:"

    local found_operations=false

    for lock_file in "${FUB_BG_LOCK_DIR}"/*.lock; do
        if [[ -f "$lock_file" ]]; then
            local operation_name
            operation_name=$(basename "$lock_file" .lock)
            local pid
            pid=$(cat "$lock_file" 2>/dev/null || echo "")

            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                echo "  $operation_name (PID: $pid)"
                found_operations=true

                # Show process info if available
                if command -v ps >/dev/null 2>&1; then
                    local cmd
                    cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    echo "    Command: $cmd"
                fi
            fi
        fi
    done

    if [[ "$found_operations" == false ]]; then
        echo "  No running background operations"
    fi
}

# Stop background operation
stop_background_operation() {
    local operation_name="$1"

    log_info "Stopping background operation: $operation_name"

    local lock_file="${FUB_BG_LOCK_DIR}/${operation_name}.lock"

    if [[ ! -f "$lock_file" ]]; then
        log_error "Background operation '$operation_name' not found"
        return 1
    fi

    local pid
    pid=$(cat "$lock_file" 2>/dev/null || echo "")

    if [[ -z "$pid" ]]; then
        log_error "Could not determine PID for operation '$operation_name'"
        return 1
    fi

    # Send SIGTERM first
    if kill -TERM "$pid" 2>/dev/null; then
        log_info "Sent SIGTERM to background operation '$operation_name' (PID: $pid)"

        # Wait a bit and check if it's still running
        sleep 5

        if kill -0 "$pid" 2>/dev/null; then
            # Send SIGKILL if still running
            log_warn "Operation still running, sending SIGKILL"
            kill -KILL "$pid" 2>/dev/null || true
        fi

        update_background_status "$operation_name" "stopped" "Operation stopped by user request"
        log_info "Background operation '$operation_name' stopped"
        return 0
    else
        log_error "Could not signal background operation '$operation_name' (PID: $pid)"
        return 1
    fi
}

# Clean up stale background processes
cleanup_stale_background_processes() {
    log_debug "Cleaning up stale background processes"

    for lock_file in "${FUB_BG_LOCK_DIR}"/*.lock; do
        if [[ -f "$lock_file" ]]; then
            local pid
            pid=$(cat "$lock_file" 2>/dev/null || echo "")

            if [[ -n "$pid" ]]; then
                # Check if process is still running
                if ! kill -0 "$pid" 2>/dev/null; then
                    local operation_name
                    operation_name=$(basename "$lock_file" .lock)
                    log_debug "Removing stale lock for '$operation_name' (PID: $pid no longer running)"
                    rm -f "$lock_file"
                    update_background_status "$operation_name" "crashed" "Process crashed or was killed"
                fi
            else
                # Empty lock file - remove it
                log_debug "Removing empty lock file: $lock_file"
                rm -f "$lock_file"
            fi
        fi
    done
}

# Get background operation logs
get_background_logs() {
    local operation_name="$1"
    local lines="${2:-50}"

    local log_pattern="${FUB_BG_LOG_DIR}/${operation_name}.*.log"

    # Find the most recent log file for the operation
    local latest_log
    latest_log=$(ls -t $log_pattern 2>/dev/null | head -1)

    if [[ -n "$latest_log" && -f "$latest_log" ]]; then
        echo "Background operation log for '$operation_name':"
        echo "Log file: $latest_log"
        echo "---"
        tail -n "$lines" "$latest_log"
    else
        echo "No logs found for background operation: $operation_name"
    fi
}

# Export functions
export -f init_background_ops
export -f set_background_resource_limits
export -f check_background_conditions
export -f execute_background_operation
export -f create_background_lock
export -f release_background_lock
export -f update_background_status
export -f get_background_status
export -f list_running_operations
export -f stop_background_operation
export -f cleanup_stale_background_processes
export -f get_background_logs