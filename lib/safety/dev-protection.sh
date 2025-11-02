#!/usr/bin/env bash

# FUB Development Environment Protection Module
# Smart detection and protection of development environments

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Development protection constants
readonly DEV_PROTECTION_VERSION="1.0.0"
readonly DEV_PROTECTION_DESCRIPTION="Development environment detection and protection"

# Development file patterns to protect
declare -a DEV_FILE_PATTERNS=(
    "*.py" "*.js" "*.ts" "*.java" "*.c" "*.cpp" "*.h" "*.hpp"
    "*.go" "*.rs" "*.rb" "*.php" "*.swift" "*.kt" "*.scala"
    "*.html" "*.css" "*.scss" "*.sass" "*.less"
    "*.json" "*.yaml" "*.yml" "*.toml" "*.xml" "*.ini" "*.cfg"
    "Dockerfile" "docker-compose.*" "Makefile" "CMakeLists.txt"
    "package.json" "package-lock.json" "yarn.lock" "requirements.txt"
    "Gemfile" "Gemfile.lock" "Cargo.toml" "Cargo.lock" "go.mod"
    "pom.xml" "build.gradle" "composer.json"
)

# Project indicator files
declare -a PROJECT_INDICATORS=(
    ".git" ".svn" ".hg" ".bzr"
    "package.json" "requirements.txt" "Gemfile" "Cargo.toml"
    "go.mod" "pom.xml" "build.gradle" "composer.json"
    "Makefile" "CMakeLists.txt" "setup.py" "setup.cfg"
    ".vscode" ".idea" ".eclipse" ".project"
    "node_modules" "target" "build" "dist" "vendor"
)

# Important configuration and data files to protect
declare -a IMPORTANT_FILES=(
    ".env" ".env.*" "config.*" "*.config" "*.conf"
    "database.yml" "secrets.yml" "credentials.json"
    "id_rsa*" "id_ed25519*" "known_hosts"
    "*.pem" "*.key" "*.crt" "*.p12" "*.pfx"
    "*.db" "*.sqlite" "*.sqlite3" "*.mdb"
)

# Initialize development protection module
init_dev_protection() {
    log_info "Initializing development protection module v$DEV_PROTECTION_VERSION"
    log_debug "Development protection module initialized"
}

# Detect development directories
detect_development_directories() {
    print_section "Detecting Development Directories"

    local dev_dirs_found=0
    local -a detected_dirs

    # Common development directories
    local -a search_paths=(
        "/home/$USER"
        "/home/$USER/projects"
        "/home/$USER/dev"
        "/home/$USER/src"
        "/home/$USER/workspace"
        "/home/$USER/code"
        "/home/$USER/Development"
        "/tmp"
        "/var/tmp"
    )

    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            local dev_dirs
            dev_dirs=$(find_development_dirs_in_path "$path")

            if [[ -n "$dev_dirs" ]]; then
                while IFS= read -r dev_dir; do
                    detected_dirs+=("$dev_dir")
                    ((dev_dirs_found++))
                done <<< "$dev_dirs"
            fi
        fi
    done

    # Report findings
    if [[ $dev_dirs_found -gt 0 ]]; then
        print_success "Development directories detected: $dev_dirs_found"

        if [[ "$SAFETY_VERBOSE" == "true" ]]; then
            for dir in "${detected_dirs[@]}"; do
                local dir_type
                dir_type=$(detect_project_type "$dir")
                print_indented 2 "$(format_status "info" "$dir ($dir_type)")"
            done
        fi

        # Export detected directories for other modules
        export FUB_DEV_DIRS="${detected_dirs[*]}"
    else
        print_info "No development directories detected"
        export FUB_DEV_DIRS=""
    fi

    return 0
}

# Find development directories in a given path
find_development_dirs_in_path() {
    local search_path="$1"
    local -a found_dirs

    # Limit search depth to avoid excessive scanning
    local max_depth=3

    # Search for Git repositories first (most reliable)
    while IFS= read -r -d '' git_dir; do
        local project_dir
        project_dir=$(dirname "$git_dir")
        found_dirs+=("$project_dir")
    done < <(find "$search_path" -maxdepth $max_depth -type d -name ".git" -print0 2>/dev/null)

    # Search for other project indicators
    for indicator in "${PROJECT_INDICATORS[@]}"; do
        if [[ "$indicator" != ".git" ]]; then
            while IFS= read -r -d '' indicator_file; do
                local project_dir
                project_dir=$(dirname "$indicator_file")

                # Avoid duplicates
                local is_duplicate=false
                for existing in "${found_dirs[@]}"; do
                    if [[ "$existing" == "$project_dir" ]]; then
                        is_duplicate=true
                        break
                    fi
                done

                if [[ "$is_duplicate" == "false" ]]; then
                    found_dirs+=("$project_dir")
                fi
            done < <(find "$search_path" -maxdepth $max_depth -name "$indicator" -print0 2>/dev/null)
        fi
    done

    # Output found directories
    printf '%s\n' "${found_dirs[@]}"
}

