#!/usr/bin/env bash

# FUB Cleanup Safety Checks Module (Enhanced)
# Pre-flight validation and safety checks for cleanup operations
# Now integrates with comprehensive safety system

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Check if enhanced safety system is available
if [[ -f "${FUB_SCRIPT_DIR}/lib/safety/safety-integration.sh" ]]; then
    source "${FUB_SCRIPT_DIR}/lib/safety/safety-integration.sh"
    SAFETY_ENHANCED=true
else
    SAFETY_ENHANCED=false
fi

# Safety checks constants
readonly SAFETY_CHECKS_VERSION="2.0.0"
readonly SAFETY_CHECKS_DESCRIPTION="Enhanced pre-flight validation and safety checks"

# Safety configuration
SAFETY_SKIP_BASIC_CHECKS=false
SAFETY_SKIP_ADVANCED_CHECKS=false
SAFETY_ALLOW_AGGRESSIVE=false
SAFETY_BACKUP_IMPORTANT=false
SAFETY_CONFIRM_DESTRUCTIVE=true

# Critical paths and files that should never be removed
declare -a PROTECTED_CRITICAL_PATHS=(
    "/"
    "/boot"
    "/bin"
    "/sbin"
    "/etc"
    "/lib"
    "/lib64"
    "/usr"
    "/var/lib"
    "/home"
    "/root"
    "/proc"
    "/sys"
    "/dev"
)

# Important configuration files to preserve
declare -a PROTECTED_CONFIGS=(
    "/etc/fstab"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/sudoers"
    "/etc/hosts"
    "/etc/hostname"
    "/etc/resolv.conf"
    "/etc/network/interfaces"
    "/etc/ssh/sshd_config"
    "/home/$USER/.ssh"
    "/home/$USER/.bashrc"
    "/home/$USER/.profile"
    "/home/$USER/.zshrc"
)

# Initialize safety checks module
init_safety_checks() {
    log_info "Initializing safety checks module v$SAFETY_CHECKS_VERSION"
    log_debug "Safety checks module initialized"
}

# Check if running with sufficient privileges
check_privileges() {
    print_section "Checking System Privileges"

    local current_user=$(whoami)
    local is_root=false
    local has_sudo=false

    if [[ "$current_user" == "root" ]]; then
        is_root=true
        print_success "Running as root"
    else
        if sudo -n true 2>/dev/null; then
            has_sudo=true
            print_success "User has sudo privileges"
        else
            print_warning "Running without sudo privileges"
            print_info "Some cleanup operations may require elevated privileges"
        fi
    fi

    # Store for later use
    export SAFETY_IS_ROOT="$is_root"
    export SAFETY_HAS_SUDO="$has_sudo"
    export SAFETY_CURRENT_USER="$current_user"

    return 0
}

# Check system stability and load
check_system_stability() {
    print_section "Checking System Stability"

    # Check system load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    local load_number=$(echo "$load_avg" | cut -d',' -f1 | sed 's/^[[:space:]]*//')

    # Convert to integer (multiply by 100)
    local load_int=$(echo "$load_number * 100" | bc 2>/dev/null || echo "0")

    if [[ $load_int -gt 200 ]]; then  # Load > 2.0
        print_warning "High system load detected: $load_avg"
        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "System load is high ($load_avg). Continue with cleanup?" "High system load may cause slow cleanup operations."; then
                print_info "Cleanup cancelled due to high system load"
                return 1
            fi
        fi
    else
        print_success "System load is acceptable: $load_avg"
    fi

    # Check available memory
    if command_exists free; then
        local mem_info
        mem_info=$(free -m | grep "Mem:")
        local total_mem=$(echo "$mem_info" | awk '{print $2}')
        local available_mem=$(echo "$mem_info" | awk '{print $7}')

        local mem_usage_percent=$((100 - (available_mem * 100 / total_mem)))

        if [[ $mem_usage_percent -gt 90 ]]; then
            print_warning "High memory usage: ${mem_usage_percent}%"
            if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
                if ! confirm_with_warning "Memory usage is high (${mem_usage_percent}%). Continue?" "Low memory may affect cleanup performance."; then
                    print_info "Cleanup cancelled due to low memory"
                    return 1
                fi
            fi
        else
            print_success "Memory usage is acceptable: ${mem_usage_percent}%"
        fi
    fi

    # Check disk space for important filesystems
    if command_exists df; then
        local root_usage
        root_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

        if [[ $root_usage -gt 95 ]]; then
            print_warning "Root filesystem is ${root_usage}% full"
            print_info "This is actually why you're running cleanup - proceeding"
        elif [[ $root_usage -gt 85 ]]; then
            print_info "Root filesystem usage is ${root_usage}% - cleanup recommended"
        else
            print_success "Root filesystem has adequate space: ${root_usage}% used"
        fi
    fi

    return 0
}

