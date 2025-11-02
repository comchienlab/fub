#!/usr/bin/env bash

# FUB Backup System Module
# Comprehensive backup creation and restoration before aggressive cleanup

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Backup system constants
readonly BACKUP_VERSION="1.0.0"
readonly BACKUP_DESCRIPTION="Backup creation and restoration system"

# Backup configuration
readonly DEFAULT_BACKUP_RETENTION_DAYS=7
readonly DEFAULT_BACKUP_LOCATION="/tmp/fub_backups"
readonly BACKUP_LOCK_FILE="/tmp/fub_backup_in_progress"

# Backup types
declare -a BACKUP_TYPES=("full" "incremental" "config" "package" "development")

# Initialize backup system
init_backup_system() {
    log_info "Initializing backup system module v$BACKUP_VERSION"
    log_debug "Backup system module initialized"

    # Create backup directory if it doesn't exist
    if [[ ! -d "$DEFAULT_BACKUP_LOCATION" ]]; then
        mkdir -p "$DEFAULT_BACKUP_LOCATION"
    fi
}

# Create backup directory structure
create_backup_structure() {
    local backup_id="$1"
    local backup_root="${2:-$DEFAULT_BACKUP_LOCATION}"
    local backup_dir="$backup_root/$backup_id"

    mkdir -p "$backup_dir"/{config,packages,development,system,logs}

    # Create backup metadata file
    cat > "$backup_dir/metadata.json" << EOF
{
    "backup_id": "$backup_id",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "user": "$USER",
    "fub_version": "$(cat "$FUB_SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")",
    "backup_types": [],
    "total_size": 0,
    "files_count": 0,
    "directories_count": 0
}
EOF

    echo "$backup_dir"
}

# Backup system configurations
backup_system_configurations() {
    local backup_dir="$1"
    local config_dir="$backup_dir/config"
    local backed_up_files=0

    print_section "Backing Up System Configurations"

    # Important system configuration files
    local -a config_files=(
        "/etc/fstab" "/etc/hosts" "/etc/hostname" "/etc/resolv.conf"
        "/etc/passwd" "/etc/group" "/etc/shadow" "/etc/gshadow"
        "/etc/sudoers" "/etc/ssh/sshd_config" "/etc/security/limits.conf"
        "/etc/systemd/system" "/etc/sysctl.conf" "/etc/limits.conf"
    )

    # Network configurations
    local -a network_configs=(
        "/etc/network/interfaces" "/etc/netplan" "/etc/NetworkManager"
        "/etc/dhcp" "/etc/resolvconf" "/etc/hosts.deny" "/etc/hosts.allow"
    )

    # Package manager configurations
    local -a package_configs=(
        "/etc/apt" "/etc/apt/sources.list*" "/etc/apt/sources.list.d"
        "/etc/dpkg" "/etc/apt.conf.d"
    )

    # User configurations
    local -a user_configs=(
        "/home/$USER/.bashrc" "/home/$USER/.profile" "/home/$USER/.zshrc"
        "/home/$USER/.ssh" "/home/$USER/.gnupg" "/home/$USER/.config"
    )

    # Backup each category
    for config_type in "config_files" "network_configs" "package_configs" "user_configs"; do
        local -n configs=$config_type
        local type_dir="$config_dir/${config_type%_*}"

        mkdir -p "$type_dir"

        for config in "${configs[@]}"; do
            if [[ -e "$config" ]]; then
                local backup_path="$config_dir${config}"
                local backup_dir_path=$(dirname "$backup_path")

                mkdir -p "$backup_dir_path"

                if cp -r "$config" "$backup_path" 2>/dev/null; then
                    ((backed_up_files++))
                    if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                        print_indented 2 "$(format_status "success" "Backed up: $config")"
                    fi
                fi
            fi
        done
    done

    # Create configuration manifest
    find "$config_dir" -type f -print0 > "$config_dir/file_manifest.txt"

    print_success "System configurations backed up: $backed_up_files files"
    return 0
}

