#!/usr/bin/env bash

# FUB Build Artifact Cleanup Module
# Git-aware cleanup of build artifacts and dependency directories

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Build cleanup constants
readonly BUILD_CLEANUP_VERSION="1.0.0"
readonly BUILD_CLEANUP_DESCRIPTION="Git-aware build artifact cleanup utilities"

# Build cleanup configuration
BUILD_DRY_RUN=false
BUILD_VERBOSE=false
BUILD_FORCE=false
BUILD_RETENTION_DAYS=7
BUILD_KEEP_STASHES=true
BUILD_KEEP_LOCKED=false
BUILD_AGGRESSIVE=false

# Build artifact patterns
declare -a BUILD_PATTERNS=(
    "node_modules"
    "target"
    "build"
    "dist"
    "out"
    ".next"
    ".nuxt"
    ".vscode"
    ".idea"
    "*.egg-info"
    "__pycache__"
    ".pytest_cache"
    ".mypy_cache"
    ".tox"
    "venv"
    "env"
    ".venv"
    "vendor"
    "bower_components"
    ".gradle"
    "build.gradle"
    "*.log"
    "*.tmp"
    "*.cache"
)

# Protected directories (never cleaned)
declare -a PROTECTED_DIRS=(
    ".git"
    ".svn"
    ".hg"
    ".bzr"
    "src"
    "lib"
    "docs"
    "README*"
    "LICENSE*"
    "*.md"
)

# Initialize build cleanup module
init_build_cleanup() {
    log_info "Initializing build cleanup module v$BUILD_CLEANUP_VERSION"
    log_debug "Build cleanup module initialized"
}

# Detect git repositories and project types
detect_project_info() {
    local dir_path="${1:-$(pwd)}"

    local project_type="unknown"
    local is_git_repo=false

    # Check if it's a git repository
    if git -C "$dir_path" rev-parse --git-dir >/dev/null 2>&1; then
        is_git_repo=true
    fi

    # Detect project type based on common files
    if [[ -f "$dir_path/package.json" ]]; then
        project_type="nodejs"
    elif [[ -f "$dir_path/requirements.txt" ]] || [[ -f "$dir_path/setup.py" ]] || [[ -f "$dir_path/pyproject.toml" ]]; then
        project_type="python"
    elif [[ -f "$dir_path/go.mod" ]] || [[ -f "$dir_path/go.sum" ]]; then
        project_type="go"
    elif [[ -f "$dir_path/Cargo.toml" ]] || [[ -f "$dir_path/Cargo.lock" ]]; then
        project_type="rust"
    elif [[ -f "$dir_path/pom.xml" ]] || [[ -f "$dir_path/build.gradle" ]] || [[ -f "$dir_path/build.gradle.kts" ]]; then
        project_type="java"
    elif [[ -f "$dir_path/Gemfile" ]] || [[ -f "$dir_path/*.gemspec" ]]; then
        project_type="ruby"
    elif [[ -f "$dir_path/Makefile" ]] || [[ -f "$dir_path/CMakeLists.txt" ]]; then
        project_type="c/cpp"
    elif [[ -f "$dir_path/composer.json" ]]; then
        project_type="php"
    fi

    echo "$is_git_repo:$project_type"
}

# Check if directory is in .gitignore
is_gitignored() {
    local item_path="$1"
    local repo_root="${2:-$(pwd)}"

    # Convert to relative path from repo root
    local rel_path
    rel_path=$(realpath --relative-to="$repo_root" "$item_path" 2>/dev/null || echo "$item_path")

    if git -C "$repo_root" check-ignore "$rel_path" >/dev/null 2>&1; then
        return 0  # Is gitignored
    else
        return 1  # Not gitignored
    fi
}

# Check if file is tracked by git
is_git_tracked() {
    local item_path="$1"
    local repo_root="${2:-$(pwd)}"

    local rel_path
    rel_path=$(realpath --relative-to="$repo_root" "$item_path" 2>/dev/null || echo "$item_path")

    if git -C "$repo_root" ls-files --error-unmatch "$rel_path" >/dev/null 2>&1; then
        return 0  # Is tracked
    else
        return 1  # Not tracked
    fi
}

# Check if file has local modifications
has_local_modifications() {
    local item_path="$1"
    local repo_root="${2:-$(pwd)}"

    local rel_path
    rel_path=$(realpath --relative-to="$repo_root" "$item_path" 2>/dev/null || echo "$item_path")

    if git -C "$repo_root" diff --quiet "$rel_path" 2>/dev/null; then
        return 1  # No modifications
    else
        return 0  # Has modifications
    fi
}