# Check for important running services
check_running_services() {
    print_section "Checking Important Services"

    local -a critical_services=(
        "sshd"
        "networking"
        "systemd"
        "dbus"
    )

    local -a warning_services=(
        "docker"
        "mysql"
        "postgresql"
        "nginx"
        "apache2"
        "redis"
    )

    local critical_running=0
    local warning_running=0

    # Check critical services
    for service in "${critical_services[@]}"; do
        if is_service_active "$service"; then
            ((critical_running++))
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "success" "$service is running")"
            fi
        fi
    done

    # Check warning services
    for service in "${warning_services[@]}"; do
        if is_service_active "$service"; then
            ((warning_running++))
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "info" "$service is running")"
            fi
        fi
    done

    if [[ $critical_running -gt 0 ]]; then
        print_success "Critical services running: $critical_running"
    else
        print_warning "No critical services detected"
    fi

    if [[ $warning_running -gt 0 ]]; then
        print_info "Other services running: $warning_running"
        print_info "Cleanup may restart or affect these services"
    fi

    return 0
}

# Check for active development environments
check_development_environment() {
    print_section "Checking Development Environment"

    local -a dev_processes=(
        "node"
        "npm"
        "yarn"
        "python"
        "pip"
        "java"
        "mvn"
        "gradle"
        "cargo"
        "rustc"
        "go"
        "docker"
        "git"
    )

    local active_dev_processes=0

    for process in "${dev_processes[@]}"; do
        if pgrep -x "$process" >/dev/null 2>&1; then
            ((active_dev_processes++))
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                local process_count
                process_count=$(pgrep -x "$process" | wc -l)
                print_indented 2 "$(format_status "info" "$process: $process_count processes")"
            fi
        fi
    done

    if [[ $active_dev_processes -gt 0 ]]; then
        print_info "Active development processes: $active_dev_processes"
        print_warning "Consider saving work before running cleanup"

        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Development processes are active. Continue with cleanup?" "Active development may be affected by cleanup operations."; then
                print_info "Cleanup cancelled - development environment active"
                return 1
            fi
        fi
    else
        print_success "No active development processes detected"
    fi

    # Check for open files in development directories
    local -a dev_dirs=(
        "/home/$USER/projects"
        "/home/$USER/dev"
        "/home/$USER/src"
        "/home/$USER/workspace"
        "/home/$USER/code"
    )

    for dev_dir in "${dev_dirs[@]}"; do
        if [[ -d "$dev_dir" ]]; then
            local open_files
            open_files=$(lsof +D "$dev_dir" 2>/dev/null | wc -l || echo "0")
            if [[ $open_files -gt 0 ]]; then
                print_indented 2 "$(format_status "warning" "$open_files files open in $dev_dir")"
            fi
        fi
    done

    return 0
}

# Check for backup and snapshot availability
check_backup_availability() {
    print_section "Checking Backup Availability"

    local backup_found=false

    # Check common backup locations
    local -a backup_locations=(
        "/backup"
        "/mnt/backup"
        "/home/$USER/backup"
        "/home/$USER/.backup"
        "/var/backups"
        "/snapshots"
        "/mnt/snapshots"
    )

    for backup_dir in "${backup_locations[@]}"; do
        if [[ -d "$backup_dir" ]]; then
            local backup_size
            backup_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
            print_indented 2 "$(format_status "success" "Backup found: $backup_dir ($backup_size)")"
            backup_found=true
        fi
    done

    # Check for TimeMachine backups (macOS)
    if command_exists tmutil && [[ "$(uname)" == "Darwin" ]]; then
        if tmutil listlocalsnapshots / 2>/dev/null | grep -q "."; then
            print_indented 2 "$(format_status "success" "TimeMachine local snapshots available")"
            backup_found=true
        fi
    fi

    # Check for Timeshift backups (Linux)
    if command_exists timeshift; then
        if timeshift --list 2>/dev/null | grep -q "."; then
            print_indented 2 "$(format_status "success" "Timeshift backups available")"
            backup_found=true
        fi
    fi

    if [[ "$backup_found" == "true" ]]; then
        print_success "Backups are available"
    else
        print_warning "No obvious backups found"
        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "No backups detected. Continue with cleanup?" "It's recommended to have backups before running cleanup."; then
                print_info "Cleanup cancelled - no backups available"
                return 1
            fi
        fi
    fi

    return 0
}