# Backup installed packages
backup_installed_packages() {
    local backup_dir="$1"
    local packages_dir="$backup_dir/packages"

    print_section "Backing Up Package Information"

    mkdir -p "$packages_dir"

    local packages_backed_up=0

    # Backup APT packages if available
    if command_exists apt; then
        # List installed packages
        apt list --installed 2>/dev/null > "$packages_dir/apt_installed.txt"
        ((packages_backed_up++))

        # List apt sources
        cp -r /etc/apt/sources.list* "$packages_dir/" 2>/dev/null || true
        cp -r /etc/apt/sources.list.d "$packages_dir/" 2>/dev/null || true

        # Get package holds
        apt-mark showhold > "$packages_dir/apt_holds.txt" 2>/dev/null || true

        if [[ "$SAFETY_VERBOSE" == "true" ]]; then
            print_indented 2 "$(format_status "success" "APT packages backed up")"
        fi
    fi

    # Backup Snap packages if available
    if command_exists snap; then
        snap list > "$packages_dir/snap_installed.txt" 2>/dev/null || true
        ((packages_backed_up++))

        if [[ "$SAFETY_VERBOSE" == "true" ]]; then
            print_indented 2 "$(format_status "success" "Snap packages backed up")"
        fi
    fi

    # Backup Flatpak packages if available
    if command_exists flatpak; then
        flatpak list > "$packages_dir/flatpak_installed.txt" 2>/dev/null || true
        ((packages_backed_up++))

        if [[ "$SAFETY_VERBOSE" == "true" ]]; then
            print_indented 2 "$(format_status "success" "Flatpak packages backed up")"
        fi
    fi

    # Create restoration script for packages
    cat > "$packages_dir/restore_packages.sh" << 'EOF'
#!/usr/bin/env bash

# FUB Package Restoration Script
# Automatically generated - use with caution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Restoring packages from backup..."

# Restore APT packages
if [[ -f "$SCRIPT_DIR/apt_installed.txt" ]]; then
    echo "Restoring APT packages..."
    apt update
    grep -v "WARNING" "$SCRIPT_DIR/apt_installed.txt" | cut -d'/' -f1 | tail -n +2 | xargs apt install -y 2>/dev/null || true
fi

# Restore Snap packages
if [[ -f "$SCRIPT_DIR/snap_installed.txt" ]]; then
    echo "Restoring Snap packages..."
    tail -n +2 "$SCRIPT_DIR/snap_installed.txt" | awk '{print $1}' | xargs -I {} snap install {} 2>/dev/null || true
fi

# Restore Flatpak packages
if [[ -f "$SCRIPT_DIR/flatpak_installed.txt" ]]; then
    echo "Restoring Flatpak packages..."
    tail -n +2 "$SCRIPT_DIR/flatpak_installed.txt" | awk '{print $1}' | xargs -I {} flatpak install -y {} 2>/dev/null || true
fi

echo "Package restoration completed"
EOF

    chmod +x "$packages_dir/restore_packages.sh"

    print_success "Package information backed up: $packages_backed_up package managers"
    return 0
}

# Backup development environments
backup_development_environments() {
    local backup_dir="$1"
    local dev_dir="$backup_dir/development"

    print_section "Backing Up Development Environments"

    mkdir -p "$dev_dir"

    local dev_backups=0

    # Backup development directory configurations if detected
    if [[ -n "$FUB_DEV_DIRS" ]]; then
        for dev_path in $FUB_DEV_DIRS; do
            if [[ -d "$dev_path" ]]; then
                local dev_name
                dev_name=$(basename "$dev_path")
                local dev_backup_dir="$dev_dir/$dev_name"

                mkdir -p "$dev_backup_dir"

                # Backup package files
                local -a package_files=("package.json" "package-lock.json" "yarn.lock" "requirements.txt" "Pipfile" "poetry.lock" "Cargo.toml" "go.mod")
                for pkg_file in "${package_files[@]}"; do
                    if [[ -f "$dev_path/$pkg_file" ]]; then
                        cp "$dev_path/$pkg_file" "$dev_backup_dir/" 2>/dev/null || true
                        ((dev_backups++))
                    fi
                done

                # Backup configuration files
                local -a config_files=(".env*" "config.*" "*.config" "docker-compose.*")
                for config_file in "${config_files[@]}"; do
                    find "$dev_path" -maxdepth 1 -name "$config_file" -exec cp {} "$dev_backup_dir/" \; 2>/dev/null || true
                done

                # Create Git status backup if it's a Git repository
                if [[ -d "$dev_path/.git" ]]; then
                    git -C "$dev_path" status --porcelain > "$dev_backup_dir/git_status.txt" 2>/dev/null || true
                    git -C "$dev_path" branch -a > "$dev_backup_dir/git_branches.txt" 2>/dev/null || true
                fi
            fi
        done
    fi

    # Backup global development tool configurations
    local -a global_dev_configs=(
        "/home/$USER/.npm" "/home/$USER/.nvm" "/home/$USER/.pyenv"
        "/home/$USER/.cargo" "/home/$USER/.rustup" "/home/$USER/.rbenv"
        "/home/$USER/.asdf" "/home/$USER/.sdkman" "/home/$USER/.gradle"
        "/home/$USER/.m2" "/home/$USER/.bundle" "/home/$USER/.composer"
    )

    for dev_config in "${global_dev_configs[@]}"; do
        if [[ -e "$dev_config" ]]; then
            local config_name
            config_name=$(basename "$dev_config")
            cp -r "$dev_config" "$dev_dir/global_$config_name" 2>/dev/null || true
            ((dev_backups++))
        fi
    done

    print_success "Development environments backed up: $dev_backups configurations"
    return 0
}

