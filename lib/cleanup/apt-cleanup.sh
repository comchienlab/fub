#!/usr/bin/env bash

# FUB Enhanced APT Cleanup Module
# Advanced APT package management cleanup with orphaned package detection and old kernel removal

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Enhanced APT cleanup constants
readonly APT_CLEANUP_VERSION="1.0.0"
readonly APT_CLEANUP_DESCRIPTION="Advanced APT package management cleanup"

# APT cleanup configuration
APT_DRY_RUN=false
APT_VERBOSE=false
APT_FORCE=false
APT_KERNEL_KEEP_COUNT=2
APT_ORPHANED_INCLUDE_CONFIGS=false

# Initialize APT cleanup module
init_apt_cleanup() {
    log_info "Initializing enhanced APT cleanup module v$APT_CLEANUP_VERSION"

    # Check if we have root privileges for APT operations
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_info "Note: Some APT operations may require sudo privileges"
    fi

    log_debug "Enhanced APT cleanup module initialized"
}

# Detect orphaned packages
detect_orphaned_packages() {
    print_section "Detecting Orphaned Packages"

    local -a orphaned_packages=()
    local orphan_count=0

    # Method 1: Use deborphan if available (most reliable)
    if command_exists deborphan; then
        log_debug "Using deborphan to find orphaned packages"

        local deborphan_output
        if deborphan_output=$(deborphan --guess-all --no-show-section 2>/dev/null); then
            while IFS= read -r package; do
                if [[ -n "$package" ]]; then
                    orphaned_packages+=("$package")
                    ((orphan_count++))
                fi
            done <<< "$deborphan_output"
        fi
    else
        log_debug "deborphan not available, using manual orphan detection"

        # Method 2: Manual orphan detection (less accurate but works without deborphan)
        local all_packages
        all_packages=$(dpkg-query -W -f='${Package}\n' 2>/dev/null || true)

        local essential_packages
        essential_packages=$(dpkg-query -W -f='${Package}\n' -W -f='${Pre-Depends}\n' -W -f='${Depends}\n' 2>/dev/null | grep -E '^([^[:space:]]+)$' | sort -u || true)

        while IFS= read -r package; do
            if [[ -n "$package" ]]; then
                # Check if package is essential or required
                if dpkg-query -W -f='${Priority}' "$package" 2>/dev/null | grep -qE '^(required|important|standard)'; then
                    continue
                fi

                # Check if package is manually installed
                if ! apt-mark showmanual | grep -q "^${package}$"; then
                    # Additional check: verify no important packages depend on it
                    local rdepends
                    rdepends=$(apt-cache rdepends "$package" --installed 2>/dev/null | grep -E '^[[:space:]]' | head -5 || true)
                    if [[ -z "$rdepends" ]]; then
                        orphaned_packages+=("$package")
                        ((orphan_count++))
                    fi
                fi
            fi
        done <<< "$all_packages"
    fi

    if [[ $orphan_count -gt 0 ]]; then
        print_success "Found $orphan_count orphaned packages"

        if [[ "$APT_VERBOSE" == "true" ]]; then
            echo ""
            print_info "Orphaned packages:"
            for package in "${orphaned_packages[@]}"; do
                local size
                size=$(dpkg-query -W -f='${Installed-size}' "$package" 2>/dev/null || echo "0")
                print_indented 2 "$package ($(format_bytes $((size * 1024))))"
            done
        fi
    else
        print_info "No orphaned packages found"
    fi

    # Return the orphaned packages list
    printf '%s\n' "${orphaned_packages[@]}"
}

