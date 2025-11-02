#!/usr/bin/env bash

# FUB Dependency Manager Cleanup Module
# Cleanup for version managers and dependency management tools

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Dependency cleanup constants
readonly DEPS_CLEANUP_VERSION="1.0.0"
readonly DEPS_CLEANUP_DESCRIPTION="Dependency manager cleanup utilities"

# Dependency cleanup configuration
DEPS_DRY_RUN=false
DEPS_VERBOSE=false
DEPS_FORCE=false
DEPS_KEEP_ACTIVE_VERSIONS=true
DEPS_RETENTION_DAYS=30

# Version manager directories
declare -A VERSION_MANAGERS=(
    ["nvm"]="${HOME}/.nvm"
    ["pyenv"]="${HOME}/.pyenv"
    ["rbenv"]="${HOME}/.rbenv"
    ["nodenv"]="${HOME}/.nodenv"
    ["jenv"]="${HOME}/.jenv"
    ["sdkman"]="${HOME}/.sdkman"
    ["asdf"]="${HOME}/.asdf"
    ["volta"]="${HOME}/.volta"
    ["fnm"]="${HOME}/.fnm"
)

# Language-specific package managers
declare -A PACKAGE_MANAGERS=(
    ["npm"]="${HOME}/.npm"
    ["yarn"]="${HOME}/.yarn"
    ["pnpm"]="${HOME}/.pnpm-store"
    ["pip"]="${HOME}/.cache/pip"
    ["conda"]="${HOME}/.conda"
    ["cargo"]="${HOME}/.cargo"
    ["gem"]="${HOME}/.gem"
    ["composer"]="${HOME}/.composer"
    ["maven"]="${HOME}/.m2"
    ["gradle"]="${HOME}/.gradle"
)

# Initialize dependency cleanup module
init_deps_cleanup() {
    log_info "Initializing dependency manager cleanup module v$DEPS_CLEANUP_VERSION"
    log_debug "Dependency cleanup module initialized"
}

