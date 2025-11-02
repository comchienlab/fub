#!/usr/bin/env bash

# FUB Cleanup Module
# System cleanup and maintenance utilities

set -euo pipefail

# Source parent libraries
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/ui.sh"
source "${FUB_ROOT_DIR}/lib/config.sh"
source "${FUB_ROOT_DIR}/lib/theme.sh"

# Cleanup module metadata
readonly CLEANUP_VERSION="1.0.0"
readonly CLEANUP_DESCRIPTION="System cleanup and maintenance utilities"

# Cleanup constants
readonly TEMP_DIRS=(
    "/tmp"
    "/var/tmp"
    "${HOME}/.cache"
    "${HOME}/.local/share/Trash/files"
)

readonly LOG_DIRS=(
    "/var/log"
    "${HOME}/.local/share/fub/logs"
)

readonly CACHE_DIRS=(
    "/var/cache/apt"
    "${HOME}/.cache"
    "${HOME}/.thumbnails"
)

# Cleanup configuration
CLEANUP_DRY_RUN=false
CLEANUP_VERBOSE=false
CLEANUP_FORCE=false
CLEANUP_RETENTION_DAYS=7

# Initialize cleanup module
init_cleanup() {
    log_info "Initializing cleanup module v$CLEANUP_VERSION"

    # Load cleanup configuration
    load_cleanup_config

    # Validate cleanup configuration
    validate_cleanup_config

    log_info "Cleanup module initialized"
}

# Initialize enhanced cleanup modules
initialize_enhanced_modules() {
    log_debug "Initializing enhanced cleanup modules"

    # Set up module paths
    readonly APT_CLEANUP_SCRIPT="${FUB_SCRIPT_DIR}/cleanup/apt-cleanup.sh"
    readonly DEV_CLEANUP_SCRIPT="${FUB_SCRIPT_DIR}/cleanup/dev-cleanup.sh"
    readonly CONTAINER_CLEANUP_SCRIPT="${FUB_SCRIPT_DIR}/cleanup/container-cleanup.sh"
    readonly IDE_CLEANUP_SCRIPT="${FUB_SCRIPT_DIR}/cleanup/ide-cleanup.sh"
    readonly BUILD_CLEANUP_SCRIPT="${FUB_SCRIPT_DIR}/cleanup/build-cleanup.sh"
    readonly DEPS_CLEANUP_SCRIPT="${FUB_SCRIPT_DIR}/cleanup/deps-cleanup.sh"

    # Check if enhanced modules are available
    local available_modules=()

    [[ -f "$APT_CLEANUP_SCRIPT" ]] && available_modules+=("apt")
    [[ -f "$DEV_CLEANUP_SCRIPT" ]] && available_modules+=("dev")
    [[ -f "$CONTAINER_CLEANUP_SCRIPT" ]] && available_modules+=("containers")
    [[ -f "$IDE_CLEANUP_SCRIPT" ]] && available_modules+=("ide")
    [[ -f "$BUILD_CLEANUP_SCRIPT" ]] && available_modules+=("build")
    [[ -f "$DEPS_CLEANUP_SCRIPT" ]] && available_modules+=("deps")

    if [[ ${#available_modules[@]} -gt 0 ]]; then
        log_debug "Enhanced cleanup modules available: ${available_modules[*]}"
    else
        log_debug "No enhanced cleanup modules found"
    fi
}

# Load cleanup configuration
load_cleanup_config() {
    log_debug "Loading cleanup configuration..."

    CLEANUP_RETENTION_DAYS=$(get_config "cleanup_retention" "7")
    CLEANUP_DRY_RUN=$(get_config "system.dry_run" "false")
    CLEANUP_VERBOSE=$(get_config "ui.verbose" "false")

    log_debug "Cleanup config: retention=${CLEANUP_RETENTION_DAYS} days, dry_run=${CLEANUP_DRY_RUN}"
}

# Cleanup command handler
cleanup_command() {
    local action="${1:-help}"

    # Run safety checks before any cleanup operation (unless explicitly skipped)
    if [[ "${action}" != "help" ]] && [[ "${action}" != "--help" ]] && [[ "${action}" != "-h" ]]; then
        # Load safety checks module only when needed
        if [[ -f "${FUB_SCRIPT_DIR}/cleanup/safety-checks.sh" ]]; then
            source "${FUB_SCRIPT_DIR}/cleanup/safety-checks.sh"
            if ! perform_safety_checks; then
                log_error "Safety checks failed - aborting cleanup"
                exit 1
            fi
        fi
    fi

    # Initialize enhanced cleanup modules
    initialize_enhanced_modules

    case "$action" in
        temp)
            cleanup_temp_files "$@"
            ;;
        cache)
            cleanup_cache_files "$@"
            ;;
        logs)
            cleanup_log_files "$@"
            ;;
        packages)
            cleanup_package_cache "$@"
            ;;
        thumbnails)
            cleanup_thumbnails "$@"
            ;;
        # Enhanced cleanup categories
        apt)
            shift
            "${FUB_SCRIPT_DIR}/cleanup/apt-cleanup.sh" "$@"
            ;;
        dev|development)
            shift
            "${FUB_SCRIPT_DIR}/cleanup/dev-cleanup.sh" "$@"
            ;;
        containers|docker)
            shift
            "${FUB_SCRIPT_DIR}/cleanup/container-cleanup.sh" "$@"
            ;;
        ide|editor)
            shift
            "${FUB_SCRIPT_DIR}/cleanup/ide-cleanup.sh" "$@"
            ;;
        build|artifacts)
            shift
            "${FUB_SCRIPT_DIR}/cleanup/build-cleanup.sh" "$@"
            ;;
        deps|dependencies)
            shift
            "${FUB_SCRIPT_DIR}/cleanup/deps-cleanup.sh" "$@"
            ;;
        enhanced|advanced)
            cleanup_enhanced_comprehensive "$@"
            ;;
        all)
            cleanup_all "$@"
            ;;
        disk)
            analyze_disk_usage "$@"
            ;;
        help|--help|-h)
            show_cleanup_help
            ;;
        *)
            log_error "Unknown cleanup action: $action"
            show_cleanup_help
            exit 1
            ;;
    esac
}

