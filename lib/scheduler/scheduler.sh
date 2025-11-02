#!/usr/bin/env bash

# FUB Core Scheduler System
# Main scheduler functionality integrating all components

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Source scheduler components
source "${FUB_ROOT_DIR}/lib/scheduler/systemd-integration.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/profiles.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/background-ops.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/notifications.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/history.sh"

# Scheduler constants
readonly FUB_SCHEDULER_VERSION="1.0.0"
readonly FUB_SCHEDULER_CONFIG="${FUB_CONFIG_DIR}/scheduler.yaml"
readonly FUB_SCHEDULER_STATE="${HOME}/.local/share/fub/scheduler.state"
readonly FUB_SCHEDULER_LOCK="${HOME}/.local/share/fub/scheduler.lock"

# Scheduler state
FUB_SCHEDULER_INITIALIZED=false
FUB_SCHEDULER_RUNNING=false
FUB_SCHEDULER_AUTO_CLEANUP=true
FUB_SCHEDULER_GLOBAL_NOTIFICATIONS=true

# Initialize scheduler system
init_scheduler() {
    if [[ "$FUB_SCHEDULER_INITIALIZED" == true ]]; then
        return 0
    fi

    log_info "Initializing FUB Scheduler v$FUB_SCHEDULER_VERSION"

    # Initialize all subsystems
    init_systemd_integration
    init_profiles
    init_background_ops
    init_notifications
    init_history

    # Load scheduler configuration
    load_scheduler_config

    # Create state file if it doesn't exist
    if [[ ! -f "$FUB_SCHEDULER_STATE" ]]; then
        create_scheduler_state
    fi

    FUB_SCHEDULER_INITIALIZED=true
    log_info "FUB Scheduler initialized successfully"
}

# Load scheduler configuration
load_scheduler_config() {
    # Set default values
    FUB_SCHEDULER_AUTO_CLEANUP=true
    FUB_SCHEDULER_GLOBAL_NOTIFICATIONS=true

    # Load from config file if it exists
    if [[ -f "$FUB_SCHEDULER_CONFIG" ]]; then
        # Simple parsing (could be enhanced with proper YAML parser)
        if grep -q "auto_cleanup:" "$FUB_SCHEDULER_CONFIG"; then
            FUB_SCHEDULER_AUTO_CLEANUP=$(grep "^auto_cleanup:" "$FUB_SCHEDULER_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "true")
        fi

        if grep -q "global_notifications:" "$FUB_SCHEDULER_CONFIG"; then
            FUB_SCHEDULER_GLOBAL_NOTIFICATIONS=$(grep "^global_notifications:" "$FUB_SCHEDULER_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "true")
        fi
    fi
}

# Create scheduler state file
create_scheduler_state() {
    cat > "$FUB_SCHEDULER_STATE" << EOF
# FUB Scheduler State File
# Generated on $(date)

scheduler_version: $FUB_SCHEDULER_VERSION
initialized_at: $(date -Iseconds)
last_check: $(date -Iseconds)
active_profiles: []
maintenance_count: 0
last_maintenance: never
EOF

    log_debug "Created scheduler state file"
}

# Update scheduler state
update_scheduler_state() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$FUB_SCHEDULER_STATE" ]]; then
        create_scheduler_state
    fi

    # Simple key-value update (could be enhanced with proper YAML parser)
    case "$key" in
        "last_check")
            sed -i "s/^last_check:.*/last_check: $value/" "$FUB_SCHEDULER_STATE"
            ;;
        "maintenance_count")
            sed -i "s/^maintenance_count:.*/maintenance_count: $value/" "$FUB_SCHEDULER_STATE"
            ;;
        "last_maintenance")
            sed -i "s/^last_maintenance:.*/last_maintenance: $value/" "$FUB_SCHEDULER_STATE"
            ;;
        "active_profiles")
            sed -i "s/^active_profiles:.*/active_profiles: $value/" "$FUB_SCHEDULER_STATE"
            ;;
    esac
}

# Get scheduler status
get_scheduler_status() {
    init_scheduler

    echo "FUB Scheduler Status"
    echo "===================="
    echo "Version: $FUB_SCHEDULER_VERSION"
    echo "Initialized: $FUB_SCHEDULER_INITIALIZED"
    echo "Auto cleanup: $FUB_SCHEDULER_AUTO_CLEANUP"
    echo "Global notifications: $FUB_SCHEDULER_GLOBAL_NOTIFICATIONS"

    if [[ -f "$FUB_SCHEDULER_STATE" ]]; then
        echo ""
        echo "State information:"
        grep -v "^#" "$FUB_SCHEDULER_STATE" | sed 's/:/: /'
    fi

    echo ""
    echo "Active profiles:"
    local active_profiles
    active_profiles=$(get_active_profiles)
    if [[ -n "$active_profiles" ]]; then
        for profile in $active_profiles; do
            echo "  - $profile"
        done
    else
        echo "  No active profiles"
    fi

    echo ""
    echo "System information:"
    if is_systemd_user_available; then
        echo "  ✓ Systemd user services available"
    else
        echo "  ✗ Systemd user services not available"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        echo "  ✓ Desktop notifications available"
    else
        echo "  ✗ Desktop notifications not available"
    fi
}