# Detect project type
detect_project_type() {
    local project_dir="$1"

    if [[ -f "$project_dir/package.json" ]]; then
        echo "Node.js"
    elif [[ -f "$project_dir/requirements.txt" ]] || [[ -f "$project_dir/setup.py" ]] || [[ -f "$project_dir/pyproject.toml" ]]; then
        echo "Python"
    elif [[ -f "$project_dir/Cargo.toml" ]]; then
        echo "Rust"
    elif [[ -f "$project_dir/go.mod" ]]; then
        echo "Go"
    elif [[ -f "$project_dir/pom.xml" ]] || [[ -f "$project_dir/build.gradle" ]]; then
        echo "Java"
    elif [[ -f "$project_dir/Gemfile" ]]; then
        echo "Ruby"
    elif [[ -f "$project_dir/composer.json" ]]; then
        echo "PHP"
    elif [[ -f "$project_dir/CMakeLists.txt" ]] || [[ -f "$project_dir/Makefile" ]]; then
        echo "C/C++"
    else
        echo "Unknown"
    fi
}

# Check for active development sessions
check_active_development_sessions() {
    print_section "Checking Active Development Sessions"

    local active_sessions=0
    local -a active_processes

    # Development editor processes
    local -a editor_processes=(
        "code" "code-insiders" "vim" "nvim" "emacs" "sublime_text"
        "atom" "brackets" "phpstorm" "pycharm" "intellij"
        "webstorm" "clion" "rider" "goland" "datagrip"
        "vscode" "nano" "micro"
    )

    # Development tool processes
    local -a dev_tool_processes=(
        "node" "npm" "yarn" "pnpm" "python" "pip" "pip3"
        "java" "javac" "mvn" "gradle" "cargo" "rustc"
        "go" "gcc" "g++" "make" "cmake" "pytest"
        "jest" "mocha" "karma" "webpack" "parcel" "vite"
        "docker" "docker-compose" "git" "ssh"
    )

    # Check for active editor processes
    for process in "${editor_processes[@]}"; do
        if pgrep -x "$process" >/dev/null 2>&1; then
            local process_count
            process_count=$(pgrep -x "$process" | wc -l)
            print_indented 2 "$(format_status "warning" "$process: $process_count processes")"
            active_processes+=("$process:$process_count")
            ((active_sessions++))
        fi
    done

    # Check for development tool processes
    for process in "${dev_tool_processes[@]}"; do
        if pgrep -x "$process" >/dev/null 2>&1; then
            local process_count
            process_count=$(pgrep -x "$process" | wc -l)
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "info" "$process: $process_count processes")"
            fi
            active_processes+=("$process:$process_count")
        fi
    done

    # Check for open files in development directories
    if [[ -n "$FUB_DEV_DIRS" ]]; then
        local open_files_count=0
        for dev_dir in $FUB_DEV_DIRS; do
            if [[ -d "$dev_dir" ]]; then
                local open_files
                open_files=$(lsof +D "$dev_dir" 2>/dev/null | wc -l || echo "0")
                if [[ $open_files -gt 0 ]]; then
                    ((open_files_count += open_files))
                    print_indented 2 "$(format_status "warning" "$open_files files open in $dev_dir")"
                fi
            fi
        done

        if [[ $open_files_count -gt 0 ]]; then
            print_warning "Total open files in development directories: $open_files_count"
        fi
    fi

    # Report findings
    if [[ $active_sessions -gt 0 ]]; then
        print_warning "Active development sessions detected: $active_sessions"
        print_warning "Consider saving work before proceeding with cleanup"

        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Continue despite active development sessions?" "Cleanup may affect active development work"; then
                print_info "Cleanup cancelled - active development sessions"
                return 1
            fi
        fi
    else
        print_success "No active development sessions detected"
    fi

    return 0
}