# Show cleanup help
show_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}FUB Cleanup Module${RESET}
${ITALIC}System cleanup and maintenance utilities${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup${RESET} [${YELLOW}ACTION${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Basic Actions:${RESET}
    ${YELLOW}temp${RESET}                     Clean temporary files
    ${YELLOW}cache${RESET}                    Clean system caches
    ${YELLOW}logs${RESET}                     Clean old log files
    ${YELLOW}packages${RESET}                 Clean package caches
    ${YELLOW}thumbnails${RESET}               Clean thumbnail cache
    ${YELLOW}all${RESET}                      Clean all of the above
    ${YELLOW}disk${RESET}                     Analyze disk usage

${BOLD}Enhanced Actions:${RESET}
    ${YELLOW}apt${RESET}                      Enhanced APT cleanup (orphans, kernels)
    ${YELLOW}dev${RESET}                      Development environment cleanup
    ${YELLOW}containers${RESET}                Docker/Podman cleanup
    ${YELLOW}ide${RESET}                      IDE/editor cache cleanup
    ${YELLOW}build${RESET}                    Build artifact cleanup (git-aware)
    ${YELLOW}deps${RESET}                     Dependency manager cleanup
    ${YELLOW}enhanced${RESET}                 All enhanced categories + basic

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}              Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}            Show what would be deleted
    ${YELLOW}-r, --retention${RESET} DAYS     Set retention period (default: 7)
    ${YELLOW}-v, --verbose${RESET}            Verbose output
    ${YELLOW}-h, --help${RESET}               Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup temp${RESET}              # Clean temporary files
    ${GREEN}fub cleanup --dry-run all${RESET}     # Preview all cleanup actions
    ${GREEN}fub cleanup --force cache${RESET}     # Clean cache without confirmation
    ${GREEN}fub cleanup --retention 14 logs${RESET} # Clean logs older than 14 days
    ${GREEN}fub cleanup apt orphans${RESET}       # Remove orphaned APT packages
    ${GREEN}fub cleanup dev --dry-run${RESET}     # Preview development cleanup
    ${GREEN}fub cleanup enhanced${RESET}          # Full enhanced cleanup

${BOLD}What gets cleaned:${RESET}
${ITALIC}Basic:${RESET}
    • Temporary files older than retention period
    • Package caches (apt, snap, flatpak)
    • Thumbnail caches
    • Old log files
    • Browser caches (with confirmation)
    • Trash files

${ITALIC}Enhanced:${RESET}
    • Orphaned APT packages and old kernels
    • Development tool caches (npm, pip, cargo, etc.)
    • Docker/Podman containers, images, volumes
    • IDE/editor caches and temporary files
    • Build artifacts (git-aware, respects .gitignore)
    • Version manager installations (nvm, pyenv, etc.)
    • Package manager caches and archives

EOF
}

