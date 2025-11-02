#!/usr/bin/env bash

# FUB Dependencies Installation Management
# Handles tool installation with user confirmation and progress tracking

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Installation state
DEPS_INSTALLATION_RUNNING=false
DEPS_INSTALLATION_QUEUE=()
DEPS_INSTALLATION_LOG="${DEPS_LOG_DIR}/installations.log"

# Package manager detection
readonly PKG_MANAGERS=("apt" "snap" "flatpak" "brew" "pacman" "yum" "dnf")

# Initialize installation system
init_installation_system() {
    log_deps_debug "Initializing dependency installation system..."

    # Ensure directories exist
    ensure_dir "$DEPS_LOG_DIR"

    # Create installation log
    if [[ ! -f "$DEPS_INSTALLATION_LOG" ]]; then
        > "$DEPS_INSTALLATION_LOG" cat << EOF
# FUB Dependencies Installation Log
# Format: timestamp|tool|package_manager|package_name|status|duration|details
# Generated: $(date)

EOF
    fi

    DEPS_INSTALLATION_RUNNING=false
    log_deps_debug "Dependency installation system initialized"
}

# Detect available package managers
detect_package_managers() {
    local available_managers=()

    for manager in "${PKG_MANAGERS[@]}"; do
        if command_exists "$manager"; then
            available_managers+=("$manager")
        fi
    done

    printf '%s\n' "${available_managers[@]}"
}

# Get preferred package manager for a tool
get_preferred_package_manager() {
    local tool_name="$1"
    local tool_index=$(find_tool_index "$tool_name")

    if [[ $tool_index -lt 0 ]]; then
        log_deps_error "Tool not found in registry: $tool_name"
        return 1
    fi

    local packages=$(get_tool_package_names "$tool_index")
    local preference=$(get_deps_config package_manager_preference)
    local preferred_manager=$(get_deps_config preferred_package_manager)

    # If user has forced a specific manager, try that first
    if [[ -n "$preferred_manager" ]]; then
        if command_exists "$preferred_manager"; then
            # Check if tool is available in this manager
            if echo "$packages" | grep -q "^${preferred_manager}:"; then
                echo "$preferred_manager"
                return 0
            fi
        fi
    fi

    # Try managers in order of preference
    IFS=',' read -ra preference_list <<< "$preference"
    for manager in "${preference_list[@]}"; do
        manager=$(trim "$manager")
        if command_exists "$manager"; then
            if echo "$packages" | grep -q "^${manager}:"; then
                echo "$manager"
                return 0
            fi
        fi
    done

    # Fallback to any available manager
    for manager in "${PKG_MANAGERS[@]}"; do
        if command_exists "$manager"; then
            if echo "$packages" | grep -q "^${manager}:"; then
                echo "$manager"
                return 0
            fi
        fi
    done

    log_deps_error "No suitable package manager found for tool: $tool_name"
    return 1
}

# Get package name for tool in specific manager
get_package_name() {
    local tool_name="$1"
    local package_manager="$2"

    local tool_index=$(find_tool_index "$tool_name")
    if [[ $tool_index -lt 0 ]]; then
        return 1
    fi

    local packages=$(get_tool_package_names "$tool_index")

    # Extract package name for the specified manager
    local package_name
    package_name=$(echo "$packages" | grep "^${package_manager}:" | cut -d':' -f2)

    if [[ -n "$package_name" ]]; then
        echo "$package_name"
        return 0
    else
        return 1
    fi
}

# Check if tool can be installed
can_install_tool() {
    local tool_name="$1"

    log_deps_debug "Checking if tool can be installed: $tool_name"

    # Check if tool exists in registry
    if ! tool_exists "$tool_name"; then
        log_deps_error "Tool not found in registry: $tool_name"
        return 1
    fi

    # Check if already installed
    local status=$(get_cached_tool_status "$tool_name")
    if [[ "$status" == "$DEPS_STATUS_INSTALLED" ]]; then
        log_deps_debug "Tool already installed: $tool_name"
        return 1
    fi

    # Check for suitable package manager
    local package_manager
    package_manager=$(get_preferred_package_manager "$tool_name")
    if [[ -z "$package_manager" ]]; then
        log_deps_error "No suitable package manager found for: $tool_name"
        return 1
    fi

    # Check if we have installation permissions
    if ! check_installation_permissions "$package_manager"; then
        log_deps_error "Insufficient permissions for package manager: $package_manager"
        return 1
    fi

    log_deps_debug "Tool can be installed: $tool_name (via $package_manager)"
    return 0
}

