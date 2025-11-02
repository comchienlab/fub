#!/usr/bin/env bash

# FUB Systemd Integration Library
# Handles systemd timer and service management for scheduled maintenance

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Systemd integration constants
[[ -z "${FUB_SYSTEMD_USER_DIR:-}" ]] && readonly FUB_SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
[[ -z "${FUB_SYSTEMD_TEMPLATE_DIR:-}" ]] && readonly FUB_SYSTEMD_TEMPLATE_DIR="${FUB_ROOT_DIR}/systemd"
[[ -z "${FUB_SYSTEMD_SERVICE_PREFIX:-}" ]] && readonly FUB_SYSTEMD_SERVICE_PREFIX="fub-"
[[ -z "${FUB_SYSTEMD_TIMER_PREFIX:-}" ]] && readonly FUB_SYSTEMD_TIMER_PREFIX="fub-"

# Systemd integration state
FUB_SYSTEMD_INTEGRATION_INITIALIZED=false

# Initialize systemd integration
init_systemd_integration() {
    if [[ "$FUB_SYSTEMD_INTEGRATION_INITIALIZED" == true ]]; then
        return 0
    fi

    log_debug "Initializing systemd integration"

    # Create user systemd directory if it doesn't exist
    mkdir -p "$FUB_SYSTEMD_USER_DIR"

    # Reload systemd daemon to recognize new units
    systemctl --user daemon-reload 2>/dev/null || {
        log_warn "Could not reload systemd daemon - user session may not be properly initialized"
    }

    FUB_SYSTEMD_INTEGRATION_INITIALIZED=true
    log_debug "Systemd integration initialized"
}

# Check if systemd user service is available
is_systemd_user_available() {
    systemctl --user list-units --type=timer --all >/dev/null 2>&1
}

# Install systemd timer and service
install_systemd_timer() {
    local profile_name="$1"
    local schedule="$2"
    local command="$3"
    local description="${4:-FUB scheduled maintenance for $profile_name}"

    log_info "Installing systemd timer for profile: $profile_name"

    # Validate inputs
    if [[ -z "$profile_name" || -z "$schedule" || -z "$command" ]]; then
        log_error "Profile name, schedule, and command are required"
        return 1
    fi

    # Validate schedule format
    if ! validate_systemd_schedule "$schedule"; then
        log_error "Invalid systemd schedule format: $schedule"
        return 1
    fi

    init_systemd_integration

    local timer_name="${FUB_SYSTEMD_TIMER_PREFIX}${profile_name}"
    local service_name="${FUB_SYSTEMD_SERVICE_PREFIX}${profile_name}"
    local timer_file="${FUB_SYSTEMD_USER_DIR}/${timer_name}.timer"
    local service_file="${FUB_SYSTEMD_USER_DIR}/${service_name}.service"

    # Create service file
    create_systemd_service_file "$service_name" "$command" "$description" > "$service_file"

    # Create timer file
    create_systemd_timer_file "$timer_name" "$service_name" "$schedule" > "$timer_file"

    # Reload systemd and enable timer
    systemctl --user daemon-reload
    systemctl --user enable "${timer_name}.timer"
    systemctl --user start "${timer_name}.timer"

    log_info "Systemd timer '$timer_name' installed and started"

    # Verify timer is active
    if systemctl --user is-active --quiet "${timer_name}.timer"; then
        log_info "Timer '$timer_name' is active"
        return 0
    else
        log_error "Failed to start timer '$timer_name'"
        return 1
    fi
}

# Create systemd service file content
create_systemd_service_file() {
    local service_name="$1"
    local command="$2"
    local description="$3"

    cat << EOF
[Unit]
Description=$description
Documentation=man:fub(1)
After=network-online.target
Wants=network-online.target
ConditionACPower=true

[Service]
Type=oneshot
ExecStart=$command
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=FUB_NON_INTERACTIVE=true
Environment=FUB_LOG_LEVEL=INFO
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
MemoryMax=512M
TasksMax=100
TimeoutStopSec=300
Restart=no

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true

# Resource limits
LimitCPU=50%
LimitFSIZE=100M
LimitNOFILE=4096

[Install]
WantedBy=default.target
EOF
}

# Create systemd timer file content
create_systemd_timer_file() {
    local timer_name="$1"
    local service_name="$2"
    local schedule="$3"

    cat << EOF
[Unit]
Description=FUB scheduled timer for $service_name
Documentation=man:fub(1)
PartOf=$service_name.service

[Timer]
OnCalendar=$schedule
Persistent=true
AccuracySec=1min
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
EOF
}

# Validate systemd schedule format
validate_systemd_schedule() {
    local schedule="$1"

    # Basic validation - systemd schedule format
    # Accepts: daily, weekly, monthly, yearly, or cron-like format
    case "$schedule" in
        daily|weekly|monthly|yearly|hourly)
            return 0
            ;;
        # Basic cron-like validation (simplified)
        *:*:*:*:*)
            return 0
            ;;
        # Systemd calendar event format
        *..*|*-*|*~*)
            return 0
            ;;
        *)
            log_error "Invalid schedule format: $schedule"
            return 1
            ;;
    esac
}

# Uninstall systemd timer
uninstall_systemd_timer() {
    local profile_name="$1"

    log_info "Uninstalling systemd timer for profile: $profile_name"

    init_systemd_integration

    local timer_name="${FUB_SYSTEMD_TIMER_PREFIX}${profile_name}"
    local service_name="${FUB_SYSTEMD_SERVICE_PREFIX}${profile_name}"

    # Stop and disable timer
    systemctl --user stop "${timer_name}.timer" 2>/dev/null || true
    systemctl --user disable "${timer_name}.timer" 2>/dev/null || true

    # Remove timer and service files
    rm -f "${FUB_SYSTEMD_USER_DIR}/${timer_name}.timer"
    rm -f "${FUB_SYSTEMD_USER_DIR}/${service_name}.service"

    # Reload systemd
    systemctl --user daemon-reload

    log_info "Systemd timer '$timer_name' uninstalled"
}