# Clean temporary files
cleanup_temp_files() {
    local retention_days="${1:-$CLEANUP_RETENTION_DAYS}"

    print_header "Temporary Files Cleanup"
    print_info "Cleaning files older than $retention_days days"

    local total_removed=0
    local total_freed=0

    for temp_dir in "${TEMP_DIRS[@]}"; do
        if [[ ! -d "$temp_dir" ]]; then
            log_debug "Temp directory not found: $temp_dir"
            continue
        fi

        print_section "Cleaning $temp_dir"

        # Find and clean old files
        local files_removed=0
        local space_freed=0

        while IFS= read -r -d '' file; do
            local file_size
            file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

            if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
                if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would remove: $(basename "$file") ($(format_bytes $file_size))")"
                fi
            else
                if rm -rf "$file" 2>/dev/null; then
                    ((files_removed++))
                    ((space_freed += file_size))
                    if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                        print_indented 2 "$(format_status "success" "Removed: $(basename "$file") ($(format_bytes $file_size))")"
                    fi
                else
                    log_debug "Failed to remove: $file"
                fi
            fi
        done < <(find "$temp_dir" -type f -mtime +$retention_days -print0 2>/dev/null)

        ((total_removed += files_removed))
        ((total_freed += space_freed))

        print_success "Cleaned $files_removed files from $temp_dir"
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean cache files
cleanup_cache_files() {
    local retention_days="${1:-$CLEANUP_RETENTION_DAYS}"

    print_header "Cache Cleanup"
    print_info "Cleaning cache files older than $retention_days days"

    local total_removed=0
    local total_freed=0

    # System package cache
    print_section "Package Cache"
    if is_package_installed "apt"; then
        local apt_cache_size
        apt_cache_size=$(du -sb /var/cache/apt 2>/dev/null | cut -f1) || apt_cache_size=0

        if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean APT cache ($(format_bytes $apt_cache_size))")"
        else
            if apt-get clean 2>/dev/null; then
                ((total_freed += apt_cache_size))
                print_success "APT cache cleaned"
            else
                print_warning "Failed to clean APT cache"
            fi
        fi
    fi

    # User cache directories
    for cache_dir in "${CACHE_DIRS[@]}"; do
        if [[ ! -d "$cache_dir" ]]; then
            log_debug "Cache directory not found: $cache_dir"
            continue
        fi

        if [[ "$cache_dir" == "/var/cache/apt" ]]; then
            continue  # Already handled above
        fi

        print_section "Cleaning $cache_dir"

        local files_removed=0
        local space_freed=0

        while IFS= read -r -d '' file; do
            local file_size
            file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

            if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
                if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would remove: $(basename "$file") ($(format_bytes $file_size))")"
                fi
            else
                if rm -rf "$file" 2>/dev/null; then
                    ((files_removed++))
                    ((space_freed += file_size))
                    if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                        print_indented 2 "$(format_status "success" "Removed: $(basename "$file") ($(format_bytes $file_size))")"
                    fi
                fi
            fi
        done < <(find "$cache_dir" -type f -mtime +$retention_days -print0 2>/dev/null)

        ((total_removed += files_removed))
        ((total_freed += space_freed))

        print_success "Cleaned $files_removed files from $cache_dir"
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean log files
cleanup_log_files() {
    local retention_days="${1:-$(get_config "cleanup_log_retention" "30")}"

    print_header "Log Files Cleanup"
    print_info "Cleaning log files older than $retention_days days"

    local total_removed=0
    local total_freed=0

    for log_dir in "${LOG_DIRS[@]}"; do
        if [[ ! -d "$log_dir" ]]; then
            log_debug "Log directory not found: $log_dir"
            continue
        fi

        print_section "Cleaning $log_dir"

        local files_removed=0
        local space_freed=0

        while IFS= read -r -d '' file; do
            # Skip important log files
            case "$(basename "$file")" in
                syslog|kern.log|auth.log|messages|debug)
                    log_debug "Skipping important log file: $file"
                    continue
                    ;;
            esac

            local file_size
            file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

            if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
                if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would remove: $(basename "$file") ($(format_bytes $file_size))")"
                fi
            else
                if rm -f "$file" 2>/dev/null; then
                    ((files_removed++))
                    ((space_freed += file_size))
                    if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                        print_indented 2 "$(format_status "success" "Removed: $(basename "$file") ($(format_bytes $file_size))")"
                    fi
                fi
            fi
        done < <(find "$log_dir" -type f -name "*.log*" -mtime +$retention_days -print0 2>/dev/null)

        ((total_removed += files_removed))
        ((total_freed += space_freed))

        print_success "Cleaned $files_removed log files from $log_dir"
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean package cache
cleanup_package_cache() {
    print_header "Package Cache Cleanup"

    local total_freed=0

    # APT cache
    if command_exists apt-get; then
        print_section "APT Package Cache"

        local before_size
        before_size=$(du -sb /var/cache/apt 2>/dev/null | cut -f1) || before_size=0

        if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean APT cache ($(format_bytes $before_size))")"
        else
            if run_sudo apt-get clean; then
                local after_size
                after_size=$(du -sb /var/cache/apt 2>/dev/null | cut -f1) || after_size=0
                local freed=$((before_size - after_size))
                ((total_freed += freed))
                print_success "APT cache cleaned ($(format_bytes $freed) freed)"
            else
                print_warning "Failed to clean APT cache"
            fi
        fi
    fi

    # Snap cache
    if command_exists snap; then
        print_section "Snap Package Cache"

        if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean old snap revisions")"
        else
            if run_sudo snap set system refresh.retain=2; then
                print_success "Snap cache retention set to 2 revisions"
            else
                print_warning "Failed to configure snap cache retention"
            fi
        fi
    fi

    # Flatpak cache
    if command_exists flatpak; then
        print_section "Flatpak Package Cache"

        if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean unused Flatpak runtimes")"
        else
            if flatpak uninstall --unused -y 2>/dev/null; then
                print_success "Unused Flatpak runtimes removed"
            else
                print_warning "Failed to clean Flatpak cache"
            fi
        fi
    fi

    show_cleanup_summary 0 "$total_freed"
}

# Clean thumbnail cache
cleanup_thumbnails() {
    print_header "Thumbnail Cache Cleanup"

    local total_removed=0
    local total_freed=0

    local thumbnail_dir="${HOME}/.thumbnails"
    if [[ ! -d "$thumbnail_dir" ]]; then
        print_info "Thumbnail directory not found: $thumbnail_dir"
        return 0
    fi

    # Remove thumbnails older than 30 days
    while IFS= read -r -d '' file; do
        local file_size
        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

        if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
            if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would remove: $(basename "$file") ($(format_bytes $file_size))")"
            fi
        else
            if rm -f "$file" 2>/dev/null; then
                ((total_removed++))
                ((total_freed += file_size))
                if [[ "$CLEANUP_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "success" "Removed: $(basename "$file") ($(format_bytes $file_size))")"
                fi
            fi
        fi
    done < <(find "$thumbnail_dir" -type f -mtime +30 -print0 2>/dev/null)

    print_success "Cleaned $total_removed thumbnail files"
    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean all
cleanup_all() {
    print_header "Complete System Cleanup"
    print_info "Performing comprehensive system cleanup"

    if [[ "$CLEANUP_DRY_RUN" == "false" ]] && [[ "$CLEANUP_FORCE" == "false" ]]; then
        if ! ask_confirmation "This will clean temporary files, caches, and logs. Continue?"; then
            print_info "Cleanup cancelled"
            return 0
        fi
    fi

    local total_files_removed=0
    local total_space_freed=0

    # Perform all cleanup operations
    cleanup_temp_files_and_summarize
    cleanup_cache_files_and_summarize
    cleanup_log_files_and_summarize
    cleanup_package_cache
    cleanup_thumbnails

    # Empty trash if exists
    if [[ -d "${HOME}/.local/share/Trash/files" ]]; then
        print_section "Emptying Trash"
        local trash_size
        trash_size=$(du -sb "${HOME}/.local/share/Trash/files" 2>/dev/null | cut -f1) || trash_size=0

        if [[ $trash_size -gt 0 ]]; then
            if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would empty trash ($(format_bytes $trash_size))")"
            else
                if rm -rf "${HOME}/.local/share/Trash/files/"* 2>/dev/null; then
                    ((total_space_freed += trash_size))
                    print_success "Trash emptied ($(format_bytes $trash_size) freed)"
                fi
            fi
        fi
    fi

    print_header "Cleanup Complete"
    print_success "System cleanup completed successfully"
}

# Helper functions for cleanup_all
cleanup_temp_files_and_summarize() {
    # This would call cleanup_temp_files but return summary data
    cleanup_temp_files "$CLEANUP_RETENTION_DAYS"
}

cleanup_cache_files_and_summarize() {
    # This would call cleanup_cache_files but return summary data
    cleanup_cache_files "$CLEANUP_RETENTION_DAYS"
}

cleanup_log_files_and_summarize() {
    # This would call cleanup_log_files but return summary data
    cleanup_log_files "$(get_config "cleanup_log_retention" "30")"
}

# Enhanced comprehensive cleanup with all new categories
cleanup_enhanced_comprehensive() {
    print_header "Enhanced Comprehensive System Cleanup"
    print_info "Performing advanced cleanup with all enhanced categories"

    if [[ "$CLEANUP_DRY_RUN" == "false" ]] && [[ "$CLEANUP_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will perform comprehensive system cleanup including enhanced categories. Continue?" "This includes APT packages, development tools, containers, IDEs, build artifacts, and dependency managers."; then
            print_info "Enhanced cleanup cancelled"
            return 0
        fi
    fi

    # Initialize enhanced modules
    initialize_enhanced_modules

    # Run basic cleanup first
    print_section "Basic System Cleanup"
    cleanup_temp_files "$CLEANUP_RETENTION_DAYS"
    cleanup_cache_files "$CLEANUP_RETENTION_DAYS"
    cleanup_log_files "$(get_config "cleanup_log_retention" "30")"
    cleanup_package_cache
    cleanup_thumbnails

    # Run enhanced cleanup categories
    echo ""
    print_header "Enhanced Cleanup Categories"

    # APT enhanced cleanup
    if [[ -f "$APT_CLEANUP_SCRIPT" ]]; then
        print_section "APT Enhanced Cleanup"
        "$APT_CLEANUP_SCRIPT" comprehensive --force
    else
        print_info "APT enhanced cleanup module not available"
    fi

    # Development environment cleanup
    if [[ -f "$DEV_CLEANUP_SCRIPT" ]]; then
        print_section "Development Environment Cleanup"
        "$DEV_CLEANUP_SCRIPT" all --force
    else
        print_info "Development environment cleanup module not available"
    fi

    # Container cleanup
    if [[ -f "$CONTAINER_CLEANUP_SCRIPT" ]]; then
        print_section "Container Runtime Cleanup"
        "$CONTAINER_CLEANUP_SCRIPT" all --force
    else
        print_info "Container cleanup module not available"
    fi

    # IDE/Editor cleanup
    if [[ -f "$IDE_CLEANUP_SCRIPT" ]]; then
        print_section "IDE/Editor Cleanup"
        "$IDE_CLEANUP_SCRIPT" all --force
    else
        print_info "IDE/Editor cleanup module not available"
    fi

    # Build artifact cleanup
    if [[ -f "$BUILD_CLEANUP_SCRIPT" ]]; then
        print_section "Build Artifact Cleanup"
        "$BUILD_CLEANUP_SCRIPT" --force
    else
        print_info "Build artifact cleanup module not available"
    fi

    # Dependency manager cleanup
    if [[ -f "$DEPS_CLEANUP_SCRIPT" ]]; then
        print_section "Dependency Manager Cleanup"
        "$DEPS_CLEANUP_SCRIPT" all --force
    else
        print_info "Dependency manager cleanup module not available"
    fi

    print_header "Enhanced Comprehensive Cleanup Complete"
    print_success "All available cleanup operations completed successfully"

    # Show final disk usage summary
    echo ""
    analyze_disk_usage
}

# Analyze disk usage
analyze_disk_usage() {
    print_header "Disk Usage Analysis"

    # Show disk usage for main filesystems
    print_section "Filesystem Usage"
    local -a df_data
    while IFS= read -r line; do
        df_data+=("$line")
    done < <(df -h | tail -n +2 | grep -E '^/dev/' | sort)

    if [[ ${#df_data[@]} -gt 0 ]]; then
        print_table df_data "Filesystem Size Used Avail Use% Mount"
    fi

    # Show large directories in user home
    print_section "Large Directories in Home"
    if [[ -d "$HOME" ]]; then
        local -a dir_sizes=()
        while IFS= read -r size dir; do
            dir_sizes+=("$size $dir")
        done < <(du -sh "$HOME"/* 2>/dev/null | sort -hr | head -10)

        if [[ ${#dir_sizes[@]} -gt 0 ]]; then
            for entry in "${dir_sizes[@]}"; do
                local size="${entry% *}"
                local dir="${entry#* }"
                print_bullet "$size $(basename "$dir")"
            done
        fi
    fi

    # Show disk usage warnings
    print_section "Disk Usage Warnings"
    local warnings_found=false

    while IFS= read -r line; do
        local usage
        usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mount
        mount=$(echo "$line" | awk '{print $6}')

        if [[ $usage -gt 90 ]]; then
            print_warning "$mount is ${usage}% full!"
            warnings_found=true
        elif [[ $usage -gt 80 ]]; then
            print_info "$mount is ${usage}% full"
        fi
    done < <(df -h | tail -n +2 | grep -E '^/dev/')

    if [[ "$warnings_found" == "false" ]]; then
        print_success "No disk usage warnings found"
    fi

    echo ""
    print_info "Run '${YELLOW}fub cleanup all${RESET}' to free up disk space"
}

# Format bytes for human readable output
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

# Show cleanup summary
show_cleanup_summary() {
    local files_removed="$1"
    local space_freed="$2"

    echo ""
    print_section "Cleanup Summary"

    if [[ "$files_removed" -gt 0 ]]; then
        print_success "Files removed: $files_removed"
    fi

    if [[ "$space_freed" -gt 0 ]]; then
        print_success "Space freed: $(format_bytes $space_freed)"
    fi

    if [[ "$CLEANUP_DRY_RUN" == "true" ]]; then
        print_info "This was a dry run. No files were actually removed."
        print_info "Run without --dry-run to perform the cleanup."
    fi
}

# Parse cleanup command line arguments
parse_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                CLEANUP_FORCE=true
                shift
                ;;
            -n|--dry-run)
                CLEANUP_DRY_RUN=true
                shift
                ;;
            -r|--retention)
                CLEANUP_RETENTION_DAYS="$2"
                shift 2
                ;;
            -v|--verbose)
                CLEANUP_VERBOSE=true
                shift
                ;;
            -h|--help)
                show_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Export functions for use in main script
export -f init_cleanup cleanup_command parse_cleanup_args
export -f cleanup_temp_files cleanup_cache_files cleanup_log_files
export -f cleanup_package_cache cleanup_thumbnails cleanup_all analyze_disk_usage
export -f show_cleanup_help format_bytes show_cleanup_summary

# Initialize cleanup module if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_cleanup
    parse_cleanup_args "$@"
    cleanup_command "$@"
fi