# Protect important development files
protect_important_files() {
    print_section "Protecting Important Development Files"

    local protected_files=0
    local protected_dirs=0

    # Create protection patterns for important files
    local -a protection_patterns=()
    for pattern in "${IMPORTANT_FILES[@]}"; do
        protection_patterns+=("-name" "$pattern")
    done

    # Check development directories for important files
    if [[ -n "$FUB_DEV_DIRS" ]]; then
        for dev_dir in $FUB_DEV_DIRS; do
            if [[ -d "$dev_dir" ]]; then
                # Find important files
                while IFS= read -r -d '' important_file; do
                    if [[ -f "$important_file" ]]; then
                        ((protected_files++))
                        if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                            local relative_path="${important_file#$dev_dir/}"
                            print_indented 2 "$(format_status "success" "Protected: $relative_path")"
                        fi
                    fi
                done < <(find "$dev_dir" -type f \( "${protection_patterns[@]}" \) -print0 2>/dev/null)

                # Check for important directories
                local -a important_dirs=(".git" ".vscode" ".idea" "node_modules")
                for important_dir in "${important_dirs[@]}"; do
                    if [[ -d "$dev_dir/$important_dir" ]]; then
                        ((protected_dirs++))
                        if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                            print_indented 2 "$(format_status "success" "Protected dir: $important_dir")"
                        fi
                    fi
                done
            fi
        done
    fi

    # Report protection summary
    if [[ $protected_files -gt 0 ]] || [[ $protected_dirs -gt 0 ]]; then
        print_success "Development protection applied"
        print_info "Protected files: $protected_files, Protected directories: $protected_dirs"
    else
        print_info "No important development files found requiring protection"
    fi

    return 0
}

# Check for unsaved work
check_unsaved_work() {
    print_section "Checking for Unsaved Work"

    local unsaved_detected=false

    # Check for common swap files (indicative of unsaved work)
    if [[ -n "$FUB_DEV_DIRS" ]]; then
        local swap_files_count=0

        for dev_dir in $FUB_DEV_DIRS; do
            if [[ -d "$dev_dir" ]]; then
                local swap_files
                swap_files=$(find "$dev_dir" -name "*.swp" -o -name "*.swo" -o -name "*~" -o -name ".#*" 2>/dev/null | wc -l)
                ((swap_files_count += swap_files))
            fi
        done

        if [[ $swap_files_count -gt 0 ]]; then
            print_warning "Swap files detected: $swap_files_count"
            print_warning "This may indicate unsaved work in editors"
            unsaved_detected=true
        fi
    fi

    # Check for modified files in Git repositories
    if [[ -n "$FUB_DEV_DIRS" ]]; then
        local modified_repos=0

        for dev_dir in $FUB_DEV_DIRS; do
            if [[ -d "$dev_dir/.git" ]]; then
                local modified_files
                modified_files=$(git -C "$dev_dir" status --porcelain 2>/dev/null | wc -l)
                if [[ $modified_files -gt 0 ]]; then
                    ((modified_repos++))
                    if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                        print_indented 2 "$(format_status "warning" "$modified_files modified files in $(basename "$dev_dir")")"
                    fi
                fi
            fi
        done

        if [[ $modified_repos -gt 0 ]]; then
            print_warning "Modified files detected in $modified_repos Git repositories"
            unsaved_detected=true
        fi
    fi

    # Report findings
    if [[ "$unsaved_detected" == "true" ]]; then
        print_warning "Unsaved work detected"
        print_warning "Please save your work before proceeding with cleanup"

        if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
            if ! confirm_with_warning "Continue despite unsaved work?" "You may lose unsaved changes"; then
                print_info "Cleanup cancelled - unsaved work detected"
                return 1
            fi
        fi
    else
        print_success "No obvious unsaved work detected"
    fi

    return 0
}

