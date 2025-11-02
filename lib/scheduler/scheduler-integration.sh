#!/usr/bin/env bash

# FUB Scheduler Integration
# Integration with existing monitoring and safety systems

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Source scheduler components
source "${FUB_ROOT_DIR}/lib/scheduler/scheduler.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/notifications.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/history.sh"

# Source safety system
source "${FUB_ROOT_DIR}/lib/safety/safety-integration.sh"

# Scheduler integration constants
readonly FUB_SCHEDULER_INTEGRATION_VERSION="1.0.0"
readonly FUB_SCHEDULER_INTEGRATION_STATE="${HOME}/.local/share/fub/scheduler_integration.state"

# Integration state
FUB_SCHEDULER_INTEGRATION_INITIALIZED=false

# Initialize scheduler integration
init_scheduler_integration() {
    if [[ "$FUB_SCHEDULER_INTEGRATION_INITIALIZED" == true ]]; then
        return 0
    fi

    log_debug "Initializing FUB Scheduler Integration v$FUB_SCHEDULER_INTEGRATION_VERSION"

    # Initialize scheduler and safety systems
    init_scheduler
    init_safety_system

    # Create integration state file if it doesn't exist
    if [[ ! -f "$FUB_SCHEDULER_INTEGRATION_STATE" ]]; then
        create_integration_state
    fi

    FUB_SCHEDULER_INTEGRATION_INITIALIZED=true
    log_debug "Scheduler integration initialized"
}

# Create integration state file
create_integration_state() {
    cat > "$FUB_SCHEDULER_INTEGRATION_STATE" << EOF
# FUB Scheduler Integration State
# Generated on $(date)

integration_version: $FUB_SCHEDULER_INTEGRATION_VERSION
initialized_at: $(date -Iseconds)
last_safety_check: $(date -Iseconds)
safety_level: $SAFETY_LEVEL
backup_count: 0
undo_points: 0
monitored_services: []
EOF
}

# Update integration state
update_integration_state() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$FUB_SCHEDULER_INTEGRATION_STATE" ]]; then
        create_integration_state
    fi

    case "$key" in
        "last_safety_check")
            sed -i "s/^last_safety_check:.*/last_safety_check: $value/" "$FUB_SCHEDULER_INTEGRATION_STATE"
            ;;
        "backup_count")
            sed -i "s/^backup_count:.*/backup_count: $value/" "$FUB_SCHEDULER_INTEGRATION_STATE"
            ;;
        "undo_points")
            sed -i "s/^undo_points:.*/undo_points: $value/" "$FUB_SCHEDULER_INTEGRATION_STATE"
            ;;
    esac
}

