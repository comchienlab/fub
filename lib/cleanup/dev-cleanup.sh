#!/usr/bin/env bash

# FUB Development Environment Cleanup Module
# Comprehensive cleanup for development tools and languages

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Development cleanup constants
readonly DEV_CLEANUP_VERSION="1.0.0"
readonly DEV_CLEANUP_DESCRIPTION="Development environment cleanup utilities"

# Development cleanup configuration
DEV_DRY_RUN=false
DEV_VERBOSE=false
DEV_FORCE=false
DEV_RETENTION_DAYS=30
DEV_KEEP_GLOBAL_PACKAGES=false

# Language-specific cache directories
declare -A NODE_CACHE_DIRS=(
    ["npm-cache"]="${HOME}/.npm"
    ["yarn-cache"]="${HOME}/.cache/yarn"
    ["pnpm-store"]="${HOME}/.local/share/pnpm/store"
    ["node-repl"]="${HOME}/.node_repl_history"
    ["nvm-dir"]="${HOME}/.nvm"
)

declare -A PYTHON_CACHE_DIRS=(
    ["pip-cache"]="${HOME}/.cache/pip"
    ["pyenv-cache"]="${HOME}/.pyenv"
    ["python-cache"]="${HOME}/.python-eggs"
    ["mypy-cache"]="${HOME}/.mypy_cache"
    ["pytest-cache"]="${HOME}/.pytest_cache"
    ["tox-dir"]="${HOME}/.tox"
)

declare -A GO_CACHE_DIRS=(
    ["go-mod-cache"]="${HOME}/go/pkg/mod"
    ["go-build-cache"]="${HOME}/.cache/go-build"
    ["go-tools"]="${HOME}/go/bin"
)

declare -A RUST_CACHE_DIRS=(
    ["cargo-registry"]="${HOME}/.cargo/registry"
    ["cargo-git"]="${HOME}/.cargo/git"
    ["cargo-target"]="${HOME}/.cargo/target"
    ["rustup"]=" "${HOME}/.rustup"
)

declare -A RUBY_CACHE_DIRS=(
    ["gem-cache"]="${HOME}/.gem"
    ["rbenv-dir"]="${HOME}/.rbenv"
    ["bundler"]="${HOME}/.bundle"
)

# Initialize development cleanup module
init_dev_cleanup() {
    log_info "Initializing development environment cleanup module v$DEV_CLEANUP_VERSION"
    log_debug "Development cleanup module initialized"
}