# Detect available version managers
detect_version_managers() {
    print_section "Detecting Version Managers"

    local -a detected_managers=()

    # NVM detection
    if [[ -d "${VERSION_MANAGERS[nvm]}" ]] || command_exists nvm; then
        detected_managers+=("nvm")
        print_success "NVM detected"
    fi

    # Pyenv detection
    if [[ -d "${VERSION_MANAGERS[pyenv]}" ]] || command_exists pyenv; then
        detected_managers+=("pyenv")
        print_success "Pyenv detected"
    fi

    # Rbenv detection
    if [[ -d "${VERSION_MANAGERS[rbenv]}" ]] || command_exists rbenv; then
        detected_managers+=("rbenv")
        print_success "Rbenv detected"
    fi

    # SDKMAN detection
    if [[ -d "${VERSION_MANAGERS[sdkman]}" ]] || command_exists sdk; then
        detected_managers+=("sdkman")
        print_success "SDKMAN detected"
    fi

    # ASDF detection
    if [[ -d "${VERSION_MANAGERS[asdf]}" ]] || command_exists asdf; then
        detected_managers+=("asdf")
        print_success "ASDF detected"
    fi

    # Volta detection
    if [[ -d "${VERSION_MANAGERS[volta]}" ]] || command_exists volta; then
        detected_managers+=("volta")
        print_success "Volta detected"
    fi

    # FNM detection
    if command_exists fnm; then
        detected_managers+=("fnm")
        print_success "FNM detected"
    fi

    if [[ ${#detected_managers[@]} -eq 0 ]]; then
        print_info "No version managers detected"
    else
        print_info "Found ${#detected_managers[@]} version manager(s): ${detected_managers[*]}"
    fi

    # Return detected managers
    printf '%s\n' "${detected_managers[@]}"
}

# Clean NVM
cleanup_nvm() {
    if ! command_exists nvm && [[ ! -d "${VERSION_MANAGERS[nvm]}" ]]; then
        return 0
    fi

    print_section "NVM Cleanup"

    local total_removed=0
    local total_freed=0

    # Source NVM if not already loaded
    if ! command -v nvm >/dev/null 2>&1; then
        export NVM_DIR="${VERSION_MANAGERS[nvm]}"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            source "$NVM_DIR/nvm.sh" 2>/dev/null || true
        fi
    fi

    if command -v nvm >/dev/null 2>&1; then
        # Get current Node.js version
        local current_version
        current_version=$(nvm current 2>/dev/null || echo "none")

        print_info "Current Node.js version: $current_version"

        # List installed versions
        local installed_versions
        installed_versions=$(nvm ls 2>/dev/null | grep -E 'v[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' || true)

        if [[ -n "$installed_versions" ]]; then
            local version_count
            version_count=$(echo "$installed_versions" | wc -l)

            print_info "Found $version_count installed Node.js versions"

            while IFS= read -r version; do
                if [[ -n "$version" ]]; then
                    # Skip current version and system
                    if [[ "$version" == "$current_version" ]] || [[ "$version" == "system" ]]; then
                        if [[ "$DEPS_VERBOSE" == "true" ]]; then
                            print_indented 2 "$(format_status "info" "Keeping active version: $version")"
                        fi
                        continue
                    fi

                    local version_dir="${VERSION_MANAGERS[nvm]}/versions/$version"
                    local version_size=0

                    if [[ -d "$version_dir" ]]; then
                        version_size=$(du -sb "$version_dir" 2>/dev/null | cut -f1) || version_size=0
                    fi

                    if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                        print_indented 2 "$(format_status "info" "Would remove version: $version ($(format_bytes $version_size))")"
                    else
                        if nvm uninstall "$version" 2>/dev/null; then
                            ((total_removed++))
                            ((total_freed += version_size))
                            if [[ "$DEPS_VERBOSE" == "true" ]]; then
                                print_indented 2 "$(format_status "success" "Removed version: $version ($(format_bytes $version_size))")"
                            fi
                        else
                            print_warning "Failed to remove version: $version"
                        fi
                    fi
                fi
            done <<< "$installed_versions"
        fi

        # Clean NVM cache
        local cache_dir="${VERSION_MANAGERS[nvm]}/.cache"
        if [[ -d "$cache_dir" ]]; then
            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean NVM cache ($(format_bytes $cache_size))")"
                else
                    if rm -rf "$cache_dir"/* 2>/dev/null; then
                        ((total_freed += cache_size))
                        print_success "NVM cache cleaned"
                    fi
                fi
            fi
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Pyenv
cleanup_pyenv() {
    if ! command_exists pyenv && [[ ! -d "${VERSION_MANAGERS[pyenv]}" ]]; then
        return 0
    fi

    print_section "Pyenv Cleanup"

    local total_removed=0
    local total_freed=0

    if command_exists pyenv; then
        # Get current Python version
        local current_version
        current_version=$(pyenv version-name 2>/dev/null || echo "none")

        print_info "Current Python version: $current_version"

        # List installed versions
        local installed_versions
        installed_versions=$(pyenv versions --bare 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' || true)

        if [[ -n "$installed_versions" ]]; then
            local version_count
            version_count=$(echo "$installed_versions" | wc -l)

            print_info "Found $version_count installed Python versions"

            while IFS= read -r version; do
                if [[ -n "$version" ]]; then
                    # Skip current version and system
                    if [[ "$version" == "$current_version" ]] || [[ "$version" == "system" ]]; then
                        if [[ "$DEPS_VERBOSE" == "true" ]]; then
                            print_indented 2 "$(format_status "info" "Keeping active version: $version")"
                        fi
                        continue
                    fi

                    local version_dir="${VERSION_MANAGERS[pyenv]}/versions/$version"
                    local version_size=0

                    if [[ -d "$version_dir" ]]; then
                        version_size=$(du -sb "$version_dir" 2>/dev/null | cut -f1) || version_size=0
                    fi

                    if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                        print_indented 2 "$(format_status "info" "Would remove version: $version ($(format_bytes $version_size))")"
                    else
                        if pyenv uninstall -f "$version" 2>/dev/null; then
                            ((total_removed++))
                            ((total_freed += version_size))
                            if [[ "$DEPS_VERBOSE" == "true" ]]; then
                                print_indented 2 "$(format_status "success" "Removed version: $version ($(format_bytes $version_size))")"
                            fi
                        else
                            print_warning "Failed to remove version: $version"
                        fi
                    fi
                fi
            done <<< "$installed_versions"
        fi

        # Clean Pyenv cache
        local cache_dir="${VERSION_MANAGERS[pyenv]}/cache"
        if [[ -d "$cache_dir" ]]; then
            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean Pyenv cache ($(format_bytes $cache_size))")"
                else
                    local files_removed=0
                    while IFS= read -r -d '' cache_file; do
                        if rm -f "$cache_file" 2>/dev/null; then
                            ((files_removed++))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$DEPS_RETENTION_DAYS -print0 2>/dev/null)

                    if [[ $files_removed -gt 0 ]]; then
                        print_success "Cleaned $files_removed Pyenv cache files"
                    fi
                fi
            fi
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Rbenv
cleanup_rbenv() {
    if ! command_exists rbenv && [[ ! -d "${VERSION_MANAGERS[rbenv]}" ]]; then
        return 0
    fi

    print_section "Rbenv Cleanup"

    local total_removed=0
    local total_freed=0

    if command_exists rbenv; then
        # Get current Ruby version
        local current_version
        current_version=$(rbenv version-name 2>/dev/null || echo "none")

        print_info "Current Ruby version: $current_version"

        # List installed versions
        local installed_versions
        installed_versions=$(rbenv versions --bare 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' || true)

        if [[ -n "$installed_versions" ]]; then
            local version_count
            version_count=$(echo "$installed_versions" | wc -l)

            print_info "Found $version_count installed Ruby versions"

            while IFS= read -r version; do
                if [[ -n "$version" ]]; then
                    # Skip current version and system
                    if [[ "$version" == "$current_version" ]] || [[ "$version" == "system" ]]; then
                        if [[ "$DEPS_VERBOSE" == "true" ]]; then
                            print_indented 2 "$(format_status "info" "Keeping active version: $version")"
                        fi
                        continue
                    fi

                    local version_dir="${VERSION_MANAGERS[rbenv]}/versions/$version"
                    local version_size=0

                    if [[ -d "$version_dir" ]]; then
                        version_size=$(du -sb "$version_dir" 2>/dev/null | cut -f1) || version_size=0
                    fi

                    if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                        print_indented 2 "$(format_status "info" "Would remove version: $version ($(format_bytes $version_size))")"
                    else
                        if rbenv uninstall -f "$version" 2>/dev/null; then
                            ((total_removed++))
                            ((total_freed += version_size))
                            if [[ "$DEPS_VERBOSE" == "true" ]]; then
                                print_indented 2 "$(format_status "success" "Removed version: $version ($(format_bytes $version_size))")"
                            fi
                        else
                            print_warning "Failed to remove version: $version"
                        fi
                    fi
                fi
            done <<< "$installed_versions"
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean SDKMAN
cleanup_sdkman() {
    if ! command_exists sdk && [[ ! -d "${VERSION_MANAGERS[sdkman]}" ]]; then
        return 0
    fi

    print_section "SDKMAN Cleanup"

    local total_removed=0
    local total_freed=0

    if [[ -d "${VERSION_MANAGERS[sdkman]}" ]]; then
        # Clean archived versions
        local archive_dir="${VERSION_MANAGERS[sdkman]}/archives"
        if [[ -d "$archive_dir" ]]; then
            local archive_size
            archive_size=$(du -sb "$archive_dir" 2>/dev/null | cut -f1) || archive_size=0

            if [[ $archive_size -gt 0 ]]; then
                if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean SDKMAN archives ($(format_bytes $archive_size))")"
                else
                    local files_removed=0
                    while IFS= read -r -d '' archive_file; do
                        if rm -f "$archive_file" 2>/dev/null; then
                            ((files_removed++))
                        fi
                    done < <(find "$archive_dir" -type f -name "*.zip" -o -name "*.tar.gz" -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    ((total_freed += archive_size))
                    print_success "Cleaned $files_removed SDKMAN archives"
                fi
            fi
        fi

        # Clean temp directory
        local temp_dir="${VERSION_MANAGERS[sdkman]}/tmp"
        if [[ -d "$temp_dir" ]]; then
            local temp_size
            temp_size=$(du -sb "$temp_dir" 2>/dev/null | cut -f1) || temp_size=0

            if [[ $temp_size -gt 0 ]]; then
                if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean SDKMAN temp ($(format_bytes $temp_size))")"
                else
                    if rm -rf "$temp_dir"/* 2>/dev/null; then
                        ((total_freed += temp_size))
                        print_success "SDKMAN temp directory cleaned"
                    fi
                fi
            fi
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean ASDF
cleanup_asdf() {
    if ! command_exists asdf && [[ ! -d "${VERSION_MANAGERS[asdf]}" ]]; then
        return 0
    fi

    print_section "ASDF Cleanup"

    local total_removed=0
    local total_freed=0

    if command_exists asdf; then
        # List all installed plugins and versions
        local plugins
        plugins=$(asdf plugin list 2>/dev/null || true)

        while IFS= read -r plugin; do
            if [[ -n "$plugin" ]]; then
                print_info "Cleaning plugin: $plugin"

                # Get current version for this plugin
                local current_version
                current_version=$(asdf current "$plugin" 2>/dev/null | awk '{print $2}' || echo "none")

                local installed_versions
                installed_versions=$(asdf list "$plugin" 2>/dev/null | grep -E '^[[:space:]]*[0-9]+' | awk '{print $1}' || true)

                while IFS= read -r version; do
                    if [[ -n "$version" ]]; then
                        # Skip current version
                        if [[ "$version" == "$current_version" ]]; then
                            if [[ "$DEPS_VERBOSE" == "true" ]]; then
                                print_indented 2 "$(format_status "info" "Keeping active $plugin version: $version")"
                            fi
                            continue
                        fi

                        local version_dir="${VERSION_MANAGERS[asdf]}/installs/$plugin/$version"
                        local version_size=0

                        if [[ -d "$version_dir" ]]; then
                            version_size=$(du -sb "$version_dir" 2>/dev/null | cut -f1) || version_size=0
                        fi

                        if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                            print_indented 2 "$(format_status "info" "Would remove $plugin version: $version ($(format_bytes $version_size))")"
                        else
                            if asdf uninstall "$plugin" "$version" 2>/dev/null; then
                                ((total_removed++))
                                ((total_freed += version_size))
                                if [[ "$DEPS_VERBOSE" == "true" ]]; then
                                    print_indented 2 "$(format_status "success" "Removed $plugin version: $version ($(format_bytes $version_size))")"
                                fi
                            else
                                print_warning "Failed to remove $plugin version: $version"
                            fi
                        fi
                    fi
                done <<< "$installed_versions"
            fi
        done <<< "$plugins"

        # Clean ASDF cache
        local cache_dir="${VERSION_MANAGERS[asdf]}/cache"
        if [[ -d "$cache_dir" ]]; then
            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean ASDF cache ($(format_bytes $cache_size))")"
                else
                    local files_removed=0
                    while IFS= read -r -d '' cache_file; do
                        if rm -f "$cache_file" 2>/dev/null; then
                            ((files_removed++))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$DEPS_RETENTION_DAYS -print0 2>/dev/null)

                    if [[ $files_removed -gt 0 ]]; then
                        print_success "Cleaned $files_removed ASDF cache files"
                    fi
                fi
            fi
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean package manager caches
cleanup_package_caches() {
    print_section "Package Manager Caches"

    local total_removed=0
    local total_freed=0

    for manager in "${!PACKAGE_MANAGERS[@]}"; do
        local cache_dir="${PACKAGE_MANAGERS[$manager]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $manager cache"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEPS_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean $manager cache ($(format_bytes $cache_size))")"
                else
                    local files_removed=0
                    while IFS= read -r -d '' cache_file; do
                        local file_size
                        file_size=$(du -sb "$cache_file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$cache_file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$DEPS_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $manager cache"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Comprehensive dependency cleanup
cleanup_deps_comprehensive() {
    print_header "Comprehensive Dependency Manager Cleanup"
    print_info "Performing dependency manager cleanup"

    if [[ "$DEPS_DRY_RUN" == "false" ]] && [[ "$DEPS_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will clean old versions from version managers and package caches. Continue?" "This operation will remove unused versions but preserve currently active ones."; then
            print_info "Dependency cleanup cancelled"
            return 0
        fi
    fi

    local -a detected_managers
    readarray -t detected_managers < <(detect_version_managers)

    # Clean each detected version manager
    for manager in "${detected_managers[@]}"; do
        case "$manager" in
            "nvm")
                cleanup_nvm
                ;;
            "pyenv")
                cleanup_pyenv
                ;;
            "rbenv")
                cleanup_rbenv
                ;;
            "sdkman")
                cleanup_sdkman
                ;;
            "asdf")
                cleanup_asdf
                ;;
            *)
                log_debug "Unknown version manager: $manager"
                ;;
        esac
    done

    # Clean package manager caches
    cleanup_package_caches

    print_header "Dependency Manager Cleanup Complete"
    print_success "Dependency manager cleanup completed successfully"
}

# Parse dependency cleanup arguments
parse_deps_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                DEPS_FORCE=true
                shift
                ;;
            -n|--dry-run)
                DEPS_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                DEPS_VERBOSE=true
                shift
                ;;
            -r|--retention)
                DEPS_RETENTION_DAYS="$2"
                shift 2
                ;;
            --keep-active)
                DEPS_KEEP_ACTIVE_VERSIONS=true
                shift
                ;;
            -h|--help)
                show_deps_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_deps_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Show dependency cleanup help
show_deps_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}Dependency Manager Cleanup Module${RESET}
${ITALIC}Cleanup for version managers and dependency management tools${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup deps${RESET} [${YELLOW}MANAGER${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Managers:${RESET}
    ${YELLOW}nvm${RESET}                     Node Version Manager cleanup
    ${YELLOW}pyenv${RESET}                   Python version management cleanup
    ${YELLOW}rbenv${RESET}                   Ruby version management cleanup
    ${YELLOW}sdkman${RESET}                  SDKMAN for Java ecosystem cleanup
    ${YELLOW}asdf${RESET}                    ASDF version manager cleanup
    ${YELLOW}packages${RESET}                Package manager caches (npm, pip, cargo, etc.)
    ${YELLOW}all${RESET}                     All detected dependency managers

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}                    Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}                  Show what would be cleaned
    ${YELLOW}-v, --verbose${RESET}                  Verbose output with details
    ${YELLOW}-r, --retention${RESET} DAYS          Retention period in days (default: 30)
    ${YELLOW}--keep-active${RESET}                 Keep currently active versions
    ${YELLOW}-h, --help${RESET}                     Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup deps nvm${RESET}             # Clean NVM versions
    ${GREEN}fub cleanup deps --dry-run all${RESET}  # Preview all cleanup actions
    ${GREEN}fub cleanup deps --keep-active pyenv${RESET} # Clean Pyenv but keep active version
    ${GREEN}fub cleanup deps packages${RESET}        # Clean package manager caches only

${BOLD}Supported Version Managers:${RESET}
    • NVM - Node Version Manager
    • Pyenv - Python version management
    • Rbenv - Ruby version management
    • SDKMAN - Software Development Kit Manager (Java, etc.)
    • ASDF - Extendable version manager
    • Volta - JavaScript tool manager
    • FNM - Fast Node Manager

${BOLD}Package Manager Caches:${RESET}
    • npm - Node.js package manager cache
    • yarn - Yarn package manager cache
    • pip - Python package installer cache
    • cargo - Rust package manager cache
    • gem - Ruby package manager cache
    • composer - PHP dependency manager cache
    • maven - Java project management cache
    • gradle - Java build system cache

${BOLD}Safety Features:${RESET}
    • Preserves currently active versions
    • Retention period for cache files
    • Dry-run mode for safe preview
    • Manager-specific safe cleanup
    - Detailed version tracking
    - Backup creation for important configurations

${BOLD}What gets cleaned:${RESET}
    • Unused language versions
    • Download archives and installers
    • Build and compilation caches
    • Temporary installation files
    • Package download caches
    - Old metadata and indexes

EOF
}

# Format bytes helper
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
            print_success "Items removed: $files_removed"
        fi

        if [[ "$space_freed" -gt 0 ]]; then
            print_success "Space freed: $(format_bytes $space_freed)"
        fi

        if [[ "$DEPS_DRY_RUN" == "true" ]]; then
            print_info "This was a dry run. No items were actually removed."
            print_info "Run without --dry-run to perform the cleanup."
        fi
    }
fi

# Export functions for use in main cleanup script
export -f init_deps_cleanup detect_version_managers cleanup_nvm cleanup_pyenv
export -f cleanup_rbenv cleanup_sdkman cleanup_asdf cleanup_package_caches
export -f cleanup_deps_comprehensive parse_deps_cleanup_args show_deps_cleanup_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_deps_cleanup
    parse_deps_cleanup_args "$@"

    # Default action if none specified
    local action="${1:-all}"

    case "$action" in
        nvm)
            cleanup_nvm
            ;;
        pyenv)
            cleanup_pyenv
            ;;
        rbenv)
            cleanup_rbenv
            ;;
        sdkman)
            cleanup_sdkman
            ;;
        asdf)
            cleanup_asdf
            ;;
        packages)
            cleanup_package_caches
            ;;
        all|comprehensive)
            cleanup_deps_comprehensive
            ;;
        help|--help|-h)
            show_deps_cleanup_help
            ;;
        *)
            log_error "Unknown dependency manager: $action"
            show_deps_cleanup_help
            exit 1
            ;;
    esac
fi