# Safe scheduled maintenance execution
execute_safe_scheduled_maintenance() {
    local profile_name="$1"
    local force="${2:-false}"
    local operations="$3"

    log_info "Executing safe scheduled maintenance for profile: $profile_name"

    init_scheduler_integration

    local start_time
    start_time=$(date +%s)

    # Record operation start
    send_notification "INFO" "Safe Maintenance Started" "Starting safe scheduled maintenance for profile: $profile_name" "$profile_name"

    # Pre-operation safety checks
    if ! perform_pre_operation_checks "$profile_name" "$operations"; then
        send_notification "ERROR" "Safety Check Failed" "Pre-operation safety checks failed for profile: $profile_name" "$profile_name"
        return 1
    fi

    # Create backup point
    local backup_id=""
    if [[ "$SAFETY_SKIP_BACKUP" != "true" ]]; then
        backup_id=$(create_backup_point "scheduled_maintenance_$profile_name" "Before scheduled maintenance for $profile_name")
        if [[ -n "$backup_id" ]]; then
            log_info "Created backup point: $backup_id"
            update_integration_state "last_safety_check" "$(date -Iseconds)"
        else
            log_warn "Failed to create backup point"
        fi
    fi

    # Execute maintenance with safety wrapper
    local maintenance_result=0
    local error_details=""

    # Use safety wrapper for critical operations
    if echo "$operations" | grep -q "packages\|system"; then
        log_info "Using safety wrapper for critical operations"
        maintenance_result=$(execute_with_safety_wrapper "$profile_name" "$operations" 2>&1) || maintenance_result=$?
        if [[ $maintenance_result -ne 0 ]]; then
            error_details="Safety wrapper failed: $maintenance_result"
        fi
    else
        log_info "Executing standard maintenance operations"
        # Execute standard maintenance with monitoring
        maintenance_result=$(execute_monitored_maintenance "$profile_name" "$operations" 2>&1) || maintenance_result=$?
        if [[ $maintenance_result -ne 0 ]]; then
            error_details="Maintenance execution failed: $maintenance_result"
        fi
    fi

    # Post-operation verification
    local post_check_result=0
    if [[ $maintenance_result -eq 0 ]]; then
        if ! perform_post_operation_checks "$profile_name" "$operations"; then
            post_check_result=1
            error_details="Post-operation verification failed"
        fi
    fi

    # Calculate final result
    local final_result=$maintenance_result
    [[ $final_result -eq 0 ]] && final_result=$post_check_result

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Record in history with safety information
    record_maintenance_operation \
        "safe_scheduled_cleanup" \
        "$profile_name" \
        "$([[ $final_result -eq 0 ]] && echo "success" || echo "failed")" \
        "$duration" \
        "0" \
        "0" \
        "$([[ $final_result -ne 0 ]] && echo "1" || echo "0")" \
        "0" \
        "0" \
        "scheduled" \
        "Operations: $operations | Safety level: $SAFETY_LEVEL | Backup: ${backup_id:-none} | Errors: $error_details"

    # Handle failure scenarios
    if [[ $final_result -ne 0 ]]; then
        handle_maintenance_failure "$profile_name" "$backup_id" "$error_details"
    fi

    # Send completion notification
    local notification_level="INFO"
    local notification_title="Safe Maintenance Completed"
    local notification_message="Safe maintenance for profile '$profile_name' completed in ${duration}s"

    if [[ $final_result -ne 0 ]]; then
        notification_level="ERROR"
        notification_title="Safe Maintenance Failed"
        notification_message="Safe maintenance for profile '$profile_name' failed: $error_details"
    fi

    send_notification "$notification_level" "$notification_title" "$notification_message" "$profile_name"

    return $final_result
}

# Perform pre-operation safety checks
perform_pre_operation_checks() {
    local profile_name="$1"
    local operations="$2"

    log_debug "Performing pre-operation safety checks for profile: $profile_name"

    # Update safety check timestamp
    update_integration_state "last_safety_check" "$(date -Iseconds)"

    # Run standard preflight checks
    if ! run_preflight_checks; then
        log_error "Preflight checks failed"
        return 1
    fi

    # Check for development environment conflicts
    if echo "$operations" | grep -q "build\|dev"; then
        if ! check_development_safety; then
            log_error "Development environment safety check failed"
            return 1
        fi
    fi

    # Check system services status
    if ! check_system_services_safety "$operations"; then
        log_error "System services safety check failed"
        return 1
    fi

    # Check protection rules
    if ! validate_operation_safety "$operations"; then
        log_error "Operation safety validation failed"
        return 1
    fi

    log_debug "Pre-operation safety checks passed"
    return 0
}

# Perform post-operation verification
perform_post_operation_checks() {
    local profile_name="$1"
    local operations="$2"

    log_debug "Performing post-operation verification for profile: $profile_name"

    # Verify system integrity
    if ! verify_system_integrity; then
        log_error "System integrity verification failed"
        return 1
    fi

    # Check if services are running properly
    if ! verify_service_health; then
        log_error "Service health verification failed"
        return 1
    fi

    # Verify development environment
    if echo "$operations" | grep -q "build\|dev"; then
        if ! verify_development_environment; then
            log_error "Development environment verification failed"
            return 1
        fi
    fi

    log_debug "Post-operation verification passed"
    return 0
}