# Find build artifacts in a directory
find_build_artifacts() {
    local search_dir="${1:-$(pwd)}"
    local include_untracked="${2:-true}"

    local project_info
    project_info=$(detect_project_info "$search_dir")
    local is_git_repo="${project_info%%:*}"
    local project_type="${project_info##*:}"

    print_info "Scanning directory: $search_dir"
    print_indented 2 "Project type: $project_type"
    print_indented 2 "Git repository: $is_git_repo"

    local -a found_artifacts=()
    local total_size=0

    # Define patterns based on project type
    local -a project_patterns=()

    case "$project_type" in
        "nodejs")
            project_patterns=("node_modules" ".next" ".nuxt" "dist" "build" ".vscode" ".nyc_output" "coverage")
            ;;
        "python")
            project_patterns=("__pycache__" "*.pyc" "*.pyo" "*.pyd" ".pytest_cache" ".mypy_cache" ".tox" "venv" "env" ".venv" "*.egg-info" "build" "dist")
            ;;
        "go")
            project_patterns=("vendor" "bin" "*.exe" "*.test" "*.prof")
            ;;
        "rust")
            project_patterns=("target" "Cargo.lock" "**/*.rlib")
            ;;
        "java")
            project_patterns=("target" "build" "out" ".gradle" "*.class" "*.jar" "*.war")
            ;;
        "ruby")
            project_patterns=("vendor/bundle" ".bundle" "tmp" "log" "*.gem")
            ;;
        "c/cpp")
            project_patterns=("*.o" "*.obj" "*.exe" "*.so" "*.dylib" "cmake-build-*" "build-*")
            ;;
        "php")
            project_patterns=("vendor" "composer.lock" ".composer")
            ;;
    esac

    # Combine with general patterns
    local -a all_patterns=("${project_patterns[@]}" "${BUILD_PATTERNS[@]}")

    # Find artifacts
    for pattern in "${all_patterns[@]}"; do
        while IFS= read -r -d '' item; do
            if [[ -n "$item" ]]; then
                local should_clean=true

                # Skip protected directories
                for protected in "${PROTECTED_DIRS[@]}"; do
                    if [[ "$(basename "$item")" == $protected ]]; then
                        should_clean=false
                        break
                    fi
                done

                if [[ "$should_clean" == "true" ]]; then
                    # Git-aware checks
                    if [[ "$is_git_repo" == "true" ]]; then
                        local repo_root
                        repo_root=$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null || echo "$search_dir")

                        # Skip if item is tracked by git
                        if is_git_tracked "$item" "$repo_root"; then
                            if [[ "$BUILD_VERBOSE" == "true" ]]; then
                                print_indented 3 "$(format_status "info" "Skipping tracked item: $(basename "$item")")"
                            fi
                            continue
                        fi

                        # Check gitignore status
                        if is_gitignored "$item" "$repo_root"; then
                            # Item is gitignored - safe to clean
                            if [[ "$BUILD_VERBOSE" == "true" ]]; then
                                print_indented 3 "$(format_status "success" "Found gitignored: $(basename "$item")")"
                            fi
                        else
                            # Item is not gitignored but also not tracked
                            # Only clean if aggressive mode is enabled
                            if [[ "$BUILD_AGGRESSIVE" != "true" ]]; then
                                if [[ "$BUILD_VERBOSE" == "true" ]]; then
                                    print_indented 3 "$(format_status "warning" "Skipping untracked non-gitignored item: $(basename "$item")")"
                                fi
                                continue
                            fi
                        fi
                    fi

                    # Calculate size
                    local item_size=0
                    if [[ -d "$item" ]]; then
                        item_size=$(du -sb "$item" 2>/dev/null | cut -f1) || item_size=0
                    else
                        item_size=$(du -sb "$item" 2>/dev/null | cut -f1) || item_size=0
                    fi

                    found_artifacts+=("$item:$item_size")
                    total_size=$((total_size + item_size))

                    if [[ "$BUILD_VERBOSE" == "true" ]]; then
                        print_indented 3 "$(format_status "info" "Found artifact: $(basename "$item") ($(format_bytes $item_size))")"
                    fi
                fi
            fi
        done < <(find "$search_dir" -name "$pattern" -type f -o -name "$pattern" -type d -print0 2>/dev/null)
    done

    # Output results
    echo "total_size:$total_size"
    for artifact in "${found_artifacts[@]}"; do
        echo "artifact:$artifact"
    done
}