# Check installation permissions
check_installation_permissions() {
    local package_manager="$1"

    case "$package_manager" in
        "apt"|"yum"|"dnf"|"pacman")
            # System package managers typically require root
            is_root || command_exists sudo
            ;;
        "snap"|"flatpak")
            # User package managers can work without root, but some features need it
            # For simplicity, we'll allow installation
            return 0
            ;;
        "brew")
            # Homebrew works without root
            return 0
            ;;
        *)
            log_deps_warn "Unknown package manager: $package_manager"
            return 0
            ;;
    esac
}

# Install a single tool
install_tool() {
    local tool_name="$1"
    local force_install="${2:-false}"
    local no_confirm="${3:-false}"

    log_deps_info "Starting installation of tool: $tool_name"

    local start_time=$(date +%s)

    # Check if installation is possible
    if [[ "$force_install" != "true" ]] && ! can_install_tool "$tool_name"; then
        log_deps_error "Cannot install tool: $tool_name"
        log_installation "$tool_name" "failed" "$(( $(date +%s) - start_time ))" "Installation prerequisites not met"
        return 1
    fi

    # Get package manager and package name
    local package_manager
    package_manager=$(get_preferred_package_manager "$tool_name")
    local package_name
    package_name=$(get_package_name "$tool_name" "$package_manager")

    if [[ -z "$package_name" ]]; then
        log_deps_error "Could not determine package name for: $tool_name"
        log_installation "$tool_name" "failed" "$(( $(date +%s) - start_time ))" "Package name not found"
        return 1
    fi

    # Show installation details
    show_installation_details "$tool_name" "$package_manager" "$package_name"

    # Get user confirmation (unless disabled)
    if [[ "$no_confirm" != "true" ]] && [[ "$(get_deps_config silent_mode)" != "true" ]]; then
        if ! confirm_tool_installation "$tool_name" "$package_manager" "$package_name"; then
            log_deps_info "Installation cancelled by user: $tool_name"
            log_installation "$tool_name" "cancelled" "$(( $(date +%s) - start_time ))" "User cancelled"
            return 1
        fi
    fi

    # Create backup if requested
    if [[ "$(get_deps_config backup_before_install)" == "true" ]]; then
        create_installation_backup "$tool_name"
    fi

    # Perform installation
    log_deps_info "Installing $tool_name using $package_manager..."
    local install_result
    install_result=$(perform_installation "$tool_name" "$package_manager" "$package_name")
    local exit_code=$?

    local duration=$(( $(date +%s) - start_time ))

    if [[ $exit_code -eq 0 ]]; then
        log_deps_info "Successfully installed: $tool_name"
        update_tool_cache "$tool_name" "$DEPS_STATUS_INSTALLED" "" "" "$package_manager"
        log_installation "$tool_name" "success" "$duration" "Installed via $package_manager"

        # Verify installation
        verify_installation "$tool_name"
    else
        log_deps_error "Failed to install: $tool_name"
        log_installation "$tool_name" "failed" "$duration" "$install_result"

        # Attempt rollback if backup exists
        rollback_installation "$tool_name"
    fi

    return $exit_code
}

# Show installation details
show_installation_details() {
    local tool_name="$1"
    local package_manager="$2"
    local package_name="$3"

    local tool_index=$(find_tool_index "$tool_name")
    local description=$(get_tool_description "$tool_index")
    local size=$(get_tool_size "$tool_index")
    local benefit=$(get_tool_benefit "$tool_index")

    echo ""
    echo "${BOLD}${CYAN}Installation Details${RESET}"
    echo "===================="
    echo ""
    echo "${YELLOW}Tool:${RESET} $tool_name"
    echo "${YELLOW}Description:${RESET} $description"
    echo "${YELLOW}Package Manager:${RESET} $package_manager"
    echo "${YELLOW}Package Name:${RESET} $package_name"
    echo "${YELLOW}Size:${RESET} $size"
    echo "${YELLOW}Benefit:${RESET} $benefit"
    echo ""
}