# Validate paths before cleanup
validate_cleanup_paths() {
    local -a cleanup_paths=("$@")
    print_section "Validating Cleanup Paths"

    for path in "${cleanup_paths[@]}"; do
        # Skip if path doesn't exist
        if [[ ! -e "$path" ]]; then
            print_indented 2 "$(format_status "warning" "Path does not exist: $path")"
            continue
        fi

        local real_path
        real_path=$(realpath "$path")

        # Check against protected critical paths
        for protected in "${PROTECTED_CRITICAL_PATHS[@]}"; do
            if [[ "$real_path" == "$protected"* ]]; then
                print_error "CRITICAL: Path overlaps with protected system directory: $real_path"
                return 1
            fi
        done

        # Check against protected configs
        for protected in "${PROTECTED_CONFIGS[@]}"; do
            if [[ "$real_path" == "$protected" ]]; then
                print_error "CRITICAL: Path is protected configuration: $real_path"
                return 1
            fi
        done

        # Check if path is in user's home directory but not in protected subdirs
        if [[ "$real_path" == "/home/$USER"* ]]; then
            local home_subdir="${real_path#/home/$USER/}"
            case "$home_subdir" in
                ".ssh"|".gnupg"|".config"|".local"|".cache"|".npm"|".cargo"|".rustup"|".pyenv"|".nvm"|".rbenv"|".asdf"|".sdkman"*)
                    print_indented 2 "$(format_status "warning" "Path affects important user directory: $home_subdir")"
                    ;;
                *)
                    print_indented 2 "$(format_status "success" "Path validated: $real_path")"
                    ;;
            esac
        else
            print_indented 2 "$(format_status "success" "Path validated: $real_path")"
        fi
    done

    return 0
}

# Create safety backup of important configurations
create_safety_backup() {
    if [[ "$SAFETY_BACKUP_IMPORTANT" != "true" ]]; then
        return 0
    fi

    print_section "Creating Safety Backup"

    local backup_dir="/tmp/fub_safety_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    local backed_up_files=0

    # Backup important configs
    for config in "${PROTECTED_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            local backup_path="$backup_dir$(dirname "$config")"
            mkdir -p "$backup_path"
            if cp "$config" "$backup_dir$config" 2>/dev/null; then
                ((backed_up_files++))
                if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "success" "Backed up: $config")"
                fi
            fi
        fi
    done

    if [[ $backed_up_files -gt 0 ]]; then
        print_success "Created safety backup: $backup_dir"
        print_info "Backup contains $backed_up_files important files"
        print_info "Backup will be kept for 24 hours"

        # Schedule cleanup of backup directory
        echo "find '$backup_dir' -type f -mtime +1 -delete 2>/dev/null; find '$backup_dir' -type d -empty -delete 2>/dev/null" | at now + 24 hours 2>/dev/null || true
    else
        print_info "No important files to backup"
    fi

    return 0
}

