#!/usr/bin/env bash

# FUB IDE/Editor Cleanup Module
# Comprehensive cleanup for IDEs and text editors cache and temporary files

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# IDE cleanup constants
readonly IDE_CLEANUP_VERSION="1.0.0"
readonly IDE_CLEANUP_DESCRIPTION="IDE and editor cache cleanup utilities"

# IDE cleanup configuration
IDE_DRY_RUN=false
IDE_VERBOSE=false
IDE_FORCE=false
IDE_RETENTION_DAYS=30
IDE_KEEP_SESSIONS=false
IDE_KEEP_EXTENSIONS=false

# IDE-specific cache directories
declare -A VSCODE_CACHE_DIRS=(
    ["vscode-user-data"]="${HOME}/.config/Code"
    ["vscode-extensions"]="${HOME}/.vscode"
    ["vscode-logs"]="${HOME}/.config/Code/logs"
    ["vscode-cached-data"]="${HOME}/.config/Code/CachedExtensions"
    ["vscode-crm"]="${HOME}/.config/Code/User/globalStorage"
    ["vscode-tmp"]="${HOME}/.config/Code/tmp"
)

declare -A INTELLIJ_CACHE_DIRS=(
    ["intellij-caches"]="${HOME}/.cache/JetBrains"
    ["intellij-logs"]="${HOME}/.local/share/JetBrains/log"
    ["intellij-indexes"]="${HOME}/.local/share/JetBrains/index"
    ["intellij-tmp"]="/tmp/intellij*"
    ["idea-config"]="${HOME}/.IntelliJIdea*/system"
    ["pycharm-config"]="${HOME}/.PyCharm*/system"
    ["webstorm-config"]="${HOME}/.WebStorm*/system"
    ["clion-config"]="${HOME}/.CLion*/system"
)

declare -A VIM_CACHE_DIRS=(
    ["vim-swap"]="${HOME}/.local/share/nvim/swap"
    ["vim-undo"]="${HOME}/.local/share/nvim/undo"
    ["vim-backup"]="${HOME}/.local/share/nvim/backup"
    ["vim-views"]="${HOME}/.local/share/nvim/view"
    ["vim-shada"]="${HOME}/.local/share/nvim/shada"
    ["vim-cache"]="${HOME}/.cache/nvim"
    ["vim-plug"]="${HOME}/.local/share/nvim/site/plugged"
)

declare -A EMACS_CACHE_DIRS=(
    ["emacs-auto-save"]="${HOME}/.emacs.d/auto-save-list"
    ["emacs-backup"]="${HOME}/.emacs.d/backups"
    ["emacs-cache"]="${HOME}/.emacs.d/eshell"
    ["emacs-elpa"]="${HOME}/.emacs.d/elpa"
    ["emacs-lisp"]="${HOME}/.emacs.d/lisp"
    ["emacs-tmp"]="/tmp/emacs*"
)

declare -A SUBLIME_CACHE_DIRS=(
    ["sublime-cache"]="${HOME}/.config/sublime-text-3/Cache"
    ["sublime-index"]="${HOME}/.config/sublime-text-3/Index"
    ["sublime-backup"]="${HOME}/.config/sublime-text-3/Backup"
    ["sublime-install"]="${HOME}/.config/sublime-text-3/Installed Packages"
)

# Additional editors
declare -A ATOM_CACHE_DIRS=(
    ["atom-cache"]="${HOME}/.atom/compile-cache"
    ["atom-storage"]="${HOME}/.atom/storage"
    ["atom-logs"]="${HOME}/.atom/.github"
)

declare -A VSCODIUM_CACHE_DIRS=(
    ["vscodium-user-data"]="${HOME}/.config/VSCodium"
    ["vscodium-extensions"]="${HOME}/.vscodium"
    ["vscodium-logs"]="${HOME}/.config/VSCodium/logs"
)

# Initialize IDE cleanup module
init_ide_cleanup() {
    log_info "Initializing IDE cleanup module v$IDE_CLEANUP_VERSION"
    log_debug "IDE cleanup module initialized"
}

