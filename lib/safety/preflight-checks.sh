#!/usr/bin/env bash

# FUB Pre-flight System Checks Module
# Comprehensive system validation before cleanup operations

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Pre-flight checks constants
readonly PREFLIGHT_VERSION="1.0.0"
readonly PREFLIGHT_DESCRIPTION="Comprehensive system validation before cleanup operations"

# System thresholds
readonly MAX_LOAD_THRESHOLD=2.0
readonly MAX_MEMORY_USAGE=90
readonly MIN_DISK_SPACE=1024  # MB
readonly CRITICAL_DISK_USAGE=95

# Initialize pre-flight checks module
init_preflight_checks() {
    log_info "Initializing pre-flight checks module v$PREFLIGHT_VERSION"
    log_debug "Pre-flight checks module initialized"
}

# Check Ubuntu version compatibility
check_ubuntu_version() {
    print_section "Checking Ubuntu Version Compatibility"

    if [[ ! -f /etc/os-release ]]; then
        print_warning "Cannot determine OS version - /etc/os-release not found"
        return 0
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        print_warning "FUB is optimized for Ubuntu, detected OS: $ID"
        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Continue with non-Ubuntu system?" "FUB may not work correctly on $ID"; then
                print_info "Cleanup cancelled - incompatible OS"
                return 1
            fi
        fi
        return 0
    fi

    print_success "Ubuntu version: $PRETTY_NAME"

    # Check for minimum supported version
    local version_number=$(echo "$VERSION_ID" | cut -d'.' -f1)
    if [[ $version_number -lt 18 ]]; then
        print_warning "Ubuntu version $VERSION_ID is not officially supported"
        print_info "FUB may have limited functionality on older versions"
    fi

    # Check for known system issues
    check_known_system_issues

    return 0
}

# Check for known system issues
check_known_system_issues() {
    # Check for disk space issues
    if command_exists df; then
        local root_usage
        root_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

        if [[ $root_usage -gt $CRITICAL_DISK_USAGE ]]; then
            print_warning "Critical: Root filesystem is ${root_usage}% full"
            print_info "This is why cleanup is needed - proceeding with caution"
        fi
    fi

    # Check for package manager locks
    if [[ -f /var/lib/dpkg/lock-frontend ]] || [[ -f /var/lib/apt/lists/lock ]]; then
        print_warning "Package manager locks detected"
        print_info "Another package operation may be in progress"

        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Continue despite package locks?" "This may cause package operation conflicts"; then
                print_info "Cleanup cancelled - package locks present"
                return 1
            fi
        fi
    fi

    # Check for system updates
    if command_exists apt; then
        local updates_available
        updates_available=$(apt list --upgradable 2>/dev/null | wc -l)
        if [[ $updates_available -gt 1 ]]; then
            print_info "System updates available: $((updates_available - 1)) packages"
            print_info "Consider updating system before cleanup"
        fi
    fi

    return 0
}

# Check system stability
check_system_stability() {
    print_section "Checking System Stability"

    local stability_issues=0

    # Check system load
    if ! check_system_load; then
        ((stability_issues++))
    fi

    # Check memory usage
    if ! check_memory_usage; then
        ((stability_issues++))
    fi

    # Check disk space
    if ! check_disk_space; then
        ((stability_issues++))
    fi

    # Check critical services
    if ! check_critical_services; then
        ((stability_issues++))
    fi

    # Check network connectivity
    if ! check_network_connectivity; then
        ((stability_issues++))
    fi

    # Check power status for laptops
    if ! check_power_status; then
        ((stability_issues++))
    fi

    if [[ $stability_issues -gt 0 ]]; then
        print_warning "System stability issues detected: $stability_issues"
        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Continue despite stability issues?" "Cleanup may be affected by system conditions"; then
                print_info "Cleanup cancelled - system stability issues"
                return 1
            fi
        fi
    else
        print_success "System stability checks passed"
    fi

    return 0
}

# Check system load
check_system_load() {
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    local load_number=$(echo "$load_avg" | cut -d',' -f1 | sed 's/^[[:space:]]*//')

    # Convert to integer for comparison
    local load_float=$(echo "$load_number" | bc 2>/dev/null || echo "0")

    if (( $(echo "$load_float > $MAX_LOAD_THRESHOLD" | bc -l) )); then
        print_warning "High system load: $load_avg (threshold: $MAX_LOAD_THRESHOLD)"
        return 1
    else
        print_success "System load acceptable: $load_avg"
        return 0
    fi
}