# Clean build artifacts in a directory
clean_build_artifacts() {
    local search_dir="${1:-$(pwd)}"

    print_section "Build Artifact Cleanup"
    print_info "Scanning for build artifacts in: $search_dir"

    # Find artifacts
    local -a artifacts=()
    local total_size=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^artifact:(.+)$ ]]; then
            artifacts+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^total_size:(.+)$ ]]; then
            total_size="${BASH_REMATCH[1]}"
        fi
    done < <(find_build_artifacts "$search_dir")

    if [[ ${#artifacts[@]} -eq 0 ]]; then
        print_info "No build artifacts found"
        return 0
    fi

    print_success "Found ${#artifacts[@]} build artifacts ($(format_bytes $total_size))"

    if [[ "$BUILD_DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would remove ${#artifacts[@]} artifacts ($(format_bytes $total_size))"

        if [[ "$BUILD_VERBOSE" == "true" ]]; then
            echo ""
            print_info "Artifacts that would be removed:"
            for artifact in "${artifacts[@]}"; do
                local item_path="${artifact%:*}"
                local item_size="${artifact##*:}"
                print_indented 2 "$(basename "$item_path") ($(format_bytes $item_size))"
            done
        fi
        return 0
    fi

    if [[ "$BUILD_FORCE" != "true" ]]; then
        if ! confirm_with_warning "Remove ${#artifacts[@]} build artifacts ($(format_bytes $total_size))?" "This will remove build artifacts and dependency directories. Make sure you have no unsaved work."; then
            print_info "Build artifact cleanup cancelled"
            return 0
        fi
    fi

    # Perform cleanup
    local removed_count=0
    local freed_space=0

    for artifact in "${artifacts[@]}"; do
        local item_path="${artifact%:*}"
        local item_size="${artifact##*:}"

        if rm -rf "$item_path" 2>/dev/null; then
            ((removed_count++))
            ((freed_space += item_size))

            if [[ "$BUILD_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "success" "Removed: $(basename "$item_path") ($(format_bytes $item_size))")"
            fi
        else
            print_warning "Failed to remove: $(basename "$item_path")"
        fi
    done

    print_success "Removed $removed_count build artifacts ($(format_bytes $freed_space) freed)"
    show_cleanup_summary "$removed_count" "$freed_space"
}

# Clean git-specific artifacts
clean_git_artifacts() {
    local search_dir="${1:-$(pwd)}"

    if ! git -C "$search_dir" rev-parse --git-dir >/dev/null 2>&1; then
        print_info "Not a git repository, skipping git-specific cleanup"
        return 0
    fi

    print_section "Git-Specific Cleanup"

    local repo_root
    repo_root=$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null || echo "$search_dir")

    local total_removed=0
    local total_freed=0

    # Clean git reflog
    if [[ "$BUILD_AGGRESSIVE" == "true" ]]; then
        print_info "Cleaning git reflog"

        if [[ "$BUILD_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean git reflog")"
        else
            if git -C "$repo_root" reflog expire --expire=now --all 2>/dev/null; then
                print_success "Git reflog cleaned"
            fi
        fi
    fi

    # Clean stale remote branches
    if [[ "$BUILD_AGGRESSIVE" == "true" ]]; then
        print_info "Cleaning stale remote branches"

        if [[ "$BUILD_DRY_RUN" == "true" ]]; then
            print_indented 2 "$(format_status "info" "Would clean stale remote branches")"
        else
            local stale_branches
            stale_branches=$(git -C "$repo_root" remote prune origin --dry-run 2>/dev/null | grep "would prune" || true)

            if [[ -n "$stale_branches" ]]; then
                if git -C "$repo_root" remote prune origin 2>/dev/null; then
                    print_success "Stale remote branches cleaned"
                fi
            fi
        fi
    fi

    # Clean untracked files (git clean)
    print_info "Cleaning untracked files"

    if [[ "$BUILD_DRY_RUN" == "true" ]]; then
        local untracked_files
        untracked_files=$(git -C "$repo_root" clean -n -d 2>/dev/null | wc -l || echo "0")
        print_indented 2 "$(format_status "info" "Would remove $untracked_files untracked files/directories")"
    else
        local removed_files=0
        local git_clean_output
        git_clean_output=$(git -C "$repo_root" clean -fd 2>/dev/null || true)

        if [[ -n "$git_clean_output" ]]; then
            removed_files=$(echo "$git_clean_output" | wc -l || echo "0")
            ((total_removed += removed_files))
            print_success "Removed $removed_files untracked files/directories"
        fi
    fi

    # Clean stashes (if not keeping them)
    if [[ "$BUILD_KEEP_STASHES" != "true" ]]; then
        print_info "Cleaning git stashes"

        if [[ "$BUILD_DRY_RUN" == "true" ]]; then
            local stash_count
            stash_count=$(git -C "$repo_root" stash list 2>/dev/null | wc -l || echo "0")
            print_indented 2 "$(format_status "info" "Would clear $stash_count stashes")"
        else
            local stash_count
            stash_count=$(git -C "$repo_root" stash list 2>/dev/null | wc -l || echo "0")

            if [[ $stash_count -gt 0 ]]; then
                if git -C "$repo_root" stash clear 2>/dev/null; then
                    print_success "Cleared $stash_count stashes"
                    ((total_removed += stash_count))
                fi
            fi
        fi
    else
        print_info "Keeping git stashes (--keep-stashes)"
    fi

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Clean multiple directories recursively
clean_multiple_directories() {
    local root_dir="${1:-$(pwd)}"
    local max_depth="${2:-2}"

    print_section "Recursive Build Artifact Cleanup"
    print_info "Scanning directories up to depth $max_depth from: $root_dir"

    local total_removed=0
    local total_freed=0

    # Find all git repositories and project directories
    while IFS= read -r -d '' project_dir; do
        echo ""
        print_info "Processing project: $(realpath --relative-to="$root_dir" "$project_dir")"

        # Skip if directory is protected
        local should_process=true
        for protected in "${PROTECTED_DIRS[@]}"; do
            if [[ "$(basename "$project_dir")" == $protected ]]; then
                should_process=false
                break
            fi
        done

        if [[ "$should_process" == "true" ]]; then
            # Clean build artifacts
            local artifacts_removed=0
            local space_freed=0

            while IFS= read -r line; do
                if [[ "$line" =~ ^artifact:(.+)$ ]]; then
                    local artifact="${BASH_REMATCH[1]}"
                    local item_path="${artifact%:*}"
                    local item_size="${artifact##*:}"

                    if [[ "$BUILD_DRY_RUN" != "true" ]]; then
                        if rm -rf "$item_path" 2>/dev/null; then
                            ((artifacts_removed++))
                            ((space_freed += item_size))
                            if [[ "$BUILD_VERBOSE" == "true" ]]; then
                                print_indented 3 "Removed: $(basename "$item_path")"
                            fi
                        fi
                    fi
                elif [[ "$line" =~ ^total_size:(.+)$ ]]; then
                    if [[ "$BUILD_DRY_RUN" == "true" ]]; then
                        print_indented 2 "Would clean: ${BASH_REMATCH[1]} bytes"
                    fi
                fi
            done < <(find_build_artifacts "$project_dir")

            ((total_removed += artifacts_removed))
            ((total_freed += space_freed))

            if [[ $artifacts_removed -gt 0 ]]; then
                print_success "Cleaned $artifacts_removed artifacts ($(format_bytes $space_freed))"
            fi
        fi
    done < <(find "$root_dir" -maxdepth $max_depth -type d \( \
        -name ".git" -o \
        -name "package.json" -o \
        -name "requirements.txt" -o \
        -name "setup.py" -o \
        -name "pyproject.toml" -o \
        -name "go.mod" -o \
        -name "Cargo.toml" -o \
        -name "pom.xml" -o \
        -name "build.gradle" -o \
        -name "Gemfile" -o \
        -name "Makefile" -o \
        -name "CMakeLists.txt" -o \
        -name "composer.json" \
    \) -print0 2>/dev/null)

    show_cleanup_summary "$total_removed" "$total_freed"
}

# Comprehensive build cleanup
cleanup_build_comprehensive() {
    print_header "Comprehensive Build Artifact Cleanup"
    print_info "Performing git-aware build artifact cleanup"

    if [[ "$BUILD_DRY_RUN" == "false" ]] && [[ "$BUILD_FORCE" == "false" ]]; then
        if ! confirm_with_warning "This will clean build artifacts and git-specific items. Continue?" "This operation removes build artifacts, untracked files, and optionally git stashes. Make sure you have committed any important changes."; then
            print_info "Build cleanup cancelled"
            return 0
        fi
    fi

    # Clean build artifacts in current directory
    clean_build_artifacts

    # Clean git-specific artifacts
    clean_git_artifacts

    # Optionally clean recursively in subdirectories
    if [[ "$BUILD_VERBOSE" == "true" ]]; then
        echo ""
        if confirm_with_warning "Also clean build artifacts in subdirectories recursively?" "This will scan and clean subdirectories up to depth 2."; then
            clean_multiple_directories "$(pwd)" 2
        fi
    fi

    print_header "Build Artifact Cleanup Complete"
    print_success "Build artifact cleanup completed successfully"
}

# Parse build cleanup arguments
parse_build_cleanup_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                BUILD_FORCE=true
                shift
                ;;
            -n|--dry-run)
                BUILD_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                BUILD_VERBOSE=true
                shift
                ;;
            -r|--retention)
                BUILD_RETENTION_DAYS="$2"
                shift 2
                ;;
            --keep-stashes)
                BUILD_KEEP_STASHES=true
                shift
                ;;
            --keep-locked)
                BUILD_KEEP_LOCKED=true
                shift
                ;;
            --aggressive)
                BUILD_AGGRESSIVE=true
                shift
                ;;
            --recursive)
                shift
                clean_multiple_directories "$(pwd)" "${1:-2}"
                exit 0
                ;;
            -h|--help)
                show_build_cleanup_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_build_cleanup_help
                exit 1
                ;;
        esac
    done
}