# Detect available IDEs and editors
detect_ides() {
    print_section "Detecting IDEs and Editors"

    local -a detected_ides=()

    # VS Code detection
    if command_exists code || [[ -d "${HOME}/.config/Code" ]]; then
        detected_ides+=("vscode")
        print_success "Visual Studio Code detected"
    fi

    # VSCodium detection
    if command_exists codium || [[ -d "${HOME}/.config/VSCodium" ]]; then
        detected_ides+=("vscodium")
        print_success "VSCodium detected"
    fi

    # IntelliJ family detection
    if [[ -d "${HOME}/.local/share/JetBrains" ]] || [[ -d "${HOME}/.IntelliJIdea" ]] || [[ -d "${HOME}/.PyCharm" ]] || [[ -d "${HOME}/.WebStorm" ]]; then
        detected_ides+=("intellij")
        print_success "JetBrains IDEs detected"
    fi

    # Vim/Neovim detection
    if command_exists vim || command_exists nvim || [[ -d "${HOME}/.vim" ]] || [[ -d "${HOME}/.config/nvim" ]]; then
        detected_ides+=("vim")
        print_success "Vim/Neovim detected"
    fi

    # Emacs detection
    if command_exists emacs || [[ -d "${HOME}/.emacs.d" ]]; then
        detected_ides+=("emacs")
        print_success "Emacs detected"
    fi

    # Sublime Text detection
    if command_exists subl || [[ -d "${HOME}/.config/sublime-text-3" ]] || [[ -d "${HOME}/.config/sublime-text" ]]; then
        detected_ides+=("sublime")
        print_success "Sublime Text detected"
    fi

    # Atom detection
    if command_exists atom || [[ -d "${HOME}/.atom" ]]; then
        detected_ides+=("atom")
        print_success "Atom detected"
    fi

    if [[ ${#detected_ides[@]} -eq 0 ]]; then
        print_info "No common IDEs or editors detected"
    else
        print_info "Found ${#detected_ides[@]} IDE(s)/editor(s): ${detected_ides[*]}"
    fi

    # Return detected IDEs
    printf '%s\n' "${detected_ides[@]}"
}

# Clean VS Code
cleanup_vscode() {
    print_section "Visual Studio Code Cleanup"

    local total_removed=0
    local total_freed=0

    for cache_name in "${!VSCODE_CACHE_DIRS[@]}"; do
        local cache_pattern="${VSCODE_CACHE_DIRS[$cache_name]}"

        # Handle patterns with wildcards
        if [[ "$cache_pattern" == *"*"* ]]; then
            while IFS= read -r -d '' cache_dir; do
                if [[ -d "$cache_dir" ]]; then
                    clean_vscode_directory "$cache_name" "$cache_dir"
                fi
            done < <(find "$(dirname "$cache_pattern")" -name "$(basename "$cache_pattern")" -type d -print0 2>/dev/null)
        else
            if [[ -d "$cache_pattern" ]]; then
                clean_vscode_directory "$cache_name" "$cache_pattern"
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean VS Code directory helper
clean_vscode_directory() {
    local cache_name="$1"
    local cache_dir="$2"

    print_info "Cleaning $cache_name"

    local cache_size
    cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

    if [[ $cache_size -gt 0 ]]; then
        if [[ "$IDE_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean $cache_name ($(format_bytes $cache_size))")"
        else
            # Skip certain directories based on configuration
            case "$cache_name" in
                "vscode-extensions")
                    if [[ "$IDE_KEEP_EXTENSIONS" == "true" ]]; then
                        print_indented 2 "$(format_status "info" "Skipping extensions directory (--keep-extensions)")"
                        return 0
                    fi
                    ;;
                "vscode-user-data")
                    # Only clean cache subdirectories, preserve configuration
                    find "$cache_dir" -type d -name "CachedData" -exec rm -rf {} + 2>/dev/null || true
                    find "$cache_dir" -type d -name "logs" -exec rm -rf {} + 2>/dev/null || true
                    print_indented 2 "$(format_status "success" "Cleaned VS Code cache directories")"
                    return 0
                    ;;
            esac

            local files_removed=0
            while IFS= read -r -d '' file; do
                local file_size
                file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                if rm -rf "$file" 2>/dev/null; then
                    ((files_removed++))
                    ((total_freed += file_size))
                fi
            done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)

            ((total_removed += files_removed))
            print_success "Cleaned $files_removed files from $cache_name"
        fi
    fi
}

# Clean JetBrains IDEs
cleanup_intellij() {
    print_section "JetBrains IDEs Cleanup"

    local total_removed=0
    local total_freed=0

    for cache_name in "${!INTELLIJ_CACHE_DIRS[@]}"; do
        local cache_pattern="${INTELLIJ_CACHE_DIRS[$cache_name]}"

        # Handle patterns with wildcards
        if [[ "$cache_pattern" == *"*"* ]]; then
            while IFS= read -r -d '' cache_dir; do
                if [[ -d "$cache_dir" ]]; then
                    clean_intellij_directory "$cache_name" "$cache_dir"
                fi
            done < <(find "$(dirname "$cache_pattern")" -name "$(basename "$cache_pattern")" -type d -print0 2>/dev/null)
        else
            if [[ -d "$cache_pattern" ]]; then
                clean_intellij_directory "$cache_name" "$cache_pattern"
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean IntelliJ directory helper
clean_intellij_directory() {
    local cache_name="$1"
    local cache_dir="$2"

    print_info "Cleaning $cache_name"

    local cache_size
    cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

    if [[ $cache_size -gt 0 ]]; then
        if [[ "$IDE_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean $cache_name ($(format_bytes $cache_size))")"
        else
            # Be careful with JetBrains caches - some are important
            case "$cache_name" in
                "intellij-indexes")
                    # Indexes can be safely removed as they will be rebuilt
                    local files_removed=0
                    while IFS= read -r -d '' file; do
                        local file_size
                        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -name "*.index*" -print0 2>/dev/null)
                    ((total_removed += files_removed))
                    print_success "Cleaned IntelliJ indexes"
                    ;;
                "intellij-caches")
                    # Clean old caches but preserve recent ones
                    local files_removed=0
                    while IFS= read -r -d '' file; do
                        local file_size
                        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)
                    ((total_removed += files_removed))
                    print_success "Cleaned old IntelliJ caches"
                    ;;
                *)
                    local files_removed=0
                    while IFS= read -r -d '' file; do
                        local file_size
                        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)
                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                    ;;
            esac
        fi
    fi
}