# Backup system state
backup_system_state() {
    local backup_dir="$1"
    local system_dir="$backup_dir/system"

    print_section "Backing Up System State"

    mkdir -p "$system_dir"

    local system_backups=0

    # System information
    uname -a > "$system_dir/uname.txt" 2>/dev/null || true
    ((system_backups++))

    # Disk usage
    df -h > "$system_dir/df.txt" 2>/dev/null || true
    ((system_backups++))

    # Memory usage
    free -h > "$system_dir/free.txt" 2>/dev/null || true
    ((system_backups++))

    # Process list
    ps aux > "$system_dir/ps.txt" 2>/dev/null || true
    ((system_backups++))

    # Service status
    if command_exists systemctl; then
        systemctl list-units --type=service --state=active > "$system_dir/services.txt" 2>/dev/null || true
        ((system_backups++))
    fi

    # Network interfaces
    ip addr show > "$system_dir/interfaces.txt" 2>/dev/null || true
    ((system_backups++))

    # Environment variables
    env > "$system_dir/environment.txt" 2>/dev/null || true
    ((system_backups++))

    # Mount points
    mount > "$system_dir/mount.txt" 2>/dev/null || true
    ((system_backups++))

    # System logs excerpt
    if command_exists journalctl; then
        journalctl --since "1 hour ago" --no-pager > "$system_dir/recent_logs.txt" 2>/dev/null || true
        ((system_backups++))
    fi

    print_success "System state backed up: $system_backups information files"
    return 0
}

# Create backup archive
create_backup_archive() {
    local backup_dir="$1"
    local backup_id
    backup_id=$(basename "$backup_dir")
    local archive_path="${backup_dir}.tar.gz"

    print_section "Creating Backup Archive"

    # Update metadata with final statistics
    local total_files
    total_files=$(find "$backup_dir" -type f | wc -l)
    local total_dirs
    total_dirs=$(find "$backup_dir" -type d | wc -l)
    local backup_size
    backup_size=$(du -sb "$backup_dir" | cut -f1)

    # Update metadata JSON
    if [[ -f "$backup_dir/metadata.json" ]]; then
        # Create temporary file for updated metadata
        local temp_metadata
        temp_metadata=$(mktemp)

        # Use jq to update metadata if available, otherwise use sed
        if command_exists jq; then
            jq --arg files "$total_files" --arg dirs "$total_dirs" --arg size "$backup_size" \
               '.files_count = ($files | tonumber) | .directories_count = ($dirs | tonumber) | .total_size = ($size | tonumber)' \
               "$backup_dir/metadata.json" > "$temp_metadata"
            mv "$temp_metadata" "$backup_dir/metadata.json"
        fi
    fi

    # Create compressed archive
    if tar -czf "$archive_path" -C "$(dirname "$backup_dir")" "$backup_id" 2>/dev/null; then
        local archive_size
        archive_size=$(du -sh "$archive_path" | cut -f1)
        print_success "Backup archive created: $archive_path"
        print_info "Archive size: $archive_size"
        print_info "Files: $total_files, Directories: $total_dirs"

        # Verify archive integrity
        if tar -tzf "$archive_path" >/dev/null 2>&1; then
            print_success "Archive integrity verified"
        else
            print_error "Archive integrity check failed"
            return 1
        fi

        # Remove original directory to save space
        rm -rf "$backup_dir"

        echo "$archive_path"
        return 0
    else
        print_error "Failed to create backup archive"
        return 1
    fi
}