# Perform comprehensive safety check
perform_safety_checks() {
    local -a cleanup_paths=("$@")

    print_header "Pre-Flight Safety Checks"
    print_info "Running comprehensive safety validation"

    # Use enhanced safety system if available
    if [[ "$SAFETY_ENHANCED" == "true" ]]; then
        print_info "Using enhanced safety system"

        # Initialize enhanced safety system
        if ! init_safety_system; then
            print_error "Failed to initialize enhanced safety system"
            return 1
        fi

        # Configure safety level based on existing settings
        local safety_level="standard"
        if [[ "$SAFETY_ALLOW_AGGRESSIVE" == "true" ]]; then
            safety_level="aggressive"
        elif [[ "$SAFETY_SKIP_BASIC_CHECKS" == "true" ]] || [[ "$SAFETY_SKIP_ADVANCED_CHECKS" == "true" ]]; then
            safety_level="conservative"
        fi

        if ! configure_safety_level "$safety_level"; then
            print_error "Failed to configure safety level"
            return 1
        fi

        # Run comprehensive safety checks
        if ! run_safety_checks "all" "${cleanup_paths[@]}"; then
            print_error "Enhanced safety checks failed - aborting cleanup"
            return 1
        fi

        # Create backup if needed
        if [[ "$SAFETY_BACKUP_IMPORTANT" == "true" ]]; then
            if ! create_safety_backup "config"; then
                print_warning "Backup creation failed, proceeding anyway"
            fi
        fi

        print_success "Enhanced safety checks passed"
        print_info "Proceeding with cleanup operations"
        return 0
    else
        print_info "Using legacy safety checks"

        # Legacy safety check implementation
        local check_failed=false

        # Initialize safety configuration
        init_safety_checks

        # Run basic safety checks
        if [[ "$SAFETY_SKIP_BASIC_CHECKS" != "true" ]]; then
            if ! check_privileges; then
                check_failed=true
            fi

            if ! check_system_stability; then
                check_failed=true
            fi
        fi

        # Run advanced safety checks
        if [[ "$SAFETY_SKIP_ADVANCED_CHECKS" != "true" ]]; then
            if ! check_running_services; then
                check_failed=true
            fi

            if ! check_development_environment; then
                check_failed=true
            fi

            if ! check_backup_availability; then
                check_failed=true
            fi
        fi

        # Validate cleanup paths
        if [[ ${#cleanup_paths[@]} -gt 0 ]]; then
            if ! validate_cleanup_paths "${cleanup_paths[@]}"; then
                check_failed=true
            fi
        fi

        # Create safety backup
        if [[ "$check_failed" != "true" ]]; then
            create_safety_backup
        fi

        if [[ "$check_failed" == "true" ]]; then
            print_error "Safety checks failed - aborting cleanup"
            return 1
        else
            print_success "All safety checks passed"
            print_info "Proceeding with cleanup operations"
            return 0
        fi
    fi
}

# Parse safety check arguments
parse_safety_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-basic)
                SAFETY_SKIP_BASIC_CHECKS=true
                shift
                ;;
            --skip-advanced)
                SAFETY_SKIP_ADVANCED_CHECKS=true
                shift
                ;;
            --allow-aggressive)
                SAFETY_ALLOW_AGGRESSIVE=true
                shift
                ;;
            --backup)
                SAFETY_BACKUP_IMPORTANT=true
                shift
                ;;
            --no-confirm)
                SAFETY_CONFIRM_DESTRUCTIVE=false
                shift
                ;;
            --verbose)
                SAFETY_VERBOSE=true
                shift
                ;;
            -h|--help)
                show_safety_help
                exit 0
                ;;
            *)
                log_error "Unknown safety option: $1"
                show_safety_help
                exit 1
                ;;
        esac
    done
}

# Show safety help
show_safety_help() {
    cat << EOF
${BOLD}${CYAN}Safety Checks Module${RESET}
${ITALIC}Pre-flight validation and safety checks for cleanup operations${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source safety-checks.sh${RESET} [${YELLOW}OPTIONS${RESET}]
    ${GREEN}perform_safety_checks${RESET} [${YELLOW}PATHS...${RESET}]

${BOLD}Functions:${RESET}
    ${YELLOW}check_privileges${RESET}              Check user privileges and sudo access
    ${YELLOW}check_system_stability${RESET}        Check system load, memory, disk space
    ${YELLOW}check_running_services${RESET}        Check important running services
    ${YELLOW}check_development_environment${RESET} Check for active development processes
    ${YELLOW}check_backup_availability${RESET}    Check for existing backups
    ${YELLOW}validate_cleanup_paths${RESET}        Validate paths against protected directories
    ${YELLOW}create_safety_backup${RESET}          Backup important configurations
    ${YELLOW}perform_safety_checks${RESET}         Run all safety checks

${BOLD}Options:${RESET}
    ${YELLOW}--skip-basic${RESET}                  Skip basic safety checks
    ${YELLOW}--skip-advanced${RESET}               Skip advanced safety checks
    ${YELLOW}--allow-aggressive${RESET}            Allow aggressive cleanup operations
    ${YELLOW}--backup${RESET}                      Create safety backup of important files
    ${YELLOW}--no-confirm${RESET}                  Skip confirmation prompts
    ${YELLOW}--verbose${RESET}                    Verbose output
    ${YELLOW}-h, --help${RESET}                   Show this help

${BOLD}Safety Features:${RESET}
    • System stability validation
    • Service availability checks
    • Development environment awareness
    • Backup verification
    • Path validation against protected directories
    • Configuration backup creation
    • User confirmation for destructive operations

${BOLD}Protected Items:${RESET}
    • Critical system directories (/bin, /etc, /usr, etc.)
    • Important configuration files
    • User SSH keys and security files
    • Development tools and environments
    • Active databases and services

EOF
}

# Export functions for use in other scripts
export -f init_safety_checks check_privileges check_system_stability
export -f check_running_services check_development_environment check_backup_availability
export -f validate_cleanup_paths create_safety_backup perform_safety_checks
export -f parse_safety_args show_safety_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_safety_args "$@"
    init_safety_checks

    # If no arguments provided, run all safety checks
    if [[ $# -eq 0 ]]; then
        perform_safety_checks
    else
        perform_safety_checks "$@"
    fi
fi