# Run scheduled maintenance
run_scheduled_maintenance() {
    local profile_name="$1"
    local force="${2:-false}"

    log_info "Running scheduled maintenance for profile: $profile_name"

    init_scheduler

    # Record operation start
    local start_time
    start_time=$(date +%s)
    local operation_start
    operation_start=$(date -Iseconds)

    # Send start notification
    if [[ "$FUB_SCHEDULER_GLOBAL_NOTIFICATIONS" == true ]]; then
        send_notification "INFO" "Maintenance Started" "Starting scheduled maintenance for profile: $profile_name" "$profile_name"
    fi

    # Load profile
    if ! load_profile "$profile_name"; then
        log_error "Failed to load profile: $profile_name"
        return 1
    fi

    # Get profile operations
    local operations
    operations=$(get_profile_property "$profile_name" "operations")

    if [[ -z "$operations" ]]; then
        log_warn "No operations defined for profile: $profile_name"
        return 1
    fi

    # Execute background operation
    local command="${FUB_ROOT_DIR}/bin/fub --non-interactive --log-level=INFO cleanup"
    for operation in $operations; do
        command="$command $operation"
    done

    # Check system conditions (unless forced)
    local conditions="ac_power,system_load"
    if [[ "$force" == "true" ]]; then
        conditions=""
        log_info "Forcing execution (skipping condition checks)"
    fi

    # Get resource limits from profile
    local memory_limit
    memory_limit=$(get_profile_property "$profile_name" "memory_limit" || echo "512M")

    # Execute maintenance operation
    local exit_code=0
    local space_freed=0
    local files_processed=0

    if execute_background_operation "maintenance-$profile_name" "$command" "$conditions" "$memory_limit"; then
        exit_code=0
        log_info "Maintenance completed successfully for profile: $profile_name"

        # Get space freed (would be calculated from actual cleanup results)
        # This is a simplified implementation
        space_freed=$(($(date +%s) - start_time))  # Placeholder
        files_processed=10  # Placeholder
    else
        exit_code=1
        log_error "Maintenance failed for profile: $profile_name"
    fi

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Record in history
    record_maintenance_operation \
        "scheduled_cleanup" \
        "$profile_name" \
        "$([[ $exit_code -eq 0 ]] && echo "success" || echo "failed")" \
        "$duration" \
        "$space_freed" \
        "$files_processed" \
        "$([[ $exit_code -ne 0 ]] && echo "1" || echo "0")" \
        "0" \
        "0" \
        "scheduled" \
        "Operations: $operations"

    # Update scheduler state
    local current_count
    current_count=$(grep "maintenance_count:" "$FUB_SCHEDULER_STATE" | cut -d' ' -f2 || echo "0")
    current_count=$((current_count + 1))
    update_scheduler_state "maintenance_count" "$current_count"
    update_scheduler_state "last_maintenance" "$(date -Iseconds)"

    # Send completion notification
    if [[ "$FUB_SCHEDULER_GLOBAL_NOTIFICATIONS" == true ]]; then
        local notification_level="INFO"
        local notification_title="Maintenance Completed"
        local notification_message="Maintenance for profile '$profile_name' completed in ${duration}s"

        if [[ $exit_code -ne 0 ]]; then
            notification_level="ERROR"
            notification_title="Maintenance Failed"
            notification_message="Maintenance for profile '$profile_name' failed after ${duration}s"
        fi

        send_notification "$notification_level" "$notification_title" "$notification_message" "$profile_name"
    fi

    return $exit_code
}

# Enable maintenance profile
enable_profile() {
    local profile_name="$1"

    log_info "Enabling maintenance profile: $profile_name"

    init_scheduler

    if activate_profile "$profile_name"; then
        # Update active profiles in state
        local active_profiles
        active_profiles=$(get_active_profiles | tr '\n' ' ')
        update_scheduler_state "active_profiles" "[$active_profiles]"

        log_info "Profile '$profile_name' enabled successfully"
        return 0
    else
        log_error "Failed to enable profile: $profile_name"
        return 1
    fi
}

# Disable maintenance profile
disable_profile() {
    local profile_name="$1"

    log_info "Disabling maintenance profile: $profile_name"

    init_scheduler

    if deactivate_profile "$profile_name"; then
        # Update active profiles in state
        local active_profiles
        active_profiles=$(get_active_profiles | tr '\n' ' ')
        update_scheduler_state "active_profiles" "[$active_profiles]"

        log_info "Profile '$profile_name' disabled successfully"
        return 0
    else
        log_error "Failed to disable profile: $profile_name"
        return 1
    fi
}

# List all available profiles and their status
list_profiles_status() {
    init_scheduler

    echo "Maintenance Profiles"
    echo "==================="
    echo ""

    list_profiles

    echo ""
    echo "Active Timers:"
    if is_systemd_user_available; then
        systemctl --user list-timers --all | grep "${FUB_SYSTEMD_TIMER_PREFIX}" || echo "  No active timers found"
    else
        echo "  Systemd user services not available"
    fi
}