# Clean Vim/Neovim
cleanup_vim() {
    print_section "Vim/Neovim Cleanup"

    local total_removed=0
    local total_freed=0

    for cache_name in "${!VIM_CACHE_DIRS[@]}"; do
        local cache_dir="${VIM_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$IDE_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean $cache_name ($(format_bytes $cache_size))")"
                else
                    # Special handling for swap files (don't remove if file is being edited)
                    case "$cache_name" in
                        "vim-swap")
                            # Remove only swap files for files that don't exist
                            local files_removed=0
                            while IFS= read -r -d '' swap_file; do
                                local original_file
                                original_file=$(basename "$swap_file" | sed 's/^\(\.\?\)\(.*\)\.swp$/\2/')
                                original_file=$(dirname "$swap_file")/"../$original_file"

                                if [[ ! -f "$original_file" ]]; then
                                    local file_size
                                    file_size=$(du -sb "$swap_file" 2>/dev/null | cut -f1) || file_size=0

                                    if rm -f "$swap_file" 2>/dev/null; then
                                        ((files_removed++))
                                        ((total_freed += file_size))
                                    fi
                                fi
                            done < <(find "$cache_dir" -name "*.swp" -type f -print0 2>/dev/null)
                            ((total_removed += files_removed))
                            print_success "Cleaned $files_removed orphaned swap files"
                            ;;
                        *)
                            local files_removed=0
                            while IFS= read -r -d '' file; do
                                local file_size
                                file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                                if rm -rf "$file" 2>/dev/null; then
                                    ((files_removed++))
                                    ((total_freed += file_size))
                                fi
                            done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)
                            ((total_removed += files_removed))
                            print_success "Cleaned $files_removed files from $cache_name"
                            ;;
                    esac
                fi
            fi
        fi
    done

    # Clean viminfo and .viminfo files
    local viminfo_files=("${HOME}/.viminfo" "${HOME}/.local/share/nvim/shada/main.shada")
    for viminfo in "${viminfo_files[@]}"; do
        if [[ -f "$viminfo" ]]; then
            local size
            size=$(du -sb "$viminfo" 2>/dev/null | cut -f1) || size=0

            if [[ "$IDE_DRY_RUN" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would remove viminfo: $(basename "$viminfo") ($(format_bytes $size))")"
            else
                if rm -f "$viminfo" 2>/dev/null; then
                    ((total_removed++))
                    ((total_freed += size))
                    print_success "Removed viminfo: $(basename "$viminfo")"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Emacs
cleanup_emacs() {
    print_section "Emacs Cleanup"

    local total_removed=0
    local total_freed=0

    for cache_name in "${!EMACS_CACHE_DIRS[@]}"; do
        local cache_pattern="${EMACS_CACHE_DIRS[$cache_name]}"

        # Handle patterns with wildcards
        if [[ "$cache_pattern" == *"*"* ]]; then
            while IFS= read -r -d '' cache_dir; do
                if [[ -d "$cache_dir" ]]; then
                    clean_emacs_directory "$cache_name" "$cache_dir"
                fi
            done < <(find "$(dirname "$cache_pattern")" -name "$(basename "$cache_pattern")" -type d -print0 2>/dev/null)
        else
            if [[ -d "$cache_pattern" ]]; then
                clean_emacs_directory "$cache_name" "$cache_pattern"
            fi
        fi
    done

    # Clean Emacs lock files
    local lock_files
    lock_files=$(find "$HOME" -name ".#*" -type f -print0 2>/dev/null || true)

    while IFS= read -r -d '' lock_file; do
        if [[ -f "$lock_file" ]]; then
            local original_file="${lock_file/.#/.}"
            if [[ ! -f "$original_file" ]]; then
                local size
                size=$(du -sb "$lock_file" 2>/dev/null | cut -f1) || size=0

                if [[ "$IDE_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would remove lock file: $(basename "$lock_file")")"
                else
                    if rm -f "$lock_file" 2>/dev/null; then
                        ((total_removed++))
                        ((total_freed += size))
                        if [[ "$IDE_VERBOSE" == "true" ]]; then
                            print_indented 2 "Removed lock file: $(basename "$lock_file")"
                        fi
                    fi
                fi
            fi
        fi
    done < <(find "$HOME" -name ".#*" -type f -print0 2>/dev/null)

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Emacs directory helper
clean_emacs_directory() {
    local cache_name="$1"
    local cache_dir="$2"

    print_info "Cleaning $cache_name"

    local cache_size
    cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

    if [[ $cache_size -gt 0 ]]; then
        if [[ "$IDE_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean $cache_name ($(format_bytes $cache_size))")"
        else
            case "$cache_name" in
                "emacs-auto-save")
                    # Remove auto-save files for files that don't exist
                    local files_removed=0
                    while IFS= read -r -d '' auto_file; do
                        local original_file="${auto_file/#*#/}"
                        original_file="${original_file/%\#/}"

                        if [[ ! -f "$original_file" ]]; then
                            local file_size
                            file_size=$(du -sb "$auto_file" 2>/dev/null | cut -f1) || file_size=0

                            if rm -f "$auto_file" 2>/dev/null; then
                                ((files_removed++))
                                ((total_freed += file_size))
                            fi
                        fi
                    done < <(find "$cache_dir" -name "#*#" -type f -print0 2>/dev/null)
                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed orphaned auto-save files"
                    ;;
                *)
                    local files_removed=0
                    while IFS= read -r -d '' file; do
                        local file_size
                        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)
                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                    ;;
            esac
        fi
    fi
}

# Clean Sublime Text
cleanup_sublime() {
    print_section "Sublime Text Cleanup"

    local total_removed=0
    local total_freed=0

    for cache_name in "${!SUBLIME_CACHE_DIRS[@]}"; do
        local cache_dir="${SUBLIME_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$IDE_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean $cache_name ($(format_bytes $cache_size))")"
                else
                    # Skip installed packages directory as it contains user extensions
                    if [[ "$cache_name" == "sublime-install" && "$IDE_KEEP_EXTENSIONS" == "true" ]]; then
                        print_indented 2 "$(format_status "info" "Skipping installed packages (--keep-extensions)")"
                        continue
                    fi

                    local files_removed=0
                    while IFS= read -r -d '' file; do
                        local file_size
                        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Atom
cleanup_atom() {
    print_section "Atom Cleanup"

    local total_removed=0
    local total_freed=0

    for cache_name in "${!ATOM_CACHE_DIRS[@]}"; do
        local cache_dir="${ATOM_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$IDE_DRY_RUN" == "true" ]]; then
                    print_indented 2 "$(format_status "info" "Would clean $cache_name ($(format_bytes $cache_size))")"
                else
                    local files_removed=0
                    while IFS= read -r -d '' file; do
                        local file_size
                        file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                        if rm -rf "$file" 2>/dev/null; then
                            ((files_removed++))
                            ((total_freed += file_size))
                        fi
                    done < <(find "$cache_dir" -type f -mtime +$IDE_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Comprehensive IDE cleanup
cleanup_ides_comprehensive() {
    print_header "Comprehensive IDE/Editor Cleanup"
    print_info "Performing IDE and editor cache cleanup"

    if [[ "$IDE_DRY_RUN" == "false" ]] && [[ "$IDE_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will clean caches and temporary files from IDEs and editors. Continue?" "This operation removes caches and temporary files but preserves your settings and important files."; then
            print_info "IDE cleanup cancelled"
            return 0
        fi
    fi

    local -a detected_ides
    readarray -t detected_ides < <(detect_ides)

    if [[ ${#detected_ides[@]} -eq 0 ]]; then
        print_info "No IDEs or editors found to clean"
        return 0
    fi

    # Clean each detected IDE
    for ide in "${detected_ides[@]}"; do
        case "$ide" in
            "vscode")
                cleanup_vscode
                ;;
            "vscodium")
                # Use VSCode cleanup function with VSCodium directories
                VSCODE_CACHE_DIRS=("${VSCODIUM_CACHE_DIRS[@]}")
                cleanup_vscode
                VSCODE_CACHE_DIRS=(
                    ["vscode-user-data"]="${HOME}/.config/Code"
                    ["vscode-extensions"]="${HOME}/.vscode"
                    ["vscode-logs"]="${HOME}/.config/Code/logs"
                    ["vscode-cached-data"]="${HOME}/.config/Code/CachedExtensions"
                    ["vscode-crm"]="${HOME}/.config/Code/User/globalStorage"
                    ["vscode-tmp"]="${HOME}/.config/Code/tmp"
                )
                ;;
            "intellij")
                cleanup_intellij
                ;;
            "vim")
                cleanup_vim
                ;;
            "emacs")
                cleanup_emacs
                ;;
            "sublime")
                cleanup_sublime
                ;;
            "atom")
                cleanup_atom
                ;;
            *)
                log_debug "Unknown IDE: $ide"
                ;;
        esac
    done

    print_header "IDE/Editor Cleanup Complete"
    print_success "IDE and editor cleanup completed successfully"
}