# Create development environment backup
create_dev_backup() {
    if [[ "$SAFETY_BACKUP_IMPORTANT" != "true" ]]; then
        return 0
    fi

    print_section "Creating Development Environment Backup"

    local backup_dir="/tmp/fub_dev_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    local backed_up_items=0

    # Backup important configuration files from development directories
    if [[ -n "$FUB_DEV_DIRS" ]]; then
        for dev_dir in $FUB_DEV_DIRS; do
            if [[ -d "$dev_dir" ]]; then
                local dev_name
                dev_name=$(basename "$dev_dir")
                local dev_backup_dir="$backup_dir/$dev_name"
                mkdir -p "$dev_backup_dir"

                # Backup important files
                local -a backup_patterns=(".env*" "config.*" "package.json" "requirements.txt")
                for pattern in "${backup_patterns[@]}"; do
                    while IFS= read -r -d '' backup_file; do
                        local relative_path="${backup_file#$dev_dir/}"
                        local backup_path="$dev_backup_dir/$relative_path"
                        local backup_dir_path=$(dirname "$backup_path")

                        mkdir -p "$backup_dir_path"
                        if cp "$backup_file" "$backup_path" 2>/dev/null; then
                            ((backed_up_items++))
                            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                                print_indented 2 "$(format_status "success" "Backed up: $relative_path")"
                            fi
                        fi
                    done < <(find "$dev_dir" -name "$pattern" -type f -print0 2>/dev/null)
                done
            fi
        done
    fi

    # Report backup summary
    if [[ $backed_up_items -gt 0 ]]; then
        print_success "Development backup created: $backup_dir"
        print_info "Backed up items: $backed_up_items"
        print_info "Backup will be kept for 24 hours"

        # Schedule cleanup of backup directory
        echo "find '$backup_dir' -type f -mtime +1 -delete 2>/dev/null; find '$backup_dir' -type d -empty -delete 2>/dev/null" | at now + 24 hours 2>/dev/null || true
    else
        rmdir "$backup_dir" 2>/dev/null || true
        print_info "No development files required backup"
    fi

    return 0
}

# Perform comprehensive development protection
perform_dev_protection() {
    print_header "Development Environment Protection"
    print_info "Detecting and protecting development environments"

    local protection_failed=false

    # Initialize module
    init_dev_protection

    # Run all development protection checks
    if ! detect_development_directories; then
        protection_failed=true
    fi

    if ! check_active_development_sessions; then
        protection_failed=true
    fi

    if ! check_unsaved_work; then
        protection_failed=true
    fi

    # Apply protections
    if ! protect_important_files; then
        protection_failed=true
    fi

    # Create backup if requested
    if [[ "$protection_failed" != "true" ]]; then
        create_dev_backup
    fi

    if [[ "$protection_failed" == "true" ]]; then
        print_error "Development protection failed"
        return 1
    else
        print_success "Development environment protection applied"
        return 0
    fi
}

# Show development protection help
show_dev_protection_help() {
    cat << EOF
${BOLD}${CYAN}Development Environment Protection Module${RESET}
${ITALIC}Smart detection and protection of development environments${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source dev-protection.sh${RESET}
    ${GREEN}perform_dev_protection${RESET}

${BOLD}Functions:${RESET}
    ${YELLOW}detect_development_directories${RESET}    Scan for development directories
    ${YELLOW}check_active_development_sessions${RESET} Check for active development work
    ${YELLOW}protect_important_files${RESET}          Apply protection to important files
    ${YELLOW}check_unsaved_work${RESET}               Detect unsaved work
    ${YELLOW}create_dev_backup${RESET}                Backup development configurations
    ${YELLOW}perform_dev_protection${RESET}           Run all development protections

${BOLD}Protected File Types:${RESET}
    • Source code files (*.py, *.js, *.java, etc.)
    • Configuration files (*.json, *.yaml, *.toml, etc.)
    • Environment files (.env, config.*)
    • SSH keys and certificates
    • Database files (*.db, *.sqlite)
    • Build files (Makefile, CMakeLists.txt)

${BOLD}Project Detection:${RESET}
    • Git, SVN, Mercurial repositories
    • Node.js (package.json)
    • Python (requirements.txt, setup.py)
    • Rust (Cargo.toml)
    • Go (go.mod)
    • Java (pom.xml, build.gradle)
    • And many more...

${BOLD}Development Tools Detected:${RESET}
    • Code editors (VSCode, Vim, Emacs, etc.)
    • Development tools (npm, pip, cargo, etc.)
    • Build tools (make, cmake, webpack, etc.)
    • Version control (git, svn)

EOF
}

# Export functions for use in other scripts
export -f init_dev_protection detect_development_directories
export -f check_active_development_sessions protect_important_files
export -f check_unsaved_work create_dev_backup perform_dev_protection
export -f show_dev_protection_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    perform_dev_protection
fi