# Show maintenance history
show_history() {
    local days="${1:-30}"
    local profile="${2:-}"

    init_scheduler

    get_maintenance_history "" "$profile" "" "$days"
}

# Show maintenance statistics
show_statistics() {
    local days="${1:-30}"

    init_scheduler

    get_operation_statistics "$days"
}

# Generate maintenance report
generate_report() {
    init_scheduler

    local report_file
    report_file=$(generate_maintenance_report)

    echo "Maintenance report generated: $report_file"

    if [[ "$FUB_SCHEDULER_GLOBAL_NOTIFICATIONS" == true ]]; then
        send_notification "INFO" "Report Generated" "Maintenance report generated: $report_file" "report"
    fi
}

# Test scheduler functionality
test_scheduler() {
    log_info "Testing FUB Scheduler functionality"

    init_scheduler

    echo "Testing scheduler components..."

    # Test systemd integration
    echo "Testing systemd integration..."
    if is_systemd_user_available; then
        echo "  ✓ Systemd user services available"
    else
        echo "  ✗ Systemd user services not available"
    fi

    # Test profiles
    echo "Testing profiles..."
    if get_profile_property "desktop" "name" >/dev/null 2>&1; then
        echo "  ✓ Default profiles available"
    else
        echo "  ✗ Default profiles not available"
    fi

    # Test background operations
    echo "Testing background operations..."
    if init_background_ops 2>/dev/null; then
        echo "  ✓ Background operations initialized"
    else
        echo "  ✗ Background operations failed to initialize"
    fi

    # Test notifications
    echo "Testing notifications..."
    if init_notifications 2>/dev/null; then
        echo "  ✓ Notifications initialized"
        echo "  Sending test notification..."
        send_notification "INFO" "Scheduler Test" "FUB Scheduler test notification" "test"
    else
        echo "  ✗ Notifications failed to initialize"
    fi

    # Test history
    echo "Testing history..."
    if init_history 2>/dev/null; then
        echo "  ✓ History system initialized"
    else
        echo "  ✗ History system failed to initialize"
    fi

    echo ""
    echo "Scheduler test completed. Check logs for details."
}

# Perform scheduler maintenance
scheduler_maintenance() {
    log_info "Performing scheduler maintenance"

    init_scheduler

    # Update scheduler state
    update_scheduler_state "last_check" "$(date -Iseconds)"

    # Clean up failed timers
    cleanup_failed_timers

    # Clean up stale background processes
    cleanup_stale_background_processes

    # Clean up old notifications if auto cleanup is enabled
    if [[ "$FUB_SCHEDULER_AUTO_CLEANUP" == true ]]; then
        cleanup_notifications 30
        cleanup_old_history_records
    fi

    # Check system maintenance conflicts
    if check_system_maintenance_conflicts; then
        log_debug "No system maintenance conflicts detected"
    else
        log_warn "System maintenance conflicts detected"
    fi

    # Update status
    update_scheduler_state "last_check" "$(date -Iseconds)"

    log_info "Scheduler maintenance completed"
}

# Main scheduler command handler
scheduler_command() {
    local action="$1"
    shift

    case "$action" in
        "init"|"initialize")
            init_scheduler
            ;;
        "status")
            get_scheduler_status
            ;;
        "enable"|"start")
            [[ $# -eq 1 ]] || { echo "Usage: scheduler enable <profile>"; return 1; }
            enable_profile "$1"
            ;;
        "disable"|"stop")
            [[ $# -eq 1 ]] || { echo "Usage: scheduler disable <profile>"; return 1; }
            disable_profile "$1"
            ;;
        "run")
            [[ $# -ge 1 ]] || { echo "Usage: scheduler run <profile> [--force]"; return 1; }
            local profile="$1"
            local force="false"
            [[ "$2" == "--force" ]] && force="true"
            run_scheduled_maintenance "$profile" "$force"
            ;;
        "list")
            list_profiles_status
            ;;
        "profiles")
            list_profiles
            ;;
        "history")
            show_history "$@"
            ;;
        "stats"|"statistics")
            show_statistics "$@"
            ;;
        "report")
            generate_report
            ;;
        "test")
            test_scheduler
            ;;
        "maintenance")
            scheduler_maintenance
            ;;
        "suggest")
            generate_maintenance_suggestions
            ;;
        *)
            echo "Unknown scheduler action: $action"
            echo "Available actions: init, status, enable, disable, run, list, profiles, history, stats, report, test, maintenance, suggest"
            return 1
            ;;
    esac
}

# Export functions
export -f init_scheduler
export -f load_scheduler_config
export -f get_scheduler_status
export -f run_scheduled_maintenance
export -f enable_profile
export -f disable_profile
export -f list_profiles_status
export -f show_history
export -f show_statistics
export -f generate_report
export -f test_scheduler
export -f scheduler_maintenance
export -f scheduler_command