# List available backups
list_backups() {
    local backup_location="${1:-$DEFAULT_BACKUP_LOCATION}"

    print_section "Available Backups"

    if [[ ! -d "$backup_location" ]]; then
        print_info "No backup directory found at: $backup_location"
        return 0
    fi

    local backup_count=0

    for archive in "$backup_location"/*.tar.gz; do
        if [[ -f "$archive" ]]; then
            ((backup_count++))
            local backup_name
            backup_name=$(basename "$archive" .tar.gz)
            local backup_size
            backup_size=$(du -sh "$archive" | cut -f1)
            local backup_date
            backup_date=$(stat -c %y "$archive" 2>/dev/null || stat -f %Sm "$archive" 2>/dev/null)

            print_indented 2 "$(format_status "info" "$backup_name")"
            print_indented 4 "Size: $backup_size, Date: $backup_date"

            # Show metadata if available and verbose
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                if tar -tf "$archive" | grep -q "metadata.json"; then
                    local temp_dir
                    temp_dir=$(mktemp -d)
                    if tar -xf "$archive" -C "$temp_dir" metadata.json 2>/dev/null; then
                        local backup_type
                        backup_type=$(jq -r '.backup_types[]?' "$temp_dir/metadata.json" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
                        if [[ -n "$backup_type" ]]; then
                            print_indented 4 "Types: $backup_type"
                        fi
                    fi
                    rm -rf "$temp_dir"
                fi
            fi
        fi
    done

    if [[ $backup_count -eq 0 ]]; then
        print_info "No backups found"
    else
        print_success "Found $backup_count backup(s)"
    fi

    return 0
}

# Restore from backup
restore_backup() {
    local backup_archive="$1"
    local restore_location="${2:-/tmp/fub_restore_$(date +%Y%m%d_%H%M%S)}"

    print_section "Restoring from Backup"

    if [[ ! -f "$backup_archive" ]]; then
        print_error "Backup archive not found: $backup_archive"
        return 1
    fi

    # Verify archive integrity
    if ! tar -tzf "$backup_archive" >/dev/null 2>&1; then
        print_error "Backup archive is corrupted"
        return 1
    fi

    # Create restore directory
    mkdir -p "$restore_location"

    # Extract backup
    if tar -xzf "$backup_archive" -C "$restore_location" 2>/dev/null; then
        print_success "Backup extracted to: $restore_location"

        # Find the extracted backup directory
        local extracted_dir
        extracted_dir=$(find "$restore_location" -maxdepth 1 -type d -name "fub_backup_*" | head -1)

        if [[ -n "$extracted_dir" ]] && [[ -f "$extracted_dir/metadata.json" ]]; then
            print_info "Backup metadata:"
            if command_exists jq; then
                jq -r 'to_entries[] | "\(.key): \(.value)"' "$extracted_dir/metadata.json" | while IFS= read -r line; do
                    print_indented 2 "$line"
                done
            fi
        fi

        print_info "Manual restoration required for:"
        print_indented 2 "• System configurations (in config/)"
        print_indented 2 "• Package installations (use packages/restore_packages.sh)"
        print_indented 2 "• Development environments (in development/)"
        print_indented 2 "• Review all files before restoring"

        return 0
    else
        print_error "Failed to extract backup archive"
        rm -rf "$restore_location"
        return 1
    fi
}

# Clean up old backups
cleanup_old_backups() {
    local backup_location="${1:-$DEFAULT_BACKUP_LOCATION}"
    local retention_days="${2:-$DEFAULT_BACKUP_RETENTION_DAYS}"

    print_section "Cleaning Up Old Backups"

    if [[ ! -d "$backup_location" ]]; then
        print_info "No backup directory found"
        return 0
    fi

    local removed_count=0

    # Find and remove old backups
    while IFS= read -r -d '' old_backup; do
        local backup_name
        backup_name=$(basename "$old_backup")
        print_indented 2 "$(format_status "warning" "Removing old backup: $backup_name")"
        rm "$old_backup"
        ((removed_count++))
    done < <(find "$backup_location" -name "fub_backup_*.tar.gz" -mtime +$retention_days -print0 2>/dev/null)

    if [[ $removed_count -gt 0 ]]; then
        print_success "Removed $removed_count old backup(s)"
    else
        print_info "No old backups to remove"
    fi

    return 0
}

# Perform comprehensive backup
perform_backup() {
    local backup_type="${1:-full}"
    local backup_id="fub_backup_$(date +%Y%m%d_%H%M%S)_$backup_type"
    local backup_location="${2:-$DEFAULT_BACKUP_LOCATION}"

    print_header "Creating Backup: $backup_type"
    print_info "Backup ID: $backup_id"

    # Check if backup is already in progress
    if [[ -f "$BACKUP_LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$BACKUP_LOCK_FILE" 2>/dev/null || echo "unknown")
        print_error "Backup already in progress (PID: $lock_pid)"
        return 1
    fi

    # Create lock file
    echo $$ > "$BACKUP_LOCK_FILE"
    trap 'rm -f "$BACKUP_LOCK_FILE"' EXIT

    local backup_failed=false
    local backup_dir

    # Initialize backup system
    init_backup_system

    # Create backup directory structure
    backup_dir=$(create_backup_structure "$backup_id" "$backup_location")

    # Perform backup based on type
    case "$backup_type" in
        "full")
            if ! backup_system_configurations "$backup_dir"; then
                backup_failed=true
            fi

            if ! backup_installed_packages "$backup_dir"; then
                backup_failed=true
            fi

            if ! backup_development_environments "$backup_dir"; then
                backup_failed=true
            fi

            if ! backup_system_state "$backup_dir"; then
                backup_failed=true
            fi
            ;;
        "config")
            if ! backup_system_configurations "$backup_dir"; then
                backup_failed=true
            fi
            ;;
        "package")
            if ! backup_installed_packages "$backup_dir"; then
                backup_failed=true
            fi
            ;;
        "development")
            if ! backup_development_environments "$backup_dir"; then
                backup_failed=true
            fi
            ;;
        *)
            print_error "Unknown backup type: $backup_type"
            backup_failed=true
            ;;
    esac

    # Create archive if backup didn't fail
    local archive_path=""
    if [[ "$backup_failed" != "true" ]]; then
        archive_path=$(create_backup_archive "$backup_dir")
        if [[ $? -ne 0 ]]; then
            backup_failed=true
        fi
    fi

    # Clean up on failure
    if [[ "$backup_failed" == "true" ]]; then
        print_error "Backup failed"
        if [[ -d "$backup_dir" ]]; then
            rm -rf "$backup_dir"
        fi
        return 1
    else
        print_success "Backup completed successfully"
        if [[ -n "$archive_path" ]]; then
            print_info "Backup location: $archive_path"
        fi

        # Clean up old backups
        cleanup_old_backups "$backup_location"

        return 0
    fi
}

# Show backup system help
show_backup_help() {
    cat << EOF
${BOLD}${CYAN}Backup System Module${RESET}
${ITALIC}Comprehensive backup creation and restoration system${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source backup-system.sh${RESET}
    ${GREEN}perform_backup${RESET} [${YELLOW}TYPE${RESET}] [${YELLOW}LOCATION${RESET}]

${BOLD}Functions:${RESET}
    ${YELLOW}backup_system_configurations${RESET}    Backup important system configurations
    ${YELLOW}backup_installed_packages${RESET}       Backup package installation lists
    ${YELLOW}backup_development_environments${RESET}  Backup development tool configurations
    ${YELLOW}backup_system_state${RESET}            Backup current system state
    ${YELLOW}create_backup_archive${RESET}           Create compressed backup archive
    ${YELLOW}list_backups${RESET}                    List available backups
    ${YELLOW}restore_backup${RESET}                  Restore from backup archive
    ${YELLOW}cleanup_old_backups${RESET}             Remove old backups
    ${YELLOW}perform_backup${RESET}                  Create comprehensive backup

${BOLD}Backup Types:${RESET}
    ${YELLOW}full${RESET}         Complete backup (default)
    ${YELLOW}config${RESET}       System configurations only
    ${YELLOW}package${RESET}      Package lists and sources
    ${YELLOW}development${RESET}  Development environments
    ${YELLOW}system${RESET}       System state information

${BOLD}Backup Contents:${RESET}
    • System configuration files
    • Package manager configurations
    • Development environment settings
    • System state snapshots
    • Service status information
    • Metadata for restoration

${BOLD}Default Settings:${RESET}
    • Backup location: $DEFAULT_BACKUP_LOCATION
    • Retention period: $DEFAULT_BACKUP_RETENTION_DAYS days
    • Archive format: tar.gz
    • Lock file: $BACKUP_LOCK_FILE

${BOLD}Examples:${RESET}
    perform_backup full                    # Create full backup
    perform_backup config /custom/path     # Create config backup in custom location
    list_backups                          # Show available backups
    restore_backup /path/to/backup.tar.gz # Restore from backup

EOF
}

# Export functions for use in other scripts
export -f init_backup_system create_backup_structure
export -f backup_system_configurations backup_installed_packages
export -f backup_development_environments backup_system_state
export -f create_backup_archive list_backups restore_backup cleanup_old_backups
export -f perform_backup show_backup_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    case "${1:-full}" in
        "list")
            list_backups
            ;;
        "restore")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 restore <backup_archive> [restore_location]"
                exit 1
            fi
            restore_backup "$2" "${3:-}"
            ;;
        "cleanup")
            cleanup_old_backups "${2:-$DEFAULT_BACKUP_LOCATION}" "${3:-$DEFAULT_BACKUP_RETENTION_DAYS}"
            ;;
        *)
            perform_backup "${1:-full}" "${2:-$DEFAULT_BACKUP_LOCATION}"
            ;;
    esac
fi