# Execute with safety wrapper
execute_with_safety_wrapper() {
    local profile_name="$1"
    local operations="$2"

    log_debug "Executing operations with safety wrapper: $operations"

    # Set safety environment variables
    export SAFETY_OPERATION="scheduled_maintenance"
    export SAFETY_PROFILE="$profile_name"
    export SAFETY_LEVEL="conservative"

    # Execute with undo system
    local undo_id=""
    if command -v create_undo_point >/dev/null 2>&1; then
        undo_id=$(create_undo_point "scheduled_maintenance_$profile_name" "Before scheduled maintenance operations")
        log_debug "Created undo point: $undo_id"
    fi

    # Execute operations
    local result=0
    local command="${FUB_ROOT_DIR}/bin/fub --non-interactive --log-level=INFO cleanup"
    for operation in $operations; do
        command="$command $operation"
    done

    log_debug "Executing: $command"
    eval "$command" || result=$?

    # Handle undo on failure
    if [[ $result -ne 0 && -n "$undo_id" ]]; then
        log_warn "Operation failed, attempting to undo changes"
        if command -v undo_changes >/dev/null 2>&1; then
            undo_changes "$undo_id" || log_error "Failed to undo changes"
        fi
    fi

    return $result
}

# Execute monitored maintenance
execute_monitored_maintenance() {
    local profile_name="$1"
    local operations="$2"

    log_debug "Executing monitored maintenance: $operations"

    # Start service monitoring
    local monitor_pid=""
    if command -v start_service_monitoring >/dev/null 2>&1; then
        start_service_monitoring &
        monitor_pid=$!
        log_debug "Started service monitoring (PID: $monitor_pid)"
    fi

    # Execute operations
    local result=0
    local command="${FUB_ROOT_DIR}/bin/fub --non-interactive --log-level=INFO cleanup"
    for operation in $operations; do
        command="$command $operation"
    done

    log_debug "Executing: $command"
    eval "$command" || result=$?

    # Stop service monitoring
    if [[ -n "$monitor_pid" ]]; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
        log_debug "Stopped service monitoring"
    fi

    return $result
}

# Check development environment safety
check_development_safety() {
    log_debug "Checking development environment safety"

    # Check for active git operations
    if command -v check_git_operations >/dev/null 2>&1; then
        if ! check_git_operations; then
            log_error "Active git operations detected"
            return 1
        fi
    fi

    # Check for running development tools
    local dev_tools=("vscode" "code" "intellij" "idea" "node" "npm" "yarn" "make" "gcc" "g++")
    for tool in "${dev_tools[@]}"; do
        if pgrep -f "$tool" >/dev/null 2>&1; then
            log_warn "Development tool detected: $tool"
            # For now, just warn - could be configurable
        fi
    done

    # Check for project files
    if [[ -d "${HOME}/projects" || -d "${HOME}/dev" ]]; then
        log_debug "Development directories detected"
    fi

    return 0
}

# Check system services safety
check_system_services_safety() {
    local operations="$1"

    log_debug "Checking system services safety for operations: $operations"

    # Define critical services that should not be interrupted
    local critical_services=("sshd" "networking" "systemd" "dbus" "cron")

    # Check for specific operation risks
    if echo "$operations" | grep -q "packages\|apt"; then
        # Check if package management is already running
        if pgrep -f "apt-get|dpkg|apt" >/dev/null 2>&1; then
            log_error "Package management already running"
            return 1
        fi
    fi

    # Check service availability
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_debug "Critical service $service is running"
        else
            log_warn "Critical service $service is not running"
        fi
    done

    return 0
}

# Validate operation safety
validate_operation_safety() {
    local operations="$1"

    log_debug "Validating operation safety: $operations"

    # Check for dangerous operations
    local dangerous_operations=("rm -rf /" "dd if=" "mkfs" "format")
    for dangerous in "${dangerous_operations[@]}"; do
        if echo "$operations" | grep -q "$dangerous"; then
            log_error "Dangerous operation detected: $dangerous"
            return 1
        fi
    done

    return 0
}

# Verify system integrity
verify_system_integrity() {
    log_debug "Verifying system integrity"

    # Check essential directories
    local essential_dirs=("/bin" "/sbin" "/usr/bin" "/usr/sbin" "/etc")
    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Essential directory missing: $dir"
            return 1
        fi
    done

    # Check essential commands
    local essential_commands=("bash" "sh" "ls" "cat" "echo")
    for cmd in "${essential_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Essential command missing: $cmd"
            return 1
        fi
    done

    return 0
}