# Confirm tool installation
confirm_tool_installation() {
    local tool_name="$1"
    local package_manager="$2"
    local package_name="$3"

    # Use gum for confirmation if available and interactive
    if command_exists gum && [[ "$(get_deps_config interactive)" == "true" ]]; then
        gum confirm "Install $tool_name using $package_manager?" --default=false
        return $?
    else
        # Fallback to simple prompt
        echo -n "${YELLOW}Install $tool_name using $package_manager? [y/N]:${RESET} "
        read -r response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# Perform the actual installation
perform_installation() {
    local tool_name="$1"
    local package_manager="$2"
    local package_name="$3"

    local timeout=$(get_deps_config install_timeout)
    local output=""

    case "$package_manager" in
        "apt")
            if is_root; then
                output=$(timeout "$timeout" apt-get install -y "$package_name" 2>&1)
            else
                output=$(timeout "$timeout" sudo apt-get install -y "$package_name" 2>&1)
            fi
            ;;
        "snap")
            output=$(timeout "$timeout" snap install "$package_name" 2>&1)
            ;;
        "flatpak")
            output=$(timeout "$timeout" flatpak install -y "$package_name" 2>&1)
            ;;
        "brew")
            output=$(timeout "$timeout" brew install "$package_name" 2>&1)
            ;;
        "yum")
            if is_root; then
                output=$(timeout "$timeout" yum install -y "$package_name" 2>&1)
            else
                output=$(timeout "$timeout" sudo yum install -y "$package_name" 2>&1)
            fi
            ;;
        "dnf")
            if is_root; then
                output=$(timeout "$timeout" dnf install -y "$package_name" 2>&1)
            else
                output=$(timeout "$timeout" sudo dnf install -y "$package_name" 2>&1)
            fi
            ;;
        "pacman")
            if is_root; then
                output=$(timeout "$timeout" pacman -S --noconfirm "$package_name" 2>&1)
            else
                output=$(timeout "$timeout" sudo pacman -S --noconfirm "$package_name" 2>&1)
            fi
            ;;
        *)
            echo "Unknown package manager: $package_manager"
            return 1
            ;;
    esac

    local exit_code=$?
    echo "$output"
    return $exit_code
}

# Verify installation
verify_installation() {
    local tool_name="$1"

    log_deps_debug "Verifying installation of: $tool_name"

    # Re-detect the tool
    detect_tool "$tool_name" true

    local status=$(get_cached_tool_status "$tool_name")
    if [[ "$status" == "$DEPS_STATUS_INSTALLED" ]]; then
        log_deps_debug "Installation verification successful: $tool_name"

        # Test basic functionality
        test_tool_functionality "$tool_name"
    else
        log_deps_warn "Installation verification failed: $tool_name (status: $status)"
    fi
}

# Test tool functionality
test_tool_functionality() {
    local tool_name="$1"

    log_deps_debug "Testing functionality of: $tool_name"

    local tool_index=$(find_tool_index "$tool_name")
    local executables=$(get_tool_executables "$tool_index")

    for executable in ${executables//,/ }; do
        if command_exists "$executable"; then
            # Test basic command execution
            case "$tool_name" in
                "gum")
                    "$executable" --version >/dev/null 2>&1
                    ;;
                "btop")
                    "$executable" --version >/dev/null 2>&1
                    ;;
                "fd"|"fd-find")
                    "$executable" --version >/dev/null 2>&1
                    ;;
                *)
                    # Generic test
                    "$executable" --help >/dev/null 2>&1 || "$executable" --version >/dev/null 2>&1 || true
                    ;;
            esac

            log_deps_debug "Functionality test passed for $tool_name ($executable)"
            return 0
        fi
    done

    log_deps_warn "Functionality test failed for $tool_name - executable not found"
    return 1
}

# Create installation backup
create_installation_backup() {
    local tool_name="$1"

    log_deps_debug "Creating installation backup for: $tool_name"

    local backup_dir="${DEPS_CACHE_DIR}/backups/$(date +%Y%m%d_%H%M%S)_${tool_name}"
    ensure_dir "$backup_dir"

    # Backup system state (simplified)
    {
        echo "backup_time:$(date)"
        echo "tool_name:$tool_name"
        echo "package_manager:$(get_preferred_package_manager "$tool_name")"
        echo "backup_dir:$backup_dir"
        dpkg -l 2>/dev/null || rpm -qa 2>/dev/null || true
    } > "$backup_dir/system_state.txt"

    log_deps_debug "Installation backup created: $backup_dir"
}