# List installed systemd timers
list_systemd_timers() {
    log_info "Listing installed FUB systemd timers"

    if ! is_systemd_user_available; then
        log_warn "Systemd user services not available"
        return 1
    fi

    # List all FUB timers
    systemctl --user list-timers "${FUB_SYSTEMD_TIMER_PREFIX}*" --all | \
    grep -E "(NEXT|LEFT|LAST|PASSED|${FUB_SYSTEMD_TIMER_PREFIX})" || {
        log_info "No FUB timers installed"
        return 0
    }
}

# Get timer status
get_timer_status() {
    local profile_name="$1"
    local timer_name="${FUB_SYSTEMD_TIMER_PREFIX}${profile_name}"

    if ! is_systemd_user_available; then
        echo "Systemd user services not available"
        return 1
    fi

    # Check if timer exists
    if ! systemctl --user list-unit-files | grep -q "${timer_name}.timer"; then
        echo "Timer '$timer_name' not found"
        return 1
    fi

    # Get timer status
    echo "Timer Status:"
    systemctl --user status "${timer_name}.timer" --no-pager

    echo -e "\nService Status:"
    systemctl --user status "${FUB_SYSTEMD_SERVICE_PREFIX}${profile_name}.service" --no-pager

    echo -e "\nNext Run:"
    systemctl --user show "${timer_name}.timer" -p NextElapseUSecMonotonic --value
}

# Check timer logs
check_timer_logs() {
    local profile_name="$1"
    local lines="${2:-20}"
    local timer_name="${FUB_SYSTEMD_TIMER_PREFIX}${profile_name}"

    log_info "Checking logs for timer: $timer_name"

    # Show timer logs
    journalctl --user -u "${timer_name}.timer" -n "$lines" --no-pager

    echo -e "\nService logs:"
    journalctl --user -u "${FUB_SYSTEMD_SERVICE_PREFIX}${profile_name}.service" -n "$lines" --no-pager
}

# Test systemd timer by running service manually
test_systemd_timer() {
    local profile_name="$1"

    log_info "Testing systemd timer for profile: $profile_name"

    init_systemd_integration

    local service_name="${FUB_SYSTEMD_SERVICE_PREFIX}${profile_name}"

    # Run service manually
    if systemctl --user start "${service_name}.service"; then
        log_info "Service test completed successfully"

        # Show service logs
        echo "Service output:"
        journalctl --user -u "${service_name}.service" -n 10 --no-pager
    else
        log_error "Service test failed"
        return 1
    fi
}

# Enable/disable systemd timer
toggle_systemd_timer() {
    local profile_name="$1"
    local action="$2"  # enable or disable

    log_info "$action systemd timer for profile: $profile_name"

    init_systemd_integration

    local timer_name="${FUB_SYSTEMD_TIMER_PREFIX}${profile_name}"

    case "$action" in
        enable)
            systemctl --user enable "${timer_name}.timer"
            systemctl --user start "${timer_name}.timer"
            log_info "Timer '$timer_name' enabled and started"
            ;;
        disable)
            systemctl --user stop "${timer_name}.timer"
            systemctl --user disable "${timer_name}.timer"
            log_info "Timer '$timer_name' disabled and stopped"
            ;;
        *)
            log_error "Invalid action: $action. Use 'enable' or 'disable'"
            return 1
            ;;
    esac
}

# Clean up failed timers
cleanup_failed_timers() {
    log_info "Cleaning up failed FUB timers"

    if ! is_systemd_user_available; then
        log_warn "Systemd user services not available"
        return 1
    fi

    # Find failed FUB services
    local failed_services
    failed_services=$(systemctl --user list-units --state=failed --type=service | \
                     grep "${FUB_SYSTEMD_SERVICE_PREFIX}" | awk '{print $1}' || true)

    if [[ -z "$failed_services" ]]; then
        log_info "No failed FUB services found"
        return 0
    fi

    echo "Found failed services:"
    echo "$failed_services"

    # Reset failed services
    for service in $failed_services; do
        log_info "Resetting failed service: $service"
        systemctl --user reset-failed "$service" 2>/dev/null || true
    done
}

# Check if timer conflicts with system maintenance
check_system_maintenance_conflicts() {
    log_debug "Checking for system maintenance conflicts"

    # Check for unattended-upgrades
    if systemctl is-active --quiet unattended-upgrades.service 2>/dev/null; then
        log_warn "Unattended upgrades service is active - may conflict with FUB maintenance"
        return 1
    fi

    # Check for apt-daily
    if systemctl is-active --quiet apt-daily.service 2>/dev/null; then
        log_warn "APT daily service is active - may conflict with FUB maintenance"
        return 1
    fi

    # Check for running dpkg/apt processes
    if pgrep -f "apt-get|dpkg" >/dev/null 2>&1; then
        log_warn "APT/dpkg processes are running - skipping scheduled maintenance"
        return 1
    fi

    return 0
}

# Export functions
export -f init_systemd_integration
export -f is_systemd_user_available
export -f install_systemd_timer
export -f uninstall_systemd_timer
export -f list_systemd_timers
export -f get_timer_status
export -f check_timer_logs
export -f test_systemd_timer
export -f toggle_systemd_timer
export -f cleanup_failed_timers
export -f check_system_maintenance_conflicts
export -f validate_systemd_schedule