# Clean orphaned packages
cleanup_orphaned_packages() {
    print_section "Cleaning Orphaned Packages"

    local -a orphaned_packages
    readarray -t orphaned_packages < <(detect_orphaned_packages)

    if [[ ${#orphaned_packages[@]} -eq 0 ]]; then
        print_info "No orphaned packages to remove"
        return 0
    fi

    local total_size=0
    local confirmation_message="Remove ${#orphaned_packages[@]} orphaned packages?"

    # Calculate total size
    for package in "${orphaned_packages[@]}"; do
        local size
        size=$(dpkg-query -W -f='${Installed-size}' "$package" 2>/dev/null || echo "0")
        total_size=$((total_size + size * 1024))
    done

    confirmation_message="$confirmation_message (estimated space freed: $(format_bytes $total_size))"

    if [[ "$APT_DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would remove orphaned packages"
        if [[ "$APT_VERBOSE" == "true" ]]; then
            for package in "${orphaned_packages[@]}"; do
                print_indented 2 "Would remove: $package"
            done
        fi
        print_info "Estimated space freed: $(format_bytes $total_size)"
        return 0
    fi

    if [[ "$APT_FORCE" != "true" ]]; then
        if ! confirm_with_warning "$confirmation_message" "This will remove packages that are no longer needed by any installed package."; then
            print_info "Orphaned package cleanup cancelled"
            return 0
        fi
    fi

    # Remove orphaned packages
    local remove_cmd="apt-get remove"
    if [[ "$APT_ORPHANED_INCLUDE_CONFIGS" == "true" ]]; then
        remove_cmd="apt-get purge"
    fi

    if [[ "$APT_VERBOSE" == "true" ]]; then
        remove_cmd="$remove_cmd -o Dpkg::Progress-Fancy=1"
    fi

    if run_sudo $remove_cmd --auto-remove -y "${orphaned_packages[@]}"; then
        print_success "Successfully removed ${#orphaned_packages[@]} orphaned packages"
        print_success "Space freed: $(format_bytes $total_size)"
    else
        print_warning "Failed to remove some orphaned packages"
        return 1
    fi
}

# Detect old kernels
detect_old_kernels() {
    print_section "Detecting Old Kernels"

    local -a installed_kernels=()
    local -a old_kernels=()
    local current_kernel
    current_kernel=$(uname -r)

    # Get all installed kernel packages
    local kernel_packages
    kernel_packages=$(dpkg-query -W -f='${Package}\n' 'linux-image-*' 2>/dev/null | grep -E '^linux-image-[0-9]' || true)

    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            local version
            version=$(echo "$package" | sed 's/linux-image-//')

            # Skip current kernel
            if [[ "$version" == "$current_kernel" ]]; then
                continue
            fi

            # Skip meta-packages
            if [[ "$version" =~ ^(generic|lowlatency|server|virtual)$ ]]; then
                continue
            fi

            installed_kernels+=("$package:$version")
        fi
    done <<< "$kernel_packages"

    # Sort kernels by version (newest first)
    IFS=$'\n' installed_kernels=($(sort -V -t: -k2,2 <<<"${installed_kernels[*]}"))
    unset IFS

    # Keep the specified number of newest kernels
    local keep_count=$((APT_KERNEL_KEEP_COUNT + 1)) # +1 for current kernel

    for ((i=${#installed_kernels[@]}-1; i>=0; i--)); do
        local kernel_entry="${installed_kernels[$i]}"
        local package="${kernel_entry%:*}"
        local version="${kernel_entry#*:}"

        if [[ $i -ge $((${#installed_kernels[@]} - keep_count)) ]]; then
            log_debug "Keeping kernel: $version"
            continue
        fi

        old_kernels+=("$package")
    done

    if [[ ${#old_kernels[@]} -gt 0 ]]; then
        print_success "Found ${#old_kernels[@]} old kernels for removal"

        if [[ "$APT_VERBOSE" == "true" ]]; then
            echo ""
            print_info "Old kernels to remove:"
            for package in "${old_kernels[@]}"; do
                local version=${package#linux-image-}
                print_indented 2 "$version"
            done
        fi
    else
        print_info "No old kernels found (keeping $APT_KERNEL_KEEP_COUNT latest kernels)"
    fi

    # Return the old kernels list
    printf '%s\n' "${old_kernels[@]}"
}

# Clean old kernels
cleanup_old_kernels() {
    print_section "Cleaning Old Kernels"

    local -a old_kernels
    readarray -t old_kernels < <(detect_old_kernels)

    if [[ ${#old_kernels[@]} -eq 0 ]]; then
        print_info "No old kernels to remove"
        return 0
    fi

    local current_kernel
    current_kernel=$(uname -r)
    local confirmation_message="Remove ${#old_kernels[@]} old kernel packages?"

    if [[ "$APT_DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would remove old kernel packages"
        if [[ "$APT_VERBOSE" == "true" ]]; then
            for package in "${old_kernels[@]}"; do
                print_indented 2 "Would remove: $package"
            done
        fi
        return 0
    fi

    if [[ "$APT_FORCE" != "true" ]]; then
        if ! confirm_with_warning "$confirmation_message" "This will remove old kernel versions. Current kernel ($current_kernel) will be preserved."; then
            print_info "Old kernel cleanup cancelled"
            return 0
        fi
    fi

    # Remove old kernels
    local removed_count=0
    local total_size=0

    for package in "${old_kernels[@]}"; do
        local size
        size=$(dpkg-query -W -f='${Installed-size}' "$package" 2>/dev/null || echo "0")
        total_size=$((total_size + size * 1024))

        if run_sudo apt-get remove --auto-remove -y "$package"; then
            ((removed_count++))
            if [[ "$APT_VERBOSE" == "true" ]]; then
                print_indented 2 "Removed: $package"
            fi
        else
            print_warning "Failed to remove: $package"
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        print_success "Successfully removed $removed_count old kernel packages"
        print_success "Space freed: $(format_bytes $total_size)"
    fi
}

# Enhanced package cache cleanup
cleanup_package_cache_enhanced() {
    print_section "Enhanced Package Cache Cleanup"

    local total_freed=0

    # Clean APT cache more thoroughly
    if command_exists apt-get; then
        print_info "Cleaning APT package cache"

        local before_size
        before_size=$(du -sb /var/cache/apt 2>/dev/null | cut -f1) || before_size=0

        if [[ "$APT_DRY_RUN" == "true" ]]; then
            print_info "DRY RUN: Would clean APT cache ($(format_bytes $before_size))"
        else
            # Clean old packages (keep only the latest version)
            if run_sudo apt-get autoclean; then
                log_debug "APT autoclean completed"
            fi

            # Clean downloaded package files completely
            if run_sudo apt-get clean; then
                local after_size
                after_size=$(du -sb /var/cache/apt 2>/dev/null | cut -f1) || after_size=0
                local freed=$((before_size - after_size))
                total_freed=$((total_freed + freed))
                print_success "APT cache cleaned ($(format_bytes $freed) freed)"
            fi
        fi
    fi

    # Clean package archive files
    local archive_dirs=(
        "/var/cache/apt/archives"
        "/var/cache/apt/archives/partial"
    )

    for archive_dir in "${archive_dirs[@]}"; do
        if [[ -d "$archive_dir" ]]; then
            local archive_size=0
            archive_size=$(find "$archive_dir" -name "*.deb" -exec du -sb {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}' || echo "0")

            if [[ $archive_size -gt 0 ]]; then
                if [[ "$APT_DRY_RUN" == "true" ]]; then
                    print_info "DRY RUN: Would remove $(format_bytes $archive_size) of package archives"
                else
                    local deb_count
                    deb_count=$(find "$archive_dir" -name "*.deb" | wc -l)
                    if run_sudo find "$archive_dir" -name "*.deb" -delete 2>/dev/null; then
                        total_freed=$((total_freed + archive_size))
                        print_success "Removed $deb_count package archives ($(format_bytes $archive_size) freed)"
                    fi
                fi
            fi
        fi
    done

    show_cleanup_summary 0 "$total_freed"
}

# Clean old package configuration files
cleanup_old_configs() {
    print_section "Cleaning Old Package Configurations"

    # Find packages that are removed but have config files remaining
    local -a residual_configs=()
    local config_count=0

    local residual_output
    residual_output=$(dpkg-query -W -f='${Package} ${Status}\n' 2>/dev/null | grep 'config-files' | awk '{print $1}' || true)

    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            residual_configs+=("$package")
            ((config_count++))
        fi
    done <<< "$residual_output"

    if [[ $config_count -gt 0 ]]; then
        print_success "Found $config_count packages with residual configuration files"

        if [[ "$APT_VERBOSE" == "true" ]]; then
            echo ""
            print_info "Packages with residual configs:"
            for package in "${residual_configs[@]}"; do
                print_indented 2 "$package"
            done
        fi

        if [[ "$APT_DRY_RUN" != "true" ]]; then
            if [[ "$APT_FORCE" != "true" ]]; then
                if ! confirm_with_warning "Remove configuration files for $config_count packages?" "This will permanently remove configuration files for packages that are no longer installed."; then
                    print_info "Configuration cleanup cancelled"
                    return 0
                fi
            fi

            local removed_count=0
            for package in "${residual_configs[@]}"; do
                if run_sudo dpkg --purge "$package" 2>/dev/null; then
                    ((removed_count++))
                    if [[ "$APT_VERBOSE" == "true" ]]; then
                        print_indented 2 "Purged: $package"
                    fi
                fi
            done

            print_success "Purged configuration files for $removed_count packages"
        fi
    else
        print_info "No residual configuration files found"
    fi
}

# Comprehensive APT cleanup
cleanup_apt_comprehensive() {
    print_header "Comprehensive APT System Cleanup"
    print_info "Performing advanced APT maintenance and cleanup"

    if [[ "$APT_DRY_RUN" == "false" ]] && [[ "$APT_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will perform comprehensive APT cleanup including orphaned packages and old kernels. Continue?" "This operation includes package removal and should be reviewed carefully."; then
            print_info "Comprehensive APT cleanup cancelled"
            return 0
        fi
    fi

    local total_files_removed=0
    local total_space_freed=0

    # Update package lists first
    if [[ "$APT_DRY_RUN" != "true" ]]; then
        print_section "Updating Package Lists"
        if run_sudo apt-get update; then
            print_success "Package lists updated"
        else
            print_warning "Failed to update package lists"
        fi
    fi

    # Perform cleanup operations
    cleanup_orphaned_packages
    cleanup_old_kernels
    cleanup_package_cache_enhanced
    cleanup_old_configs

    # Final autoremove to catch any remaining dependencies
    if [[ "$APT_DRY_RUN" != "true" ]]; then
        print_section "Final Dependency Cleanup"
        if run_sudo apt-get autoremove -y; then
            print_success "Final dependency cleanup completed"
        fi
    fi

    print_header "Comprehensive APT Cleanup Complete"
    print_success "APT system maintenance completed successfully"
}

# Parse APT cleanup arguments
parse_apt_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                APT_FORCE=true
                shift
                ;;
            -n|--dry-run)
                APT_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                APT_VERBOSE=true
                shift
                ;;
            --kernel-count)
                APT_KERNEL_KEEP_COUNT="$2"
                shift 2
                ;;
            --include-configs)
                APT_ORPHANED_INCLUDE_CONFIGS=true
                shift
                ;;
            -h|--help)
                show_apt_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_apt_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Show APT cleanup help
show_apt_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}Enhanced APT Cleanup Module${RESET}
${ITALIC}Advanced APT package management and cleanup utilities${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup apt${RESET} [${YELLOW}ACTION${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Actions:${RESET}
    ${YELLOW}orphans${RESET}                Detect and remove orphaned packages
    ${YELLOW}kernels${RESET}                Remove old kernel versions
    ${YELLOW}cache${RESET}                  Clean package cache thoroughly
    ${YELLOW}configs${RESET}                Remove old package configuration files
    ${YELLOW}comprehensive${RESET}          Perform all APT cleanup operations
    ${YELLOW}all${RESET}                    Alias for comprehensive

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}                    Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}                  Show what would be removed
    ${YELLOW}-v, --verbose${RESET}                  Verbose output
    ${YELLOW}--kernel-count${RESET} NUM             Number of kernels to keep (default: 2)
    ${YELLOW}--include-configs${RESET}              Include configs when removing orphans
    ${YELLOW}-h, --help${RESET}                     Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup apt orphans${RESET}           # Remove orphaned packages
    ${GREEN}fub cleanup apt kernels --dry-run${RESET} # Preview old kernel removal
    ${GREEN}fub cleanup apt comprehensive${RESET}     # Full APT cleanup
    ${GREEN}fub cleanup apt --force --verbose${RESET} # Force cleanup with details

${BOLD}Features:${RESET}
    • Orphaned package detection (with deborphan if available)
    • Safe old kernel removal (keeps current and specified count)
    • Thorough package cache cleaning
    • Residual configuration file cleanup
    • Pre-flight safety checks and confirmations
    • Detailed size calculations and reporting

${BOLD}Safety Features:${RESET}
    • Never removes the currently running kernel
    • Requires confirmation for package removal operations
    • Supports dry-run mode for safe preview
    • Preserves essential system packages
    • Detailed logging and progress reporting

EOF
}

# Format bytes helper (reuse from main cleanup or define here if not available)
if ! command -v format_bytes >/dev/null 2>&1; then
    format_bytes() {
        local bytes=$1
        local units=('B' 'KB' 'MB' 'GB' 'TB')
        local unit=0

        while [[ $bytes -gt 1024 ]] && [[ $unit -lt $((${#units[@]} - 1)) ]]; do
            bytes=$((bytes / 1024))
            ((unit++))
        done

        echo "${bytes}${units[$unit]}"
    }
fi

# Show cleanup summary helper
if ! command -v show_cleanup_summary >/dev/null 2>&1; then
    show_cleanup_summary() {
        local files_removed="$1"
        local space_freed="$2"

        echo ""
        print_section "Cleanup Summary"

        if [[ "$files_removed" -gt 0 ]]; then
            print_success "Packages/files removed: $files_removed"
        fi

        if [[ "$space_freed" -gt 0 ]]; then
            print_success "Space freed: $(format_bytes $space_freed)"
        fi

        if [[ "$APT_DRY_RUN" == "true" ]]; then
            print_info "This was a dry run. No packages were actually removed."
            print_info "Run without --dry-run to perform the cleanup."
        fi
    }
fi

# Export functions for use in main cleanup script
export -f init_apt_cleanup detect_orphaned_packages cleanup_orphaned_packages
export -f detect_old_kernels cleanup_old_kernels cleanup_package_cache_enhanced
export -f cleanup_old_configs cleanup_apt_comprehensive parse_apt_cleanup_args
export -f show_apt_cleanup_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_apt_cleanup
    parse_apt_cleanup_args "$@"

    # Default action if none specified
    local action="${1:-comprehensive}"

    case "$action" in
        orphans)
            cleanup_orphaned_packages
            ;;
        kernels)
            cleanup_old_kernels
            ;;
        cache)
            cleanup_package_cache_enhanced
            ;;
        configs)
            cleanup_old_configs
            ;;
        comprehensive|all)
            cleanup_apt_comprehensive
            ;;
        help|--help|-h)
            show_apt_cleanup_help
            ;;
        *)
            log_error "Unknown APT cleanup action: $action"
            show_apt_cleanup_help
            exit 1
            ;;
    esac
fi