# Check memory usage
check_memory_usage() {
    if ! command_exists free; then
        print_info "Memory check skipped - 'free' command not available"
        return 0
    fi

    local mem_info
    mem_info=$(free -m | grep "Mem:")
    local total_mem=$(echo "$mem_info" | awk '{print $2}')
    local available_mem=$(echo "$mem_info" | awk '{print $7}')

    local mem_usage_percent=$((100 - (available_mem * 100 / total_mem)))

    if [[ $mem_usage_percent -gt $MAX_MEMORY_USAGE ]]; then
        print_warning "High memory usage: ${mem_usage_percent}% (threshold: ${MAX_MEMORY_USAGE}%)"
        return 1
    else
        print_success "Memory usage acceptable: ${mem_usage_percent}%"
        return 0
    fi
}

# Check disk space
check_disk_space() {
    if ! command_exists df; then
        print_info "Disk space check skipped - 'df' command not available"
        return 0
    fi

    local space_issues=0

    # Check root filesystem
    local root_available
    root_available=$(df / | tail -1 | awk '{print $4}')
    local root_available_mb=$((root_available / 1024))

    if [[ $root_available_mb -lt $MIN_DISK_SPACE ]]; then
        print_warning "Low disk space: ${root_available_mb}MB available (threshold: ${MIN_DISK_SPACE}MB)"
        ((space_issues++))
    else
        print_success "Disk space adequate: ${root_available_mb}MB available"
    fi

    # Check other important mount points
    local -a important_mounts=("/home" "/var" "/tmp")
    for mount in "${important_mounts[@]}"; do
        if mountpoint -q "$mount" 2>/dev/null; then
            local available
            available=$(df "$mount" | tail -1 | awk '{print $4}')
            local available_mb=$((available / 1024))

            if [[ $available_mb -lt $((MIN_DISK_SPACE / 2)) ]]; then
                print_warning "Low disk space on $mount: ${available_mb}MB available"
                ((space_issues++))
            fi
        fi
    done

    return $space_issues
}

# Check critical services
check_critical_services() {
    local -a critical_services=("systemd" "dbus" "udev")
    local failed_services=0

    for service in "${critical_services[@]}"; do
        if is_service_active "$service"; then
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "success" "$service running")"
            fi
        else
            print_warning "Critical service not running: $service"
            ((failed_services++))
        fi
    done

    if [[ $failed_services -gt 0 ]]; then
        print_warning "$failed_services critical services not running"
        return 1
    else
        print_success "All critical services running"
        return 0
    fi
}

# Check network connectivity
check_network_connectivity() {
    print_info "Checking network connectivity"

    local connectivity_ok=false

    # Try multiple methods to check connectivity
    if command_exists ping; then
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            connectivity_ok=true
        fi
    fi

    # Try alternative if ping fails
    if [[ "$connectivity_ok" == "false" ]] && command_exists curl; then
        if curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; then
            connectivity_ok=true
        fi
    fi

    if [[ "$connectivity_ok" == "true" ]]; then
        print_success "Network connectivity OK"
        return 0
    else
        print_warning "Limited or no network connectivity"
        print_info "Some cleanup operations may be affected"
        return 1
    fi
}