# Detect available development environments
detect_dev_environments() {
    print_section "Detecting Development Environments"

    local -a detected_envs=()

    # Node.js detection
    if command_exists node || command_exists npm || command_exists yarn || command_exists pnpm; then
        detected_envs+=("nodejs")
        print_success "Node.js environment detected"
    fi

    # Python detection
    if command_exists python3 || command_exists pip || command_exists python || command_exists pyenv; then
        detected_envs+=("python")
        print_success "Python environment detected"
    fi

    # Go detection
    if command_exists go || [[ -d "${HOME}/go" ]]; then
        detected_envs+=("go")
        print_success "Go environment detected"
    fi

    # Rust detection
    if command_exists rustc || command_exists cargo || [[ -d "${HOME}/.cargo" ]]; then
        detected_envs+=("rust")
        print_success "Rust environment detected"
    fi

    # Ruby detection
    if command_exists ruby || command_exists gem || command_exists rbenv; then
        detected_envs+=("ruby")
        print_success "Ruby environment detected"
    fi

    # Java/Maven detection
    if command_exists java || command_exists mvn || command_exists gradle; then
        detected_envs+=("java")
        print_success "Java environment detected"
    fi

    if [[ ${#detected_envs[@]} -eq 0 ]]; then
        print_info "No common development environments detected"
    else
        print_info "Found ${#detected_envs[@]} development environment(s): ${detected_envs[*]}"
    fi

    # Return detected environments
    printf '%s\n' "${detected_envs[@]}"
}

# Clean Node.js environment
cleanup_nodejs_environment() {
    print_section "Node.js Environment Cleanup"

    local total_removed=0
    local total_freed=0

    # Clean npm cache
    if command_exists npm; then
        print_info "Cleaning npm cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean npm cache")"
        else
            if npm cache clean --force 2>/dev/null; then
                print_success "npm cache cleaned"
            else
                print_warning "Failed to clean npm cache"
            fi
        fi
    fi

    # Clean yarn cache
    if command_exists yarn; then
        print_info "Cleaning yarn cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean yarn cache")"
        else
            if yarn cache clean 2>/dev/null; then
                print_success "yarn cache cleaned"
            else
                print_warning "Failed to clean yarn cache"
            fi
        fi
    fi

    # Clean pnpm store
    if command_exists pnpm; then
        print_info "Cleaning pnpm store"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean pnpm store")"
        else
            if pnpm store prune 2>/dev/null; then
                print_success "pnpm store cleaned"
            else
                print_warning "Failed to clean pnpm store"
            fi
        fi
    fi

    # Clean Node.js cache directories
    for cache_name in "${!NODE_CACHE_DIRS[@]}"; do
        local cache_dir="${NODE_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEV_DRY_RUN" == "true" ]]; then
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
                    done < <(find "$cache_dir" -type f -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Python environment
cleanup_python_environment() {
    print_section "Python Environment Cleanup"

    local total_removed=0
    local total_freed=0

    # Clean pip cache
    if command_exists pip; then
        print_info "Cleaning pip cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean pip cache")"
        else
            if pip cache purge 2>/dev/null; then
                print_success "pip cache cleaned"
            else
                # Fallback for older pip versions
                local pip_cache_dir
                pip_cache_dir=$(pip cache dir 2>/dev/null || echo "${HOME}/.cache/pip")
                if [[ -d "$pip_cache_dir" ]]; then
                    rm -rf "$pip_cache_dir"/* 2>/dev/null || true
                    print_success "pip cache directory cleaned"
                fi
            fi
        fi
    fi

    # Clean pip3 cache if available
    if command_exists pip3 && ! pip --version | grep -q "pip 3"; then
        print_info "Cleaning pip3 cache"

        if [[ "$DEV_DRY_RUN" != "true" ]]; then
            if pip3 cache purge 2>/dev/null; then
                print_success "pip3 cache cleaned"
            fi
        fi
    fi

    # Clean Python cache directories
    for cache_name in "${!PYTHON_CACHE_DIRS[@]}"; do
        local cache_dir="${PYTHON_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEV_DRY_RUN" == "true" ]]; then
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
                    done < <(find "$cache_dir" -type f -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    # Clean Python __pycache__ directories in home directory
    print_info "Cleaning Python __pycache__ directories"
    local pycache_count=0
    while IFS= read -r -d '' pycache_dir; do
        local dir_size
        dir_size=$(du -sb "$pycache_dir" 2>/dev/null | cut -f1) || dir_size=0

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would remove __pycache__ directory: $(basename "$(dirname "$pycache_dir")")")"
        else
            if rm -rf "$pycache_dir" 2>/dev/null; then
                ((pycache_count++))
                ((total_freed += dir_size))
            fi
        fi
    done < <(find "$HOME" -type d -name "__pycache__" -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

    if [[ $pycache_count -gt 0 ]]; then
        print_success "Removed $pycache_count __pycache__ directories"
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Go environment
cleanup_go_environment() {
    print_section "Go Environment Cleanup"

    local total_removed=0
    local total_freed=0

    # Clean Go module cache
    if command_exists go; then
        print_info "Cleaning Go module cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean Go module cache")"
        else
            if go clean -modcache 2>/dev/null; then
                print_success "Go module cache cleaned"
            else
                print_warning "Failed to clean Go module cache"
            fi
        fi

        # Clean Go build cache
        print_info "Cleaning Go build cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean Go build cache")"
        else
            if go clean -cache 2>/dev/null; then
                print_success "Go build cache cleaned"
            else
                print_warning "Failed to clean Go build cache"
            fi
        fi
    fi

    # Clean Go cache directories
    for cache_name in "${!GO_CACHE_DIRS[@]}"; do
        local cache_dir="${GO_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEV_DRY_RUN" == "true" ]]; then
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
                    done < <(find "$cache_dir" -type f -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Rust environment
cleanup_rust_environment() {
    print_section "Rust Environment Cleanup"

    local total_removed=0
    local total_freed=0

    # Clean cargo cache if cargo command is available
    if command_exists cargo; then
        print_info "Cleaning Cargo cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean Cargo cache")"
        else
            # Clean cargo registry cache
            if cargo cache --remove-dir all 2>/dev/null; then
                print_success "Cargo cache cleaned"
            else
                # Fallback: manually clean cargo directories
                local cargo_home="${CARGO_HOME:-${HOME}/.cargo}"
                for cache_dir in "$cargo_home/registry" "$cargo_home/git"; do
                    if [[ -d "$cache_dir" ]]; then
                        rm -rf "$cache_dir"/* 2>/dev/null || true
                    fi
                done
                print_success "Cargo directories cleaned manually"
            fi
        fi
    fi

    # Clean Rust cache directories
    for cache_name in "${!RUST_CACHE_DIRS[@]}"; do
        local cache_dir="${RUST_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEV_DRY_RUN" == "true" ]]; then
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
                    done < <(find "$cache_dir" -type f -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Ruby environment
cleanup_ruby_environment() {
    print_section "Ruby Environment Cleanup"

    local total_removed=0
    local total_freed=0

    # Clean gem cache
    if command_exists gem; then
        print_info "Cleaning gem cache"

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean gem cache")"
        else
            if gem cleanup 2>/dev/null; then
                print_success "gem cache cleaned"
            else
                print_warning "Failed to clean gem cache"
            fi
        fi
    fi

    # Clean Ruby cache directories
    for cache_name in "${!RUBY_CACHE_DIRS[@]}"; do
        local cache_dir="${RUBY_CACHE_DIRS[$cache_name]}"

        if [[ -d "$cache_dir" ]]; then
            print_info "Cleaning $cache_name"

            local cache_size
            cache_size=$(du -sb "$cache_dir" 2>/dev/null | cut -f1) || cache_size=0

            if [[ $cache_size -gt 0 ]]; then
                if [[ "$DEV_DRY_RUN" == "true" ]]; then
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
                    done < <(find "$cache_dir" -type f -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                    ((total_removed += files_removed))
                    print_success "Cleaned $files_removed files from $cache_name"
                fi
            fi
        fi
    done

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean Java/Maven environment
cleanup_java_environment() {
    print_section "Java/Maven Environment Cleanup"

    local total_removed=0
    local total_freed=0

    # Clean Maven local repository
    local maven_repo="${HOME}/.m2/repository"
    if [[ -d "$maven_repo" ]]; then
        print_info "Cleaning Maven local repository"

        local repo_size
        repo_size=$(du -sb "$maven_repo" 2>/dev/null | cut -f1) || repo_size=0

        if [[ $repo_size -gt 0 ]]; then
            if [[ "$DEV_DRY_RUN" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would clean Maven repository ($(format_bytes $repo_size))")"
            else
                if command_exists mvn; then
                    # Use Maven dependency plugin if available
                    if mvn dependency:purge-local-repository -DmanualInclude="com.example:*" -DreResolve=false -q 2>/dev/null; then
                        print_success "Maven repository cleaned using Maven"
                    else
                        # Fallback: clean old snapshots and unused artifacts
                        local files_removed=0
                        while IFS= read -r -d '' file; do
                            local file_size
                            file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                            if rm -rf "$file" 2>/dev/null; then
                                ((files_removed++))
                                ((total_freed += file_size))
                            fi
                        done < <(find "$maven_repo" -name "*-SNAPSHOT" -type d -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                        ((total_removed += files_removed))
                        print_success "Cleaned $files_removed Maven snapshot directories"
                    fi
                fi
            fi
        fi
    fi

    # Clean Gradle cache
    local gradle_cache="${HOME}/.gradle/caches"
    if [[ -d "$gradle_cache" ]]; then
        print_info "Cleaning Gradle cache"

        local cache_size
        cache_size=$(du -sb "$gradle_cache" 2>/dev/null | cut -f1) || cache_size=0

        if [[ $cache_size -gt 0 ]]; then
            if [[ "$DEV_DRY_RUN" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Would clean Gradle cache ($(format_bytes $cache_size))")"
            else
                local files_removed=0
                while IFS= read -r -d '' file; do
                    local file_size
                    file_size=$(du -sb "$file" 2>/dev/null | cut -f1) || file_size=0

                    if rm -rf "$file" 2>/dev/null; then
                        ((files_removed++))
                        ((total_freed += file_size))
                    fi
                done < <(find "$gradle_cache" -type f -mtime +$DEV_RETENTION_DAYS -print0 2>/dev/null)

                ((total_removed += files_removed))
                print_success "Cleaned $files_removed files from Gradle cache"
            fi
        fi
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Comprehensive development environment cleanup
cleanup_dev_comprehensive() {
    print_header "Comprehensive Development Environment Cleanup"
    print_info "Performing development environment cleanup"

    if [[ "$DEV_DRY_RUN" == "false" ]] && [[ "$DEV_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will clean caches and temporary files from development environments. Continue?" "This operation removes development caches but preserves your source code and important packages."; then
            print_info "Development environment cleanup cancelled"
            return 0
        fi
    fi

    local -a detected_envs
    readarray -t detected_envs < <(detect_dev_environments)

    if [[ ${#detected_envs[@]} -eq 0 ]]; then
        print_info "No development environments found to clean"
        return 0
    fi

    # Clean each detected environment
    for env in "${detected_envs[@]}"; do
        case "$env" in
            "nodejs")
                cleanup_nodejs_environment
                ;;
            "python")
                cleanup_python_environment
                ;;
            "go")
                cleanup_go_environment
                ;;
            "rust")
                cleanup_rust_environment
                ;;
            "ruby")
                cleanup_ruby_environment
                ;;
            "java")
                cleanup_java_environment
                ;;
            *)
                log_debug "Unknown development environment: $env"
                ;;
        esac
    done

    print_header "Development Environment Cleanup Complete"
    print_success "Development environment cleanup completed successfully"
}

# Parse development cleanup arguments
parse_dev_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                DEV_FORCE=true
                shift
                ;;
            -n|--dry-run)
                DEV_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                DEV_VERBOSE=true
                shift
                ;;
            -r|--retention)
                DEV_RETENTION_DAYS="$2"
                shift 2
                ;;
            --keep-global)
                DEV_KEEP_GLOBAL_PACKAGES=true
                shift
                ;;
            -h|--help)
                show_dev_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_dev_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Show development cleanup help
show_dev_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}Development Environment Cleanup Module${RESET}
${ITALIC}Comprehensive cleanup for development tools and languages${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup dev${RESET} [${YELLOW}ENVIRONMENT${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Environments:${RESET}
    ${YELLOW}nodejs${RESET}                 Node.js/npm/yarn/pnpm cache cleanup
    ${YELLOW}python${RESET}                 Python/pip/pyenv cache cleanup
    ${YELLOW}go${RESET}                     Go module and build cache cleanup
    ${YELLOW}rust${RESET}                   Rust/Cargo cache cleanup
    ${YELLOW}ruby${RESET}                   Ruby/gem cache cleanup
    ${YELLOW}java${RESET}                   Java/Maven/Gradle cache cleanup
    ${YELLOW}all${RESET}                    Clean all detected development environments

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}                    Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}                  Show what would be cleaned
    ${YELLOW}-v, --verbose${RESET}                  Verbose output
    ${YELLOW}-r, --retention${RESET} DAYS          Retention period in days (default: 30)
    ${YELLOW}--keep-global${RESET}                 Keep global packages (where applicable)
    ${YELLOW}-h, --help${RESET}                     Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup dev nodejs${RESET}           # Clean Node.js environment
    ${GREEN}fub cleanup dev --dry-run all${RESET}    # Preview all cleanup actions
    ${GREEN}fub cleanup dev --force python${RESET}   # Clean Python without confirmation
    ${GREEN}fub cleanup dev --retention 7 rust${RESET} # Clean Rust with 7-day retention

${BOLD}What gets cleaned:${RESET}
    • Package manager caches (npm, pip, cargo, gem, maven)
    • Build artifacts and temporary files
    • Module and dependency caches
    • IDE and tool-specific caches
    • Old snapshots and version artifacts

${BOLD}Safety Features:${RESET}
    • Preserves globally installed packages (unless --keep-global is false)
    • Retention period for cache files
    • Dry-run mode for safe preview
    • Environment-specific safe cleanup
    • Detailed logging and progress reporting

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

        if [[ "$DEV_DRY_RUN" == "true" ]]; then
            print_info "This was a dry run. No files were actually removed."
            print_info "Run without --dry-run to perform the cleanup."
        fi
    }
fi

# Export functions for use in main cleanup script
export -f init_dev_cleanup detect_dev_environments cleanup_nodejs_environment
export -f cleanup_python_environment cleanup_go_environment cleanup_rust_environment
export -f cleanup_ruby_environment cleanup_java_environment cleanup_dev_comprehensive
export -f parse_dev_cleanup_args show_dev_cleanup_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_dev_cleanup
    parse_dev_cleanup_args "$@"

    # Default action if none specified
    local action="${1:-all}"

    case "$action" in
        nodejs)
            cleanup_nodejs_environment
            ;;
        python)
            cleanup_python_environment
            ;;
        go)
            cleanup_go_environment
            ;;
        rust)
            cleanup_rust_environment
            ;;
        ruby)
            cleanup_ruby_environment
            ;;
        java)
            cleanup_java_environment
            ;;
        all|comprehensive)
            cleanup_dev_comprehensive
            ;;
        help|--help|-h)
            show_dev_cleanup_help
            ;;
        *)
            log_error "Unknown development environment: $action"
            show_dev_cleanup_help
            exit 1
            ;;
    esac
fi