# Show build cleanup help
show_build_cleanup_help() {
    cat << EOF
${BOLD}${CYAN}Build Artifact Cleanup Module${RESET}
${ITALIC}Git-aware cleanup of build artifacts and dependency directories${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}fub cleanup build${RESET} [${YELLOW}DIRECTORY${RESET}] [${YELLOW}OPTIONS${RESET}]

${BOLD}Options:${RESET}
    ${YELLOW}-f, --force${RESET}                    Skip confirmation prompts
    ${YELLOW}-n, --dry-run${RESET}                  Show what would be cleaned
    ${YELLOW}-v, --verbose${RESET}                  Verbose output with details
    ${YELLOW}-r, --retention${RESET} DAYS          Retention period in days (default: 7)
    ${YELLOW}--keep-stashes${RESET}                Keep git stashes
    ${YELLOW}--keep-locked${RESET}                 Keep locked files
    ${YELLOW}--aggressive${RESET}                  Clean more aggressively (reflog, etc.)
    ${YELLOW}--recursive${RESET} [DEPTH]           Clean recursively (default depth: 2)
    ${YELLOW}-h, --help${RESET}                     Show this help

${BOLD}Examples:${RESET}
    ${GREEN}fub cleanup build${RESET}                    # Clean current directory
    ${GREEN}fub cleanup build --dry-run${RESET}          # Preview cleanup actions
    ${GREEN}fub cleanup build --aggressive${RESET}       # Aggressive cleanup mode
    ${GREEN}fub cleanup build --recursive 3${RESET}      # Clean recursively up to depth 3
    ${GREEN}fub cleanup build /path/to/project${RESET}   # Clean specific directory

${BOLD}What gets cleaned:${RESET}
    • Language-specific build directories (target, build, dist, out)
    • Dependency directories (node_modules, vendor, .gradle)
    • Cache directories (__pycache__, .pytest_cache, .next)
    • Temporary files and logs
    • Untracked files (git clean)
    • Git stashes (unless --keep-stashes)

${BOLD}Git-Aware Features:${RESET}
    • Preserves git-tracked files
    • Respects .gitignore patterns
    • Only cleans untracked/uncommitted artifacts
    • Safe handling of git worktrees
    • Preserves locked files by default
    • Repository-specific cleanup strategies

${BOLD}Language Support:${RESET}
    • Node.js: node_modules, .next, .nuxt, dist, coverage
    • Python: __pycache__, .venv, .pytest_cache, build
    • Go: vendor, bin, compiled executables
    • Rust: target/, Cargo.lock
    • Java: target/, build/, .gradle/
    • Ruby: vendor/bundle, tmp, log
    • C/C++: object files, executables, cmake builds
    • PHP: vendor/, composer cache

${BOLD}Safety Features:${RESET}
    • Never removes git-tracked files
    • Respects .gitignore patterns
    • Preserves source code directories
    - Dry-run mode for safe preview
    - Recursive scanning with depth control
    - Protection for important project files

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

        if [[ "$BUILD_DRY_RUN" == "true" ]]; then
            print_info "This was a dry run. No files were actually removed."
            print_info "Run without --dry-run to perform the cleanup."
        fi
    }
fi

# Export functions for use in main cleanup script
export -f init_build_cleanup detect_project_info is_gitignored is_git_tracked
export -f has_local_modifications find_build_artifacts clean_build_artifacts
export -f clean_git_artifacts clean_multiple_directories cleanup_build_comprehensive
export -f parse_build_cleanup_args show_build_cleanup_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_build_cleanup
    parse_build_cleanup_args "$@"

    # Default action if no directory specified
    local target_dir="${1:-$(pwd)}"

    # Skip if the argument is an option
    if [[ "$target_dir" =~ ^- ]]; then
        target_dir="$(pwd)"
    fi

    cleanup_build_comprehensive "$target_dir"
fi