# Verify service health
verify_service_health() {
    log_debug "Verifying service health"

    # Check critical services
    local critical_services=("systemd-journald" "systemd-logind" "networking")

    for service in "${critical_services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            if ! systemctl is-active --quiet "$service" 2>/dev/null; then
                log_warn "Service $service is not active"
            fi
        fi
    done

    return 0
}

# Verify development environment
verify_development_environment() {
    log_debug "Verifying development environment"

    # Check if git is working
    if command -v git >/dev/null 2>&1; then
        if ! git --version >/dev/null 2>&1; then
            log_error "Git is not working properly"
            return 1
        fi
    fi

    # Check if development directories are intact
    if [[ -d "${HOME}/projects" ]]; then
        if [[ ! -r "${HOME}/projects" ]]; then
            log_error "Projects directory is not readable"
            return 1
        fi
    fi

    return 0
}

# Handle maintenance failure
handle_maintenance_failure() {
    local profile_name="$1"
    local backup_id="$2"
    local error_details="$3"

    log_error "Handling maintenance failure for profile: $profile_name"

    # Send critical notification
    send_notification "CRITICAL" "Maintenance Failed" "Scheduled maintenance failed for profile '$profile_name': $error_details" "$profile_name"

    # Attempt rollback if backup exists
    if [[ -n "$backup_id" ]]; then
        log_info "Attempting rollback from backup: $backup_id"
        if command -v restore_backup >/dev/null 2>&1; then
            if restore_backup "$backup_id"; then
                log_info "Rollback successful"
                send_notification "INFO" "Rollback Successful" "System restored from backup after maintenance failure" "$profile_name"
            else
                log_error "Rollback failed"
                send_notification "CRITICAL" "Rollback Failed" "Failed to restore system from backup after maintenance failure" "$profile_name"
            fi
        fi
    fi

    # Create emergency undo point if needed
    if command -v create_undo_point >/dev/null 2>&1; then
        local emergency_undo_id
        emergency_undo_id=$(create_undo_point "emergency_after_maintenance_failure" "Emergency state after maintenance failure")
        log_info "Created emergency undo point: $emergency_undo_id"
    fi
}

# Get integration status
get_scheduler_integration_status() {
    echo "FUB Scheduler Integration Status"
    echo "================================="
    echo "Version: $FUB_SCHEDULER_INTEGRATION_VERSION"
    echo "Safety Level: $SAFETY_LEVEL"
    echo "Skip Backup: $SAFETY_SKIP_BACKUP"
    echo "Dry Run: $SAFETY_DRY_RUN"

    if [[ -f "$FUB_SCHEDULER_INTEGRATION_STATE" ]]; then
        echo ""
        echo "Integration State:"
        grep -v "^#" "$FUB_SCHEDULER_INTEGRATION_STATE" | sed 's/:/: /'
    fi

    echo ""
    echo "Safety Systems:"
    if command -v run_preflight_checks >/dev/null 2>&1; then
        echo "  ✓ Preflight checks available"
    else
        echo "  ✗ Preflight checks not available"
    fi

    if command -v create_backup_point >/dev/null 2>&1; then
        echo "  ✓ Backup system available"
    else
        echo "  ✗ Backup system not available"
    fi

    if command -v create_undo_point >/dev/null 2>&1; then
        echo "  ✓ Undo system available"
    else
        echo "  ✗ Undo system not available"
    fi
}

# Export functions
export -f init_scheduler_integration
export -f execute_safe_scheduled_maintenance
export -f perform_pre_operation_checks
export -f perform_post_operation_checks
export -f execute_with_safety_wrapper
export -f execute_monitored_maintenance
export -f check_development_safety
export -f check_system_services_safety
export -f validate_operation_safety
export -f verify_system_integrity
export -f verify_service_health
export -f verify_development_environment
export -f handle_maintenance_failure
export -f get_scheduler_integration_status