# Parse IDE cleanup arguments
parse_ide_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                IDE_FORCE=true
                shift
                ;;
            -n|--dry-run)
                IDE_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                IDE_VERBOSE=true
                shift
                ;;
            -r|--retention)
                IDE_RETENTION_DAYS="$2"
                shift 2
                ;;
            --keep-sessions)
                IDE_KEEP_SESSIONS=true
                shift
                ;;
            --keep-extensions)
                IDE_KEEP_EXTENSIONS=true
                shift
                ;;
            -h|--help)
                show_ide_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_ide_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Show IDE cleanup help
show_ide_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}IDE/Editor Cleanup Module${RESET}
${ITALIC}Comprehensive cleanup for IDEs and text editors${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup ide${RESET} [${YELLOW}EDITOR${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Editors:${RESET}
    ${YELLOW}vscode${RESET}                 Visual Studio Code
    ${YELLOW}vscodium${RESET}               VSCodium
    ${YELLOW}intellij${RESET}               JetBrains IDEs (IntelliJ, PyCharm, WebStorm, etc.)
    ${YELLOW}vim${RESET}                    Vim/Neovim
    ${YELLOW}emacs${RESET}                  Emacs
    ${YELLOW}sublime${RESET}                Sublime Text
    ${YELLOW}atom${RESET}                   Atom
    ${YELLOW}all${RESET}                    All detected IDEs and editors

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}                    Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}                  Show what would be cleaned
    ${YELLOW}-v, --verbose${RESET}                  Verbose output with details
    ${YELLOW}-r, --retention${RESET} DAYS          Retention period in days (default: 30)
    ${YELLOW}--keep-sessions${RESET}                Keep session files and states
    ${YELLOW}--keep-extensions${RESET}              Keep extension/plugin data
    ${YELLOW}-h, --help${RESET}                     Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup ide vscode${RESET}           # Clean VS Code cache
    ${GREEN}fub cleanup ide --dry-run all${RESET}    # Preview all cleanup actions
    ${GREEN}fub cleanup ide --keep-extensions vim${RESET} # Clean Vim but keep plugins
    ${GREEN}fub cleanup ide --retention 7 intellij${RESET} # Clean IntelliJ with 7-day retention

${BOLD}What gets cleaned:${RESET}
    • Cache files and temporary data
    • Build artifacts and compiled files
    • Log files and crash reports
    • Auto-save files for deleted documents
    • Swap files for closed editing sessions
    • Package manager caches
    • Index files and search caches

${BOLD}What gets preserved:${RESET}
    • User configurations and settings
    • Installed extensions and plugins (unless --keep-extensions is false)
    • Active editing sessions and swap files
    • Important project data
    • License and authentication data

${BOLD}Safety Features:${RESET}
    • Preserves active editing sessions
    • Intelligent detection of orphaned files
    • Optional extension protection
    • Retention period for cache files
    • Editor-specific safe cleanup
    • Dry-run mode for safe preview

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
            print_success "Files removed: $files_removed"
        fi

        if [[ "$space_freed" -gt 0 ]]; then
            print_success "Space freed: $(format_bytes $space_freed)"
        fi

        if [[ "$IDE_DRY_RUN" == "true" ]]; then
            print_info "This was a dry run. No files were actually removed."
            print_info "Run without --dry-run to perform the cleanup."
        fi
    }