# Check power status for laptops
check_power_status() {
    # Check if we're on a laptop
    if [[ ! -d /sys/class/power_supply ]]; then
        return 0  # Not a laptop or no power supply info
    fi

    local on_battery=false
    local battery_low=false

    # Check each power supply
    for supply in /sys/class/power_supply/*/type; do
        if [[ -f "$supply" ]]; then
            local type=$(cat "$supply")
            if [[ "$type" == "Battery" ]]; then
                local supply_dir=$(dirname "$supply")
                if [[ -f "$supply_dir/status" ]]; then
                    local status=$(cat "$supply_dir/status")
                    if [[ "$status" == "Discharging" ]]; then
                        on_battery=true

                        # Check battery capacity
                        if [[ -f "$supply_dir/capacity" ]]; then
                            local capacity=$(cat "$supply_dir/capacity")
                            if [[ $capacity -lt 20 ]]; then
                                battery_low=true
                            fi
                        fi
                    fi
                fi
            fi
        fi
    done

    if [[ "$on_battery" == "true" ]]; then
        if [[ "$battery_low" == "true" ]]; then
            print_warning "On battery power with low battery level"
            if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
                if ! confirm_with_warning "Continue on low battery?" "System may shutdown during cleanup"; then
                    print_info "Cleanup cancelled - low battery"
                    return 1
                fi
            fi
        else
            print_info "Running on battery power"
        fi
    fi

    return 0
}

# Validate file system integrity
check_filesystem_integrity() {
    print_section "Checking Filesystem Integrity"

    local integrity_issues=0

    # Check for file system errors (basic checks)
    if command_exists dmesg; then
        local fs_errors
        fs_errors=$(dmesg 2>/dev/null | grep -i "filesystem\|ext.*error\|i/o error" | wc -l || echo "0")
        if [[ $fs_errors -gt 0 ]]; then
            print_warning "Filesystem errors detected in system log"
            ((integrity_issues++))
        fi
    fi

    # Check for read-only filesystems
    local readonly_mounts
    readonly_mounts=$(mount 2>/dev/null | grep "(ro)" | wc -l || echo "0")
    if [[ $readonly_mounts -gt 0 ]]; then
        print_warning "Read-only filesystems detected: $readonly_mounts"
        print_info "Cleanup may be limited on read-only filesystems"
    fi

    # Check available inodes
    if command_exists df; then
        local inode_usage
        inode_usage=$(df -i / | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $inode_usage -gt 90 ]]; then
            print_warning "High inode usage: ${inode_usage}%"
            ((integrity_issues++))
        fi
    fi

    if [[ $integrity_issues -gt 0 ]]; then
        print_warning "Filesystem integrity issues detected: $integrity_issues"
        return 1
    else
        print_success "Filesystem integrity checks passed"
        return 0
    fi
}

# Perform comprehensive pre-flight validation
perform_preflight_checks() {
    print_header "Pre-Flight System Validation"
    print_info "Running comprehensive system validation before cleanup"

    local validation_failed=false

    # Initialize module
    init_preflight_checks

    # Run all pre-flight checks
    if ! check_ubuntu_version; then
        validation_failed=true
    fi

    if ! check_system_stability; then
        validation_failed=true
    fi

    if ! check_filesystem_integrity; then
        validation_failed=true
    fi

    if [[ "$validation_failed" == "true" ]]; then
        print_error "Pre-flight validation failed"
        print_info "Resolve reported issues before running cleanup"
        return 1
    else
        print_success "All pre-flight checks passed"
        print_info "System is ready for cleanup operations"
        return 0
    fi
}

# Show pre-flight help
show_preflight_help() {
    cat << EOF
${BOLD}${CYAN}Pre-flight System Checks Module${RESET}
${ITALIC}Comprehensive system validation before cleanup operations${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source preflight-checks.sh${RESET}
    ${GREEN}perform_preflight_checks${RESET}

${BOLD}Functions:${RESET}
    ${YELLOW}check_ubuntu_version${RESET}           Validate Ubuntu version compatibility
    ${YELLOW}check_system_stability${RESET}         Check system load, memory, disk space
    ${YELLOW}check_filesystem_integrity${RESET}     Validate filesystem health
    ${YELLOW}check_network_connectivity${RESET}     Verify network connectivity
    ${YELLOW}check_power_status${RESET}            Check battery level for laptops
    ${YELLOW}perform_preflight_checks${RESET}       Run all pre-flight validations

${BOLD}Validations Performed:${RESET}
    • Ubuntu version compatibility check
    • System load and resource usage
    • Memory usage validation
    • Disk space availability
    • Critical service status
    • Network connectivity
    • Power status (laptops)
    • Filesystem integrity
    • Known system issues detection

${BOLD}Thresholds:${RESET}
    • System load: $MAX_LOAD_THRESHOLD
    • Memory usage: ${MAX_MEMORY_USAGE}%
    • Minimum disk space: ${MIN_DISK_SPACE}MB
    • Critical disk usage: ${CRITICAL_DISK_USAGE}%

EOF
}

# Export functions for use in other scripts
export -f init_preflight_checks check_ubuntu_version check_system_stability
export -f check_filesystem_integrity check_network_connectivity check_power_status
export -f perform_preflight_checks show_preflight_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    perform_preflight_checks
fi