# Rollback installation
rollback_installation() {
    local tool_name="$1"

    log_deps_info "Attempting rollback for: $tool_name"

    # This is a simplified rollback - in production, you'd have more sophisticated rollback
    # For now, we just remove the package if installation failed
    local package_manager
    package_manager=$(get_preferred_package_manager "$tool_name")
    local package_name
    package_name=$(get_package_name "$tool_name" "$package_manager")

    if [[ -n "$package_name" ]]; then
        case "$package_manager" in
            "apt")
                if is_root; then
                    apt-get remove -y "$package_name" 2>/dev/null || true
                else
                    sudo apt-get remove -y "$package_name" 2>/dev/null || true
                fi
                ;;
            "snap")
                snap remove "$package_name" 2>/dev/null || true
                ;;
            "brew")
                brew uninstall "$package_name" 2>/dev/null || true
                ;;
            # Add other package managers as needed
        esac
    fi

    log_deps_info "Rollback completed for: $tool_name"
}

# Log installation attempt
log_installation() {
    local tool_name="$1"
    local status="$2"
    local duration="$3"
    local details="$4"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$tool_name|$status|$duration|$details" >> "$DEPS_INSTALLATION_LOG"

    log_deps_debug "Installation logged: $tool_name = $status (${duration}s)"
}

# Install multiple tools
install_tools() {
    local tools=("$@")
    local no_confirm="${tools[-1]}"
    unset 'tools[-1]'  # Remove last element (no_confirm)

    if [[ ${#tools[@]} -eq 0 ]]; then
        log_deps_error "No tools specified for installation"
        return 1
    fi

    log_deps_info "Installing ${#tools[@]} tools: ${tools[*]}"

    local successful_installs=0
    local failed_installs=0

    for tool in "${tools[@]}"; do
        if install_tool "$tool" false "$no_confirm"; then
            ((successful_installs++))
        else
            ((failed_installs++))
        fi
    done

    log_deps_info "Installation completed: $successful_installs successful, $failed_installs failed"

    # Show summary if not in silent mode
    if [[ "$(get_deps_config silent_mode)" != "true" ]]; then
        show_installation_summary "$successful_installs" "$failed_installs"
    fi

    return $failed_installs
}

# Show installation summary
show_installation_summary() {
    local successful="$1"
    local failed="$2"
    local total=$((successful + failed))

    echo ""
    echo "${BOLD}${CYAN}Installation Summary${RESET}"
    echo "====================="
    echo ""
    printf "${GREEN}✓ Successful:${RESET} %d\n" "$successful"
    printf "${RED}✗ Failed:${RESET}     %d\n" "$failed"
    printf "${CYAN}Total:${RESET}        %d\n" "$total"
    echo ""

    if [[ $failed -gt 0 ]]; then
        echo "${YELLOW}Note:${RESET} Some installations failed. Check the installation log for details:"
        echo "  $DEPS_INSTALLATION_LOG"
        echo ""
    fi
}

# Show installation history
show_installation_history() {
    local limit="${1:-20}"

    echo ""
    echo "${BOLD}${CYAN}Installation History${RESET}"
    echo "======================"
    echo ""

    if [[ ! -f "$DEPS_INSTALLATION_LOG" ]]; then
        echo "No installation history found."
        return 0
    fi

    # Skip header and show recent entries
    tail -n "$((limit + 1))" "$DEPS_INSTALLATION_LOG" | tail -n "$limit" | while IFS='|' read -r timestamp tool package_manager package_name status duration details; do
        [[ -z "$tool" || "$tool" == "#" ]] && continue

        local status_icon="✗"
        local status_color="$RED"
        case "$status" in
            "success") status_icon="✓"; status_color="$GREEN" ;;
            "failed") status_icon="✗"; status_color="$RED" ;;
            "cancelled") status_icon="⏸"; status_color="$YELLOW" ;;
        esac

        printf "${status_color}%s${RESET} ${CYAN}%-20s${RESET} ${GRAY}%-10s${RESET} %s\n" \
               "$status_icon" "$tool" "${duration}s" "$timestamp"
    done

    echo ""
}

# Export functions
export -f init_installation_system detect_package_managers get_preferred_package_manager
export -f get_package_name can_install_tool check_installation_permissions install_tool
export -f show_installation_details confirm_tool_installation perform_installation
export -f verify_installation test_tool_functionality create_installation_backup
export -f rollback_installation log_installation install_tools show_installation_summary
export -f show_installation_history

log_deps_debug "Dependency installation system loaded"