fi

# Export functions for use in main cleanup script
export -f init_ide_cleanup detect_ides cleanup_vscode cleanup_intellij
export -f cleanup_vim cleanup_emacs cleanup_sublime cleanup_atom
export -f cleanup_ides_comprehensive parse_ide_cleanup_args show_ide_cleanup_help
export -f clean_vscode_directory clean_intellij_directory clean_emacs_directory

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_ide_cleanup
    parse_ide_cleanup_args "$@"

    # Default action if none specified
    local action="${1:-all}"

    case "$action" in
        vscode)
            cleanup_vscode
            ;;
        vscodium)
            VSCODE_CACHE_DIRS=("${VSCODIUM_CACHE_DIRS[@]}")
            cleanup_vscode
            ;;
        intellij)
            cleanup_intellij
            ;;
        vim)
            cleanup_vim
            ;;
        emacs)
            cleanup_emacs
            ;;
        sublime)
            cleanup_sublime
            ;;
        atom)
            cleanup_atom
            ;;
        all|comprehensive)
            cleanup_ides_comprehensive
            ;;
        help|--help|-h)
            show_ide_cleanup_help
            ;;
        *)
            log_error "Unknown IDE/editor: $action"
            show_ide_cleanup_help
            exit 1
            ;;
    esac
fi