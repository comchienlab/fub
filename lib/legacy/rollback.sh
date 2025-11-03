#!/usr/bin/env bash

# FUB Rollback System
# Provides rollback procedures for failed upgrades and system state restoration

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/ui.sh"
source "${FUB_ROOT_DIR}/lib/legacy/config-migration.sh"

# Rollback constants
readonly FUB_ROLLBACK_DIR="${FUB_ROLLBACK_DIR:-${HOME}/.local/share/fub/rollbacks}"
readonly FUB_ROLLBACK_LOG="${FUB_ROLLBACK_LOG:-${HOME}/.local/share/fub/logs/rollback.log}"
readonly FUB_MAX_ROLLBACKS="${FUB_MAX_ROLLBACKS:-10}"

# Rollback state
FUB_ROLLBACK_ACTIVE=false
FUB_ROLLBACK_ID=""
FUB_ROLLBACK_REASON=""

# Initialize rollback system
init_rollback_system() {
    log_debug "Initializing rollback system"

    # Create rollback directories
    mkdir -p "$FUB_ROLLBACK_DIR"
    mkdir -p "$(dirname "$FUB_ROLLBACK_LOG")"

    # Initialize rollback log
    {
        echo "=== FUB Rollback System Log ==="
        echo "Initialized at: $(date)"
        echo "FUB version: ${FUB_VERSION:-unknown}"
        echo ""
    } >> "$FUB_ROLLBACK_LOG"

    # Set up signal handlers for emergency rollback
    trap 'emergency_rollback "Signal received"' TERM INT QUIT

    log_debug "Rollback system initialized"
}

# Create rollback point
create_rollback_point() {
    local rollback_id="${1:-auto-$(date +%Y%m%d_%H%M%S)}"
    local description="${2:-Automatic rollback point}"

    log_info "Creating rollback point: $rollback_id"
    log_info "Description: $description"

    local rollback_dir="${FUB_ROLLBACK_DIR}/${rollback_id}"
    mkdir -p "$rollback_dir"

    # Log rollback creation
    {
        echo "Rollback point created: $(date)"
        echo "ID: $rollback_id"
        echo "Description: $description"
        echo "Directory: $rollback_dir"
        echo ""
    } >> "$FUB_ROLLBACK_LOG"

    # Backup critical system components
    backup_configuration_files "$rollback_dir"
    backup_package_state "$rollback_dir"
    backup_service_state "$rollback_dir"
    backup_fub_installation "$rollback_dir"
    backup_user_data "$rollback_dir"

    # Create rollback metadata
    create_rollback_metadata "$rollback_dir" "$rollback_id" "$description"

    # Cleanup old rollbacks
    cleanup_old_rollbacks

    log_info "Rollback point created successfully: $rollback_id"
    echo "$rollback_id"
}

# Backup configuration files
backup_configuration_files() {
    local rollback_dir="$1"
    local config_backup_dir="${rollback_dir}/config"

    mkdir -p "$config_backup_dir"

    log_debug "Backing up configuration files"

    local -a config_files=(
        "${HOME}/.config/fub/config.yaml"
        "${HOME}/.config/fub/"
        "/etc/fub/config.yaml"
        "${HOME}/.fubrc"
        "${HOME}/.fub.conf"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -e "$config_file" ]]; then
            local backup_path="${config_backup_dir}$(dirname "$config_file")"
            mkdir -p "$backup_path"

            if cp -r "$config_file" "$backup_path/" 2>/dev/null; then
                log_debug "Backed up: $config_file"
            else
                log_debug "Failed to backup: $config_file"
            fi
        fi
    done

    # Backup systemd timers if they exist
    if systemctl list-timers | grep -q "fub"; then
        mkdir -p "${config_backup_dir}/systemd"
        systemctl list-timers --all | grep fub > "${config_backup_dir}/systemd/timers.list" 2>/dev/null || true

        # Export timer configurations
        local -a fub_timers
        readarray -t fub_timers < <(systemctl list-timers --all | awk '/fub/ {print $1}')
        for timer in "${fub_timers[@]}"; do
            if [[ -n "$timer" ]]; then
                systemctl cat "$timer" > "${config_backup_dir}/systemd/${timer}.service" 2>/dev/null || true
                systemctl cat "${timer}.timer" > "${config_backup_dir}/systemd/${timer}.timer" 2>/dev/null || true
            fi
        done
    fi
}

# Backup package state
backup_package_state() {
    local rollback_dir="$1"
    local package_backup_dir="${rollback_dir}/packages"

    mkdir -p "$package_backup_dir"

    log_debug "Backing up package state"

    # APT package state
    if command_exists apt; then
        dpkg --get-selections > "${package_backup_dir}/dpkg-selections.txt" 2>/dev/null || true
        apt-mark showhold > "${package_backup_dir}/apt-hold.txt" 2>/dev/null || true
        apt-mark showmanual > "${package_backup_dir}/apt-manual.txt" 2>/dev/null || true

        # List installed FUB package version
        apt-cache policy fub > "${package_backup_dir}/fub-package-info.txt" 2>/dev/null || true
    fi

    # Snap packages
    if command_exists snap; then
        snap list > "${package_backup_dir}/snap-list.txt" 2>/dev/null || true
    fi

    # Flatpak packages
    if command_exists flatpak; then
        flatpak list --columns=application,branch,arch,origin > "${package_backup_dir}/flatpak-list.txt" 2>/dev/null || true
    fi

    # Package repositories configuration
    if [[ -d /etc/apt ]]; then
        tar -czf "${package_backup_dir}/apt-sources.tar.gz" -C /etc/apt sources.list* sources.list.d/ 2>/dev/null || true
    fi
}

# Backup service state
backup_service_state() {
    local rollback_dir="$1"
    local service_backup_dir="${rollback_dir}/services"

    mkdir -p "$service_backup_dir"

    log_debug "Backing up service state"

    # System service states
    systemctl list-unit-files --type=service --state=enabled,disabled > "${service_backup_dir}/service-files.txt" 2>/dev/null || true
    systemctl list-units --type=service --state=running,failed > "${service_backup_dir}/active-services.txt" 2>/dev/null || true

    # FUB-specific services
    local -a fub_services=("fub-cleanup" "fub-monitoring" "fub-scheduler")
    for service in "${fub_services[@]}"; do
        if systemctl list-unit-files | grep -q "${service}"; then
            systemctl is-enabled "$service" > "${service_backup_dir}/${service}-enabled.txt" 2>/dev/null || true
            systemctl is-active "$service" > "${service_backup_dir}/${service}-active.txt" 2>/dev/null || true
        fi
    done
}

# Backup FUB installation
backup_fub_installation() {
    local rollback_dir="$1"
    local fub_backup_dir="${rollback_dir}/fub-installation"

    mkdir -p "$fub_backup_dir"

    log_debug "Backing up FUB installation"

    # Backup installed files
    local -a fub_paths=(
        "/usr/bin/fub"
        "/usr/local/bin/fub"
        "/etc/fub"
        "/usr/share/fub"
        "/usr/share/doc/fub"
        "/usr/share/man/man1/fub.1.gz"
    )

    for path in "${fub_paths[@]}"; do
        if [[ -e "$path" ]]; then
            if tar -czf "${fub_backup_dir}/$(basename "$path").tar.gz" -C "$(dirname "$path")" "$(basename "$path")" 2>/dev/null; then
                log_debug "Backed up FUB component: $path"
            fi
        fi
    done

    # Current FUB version and installation method
    if command_exists fub; then
        fub --version > "${fub_backup_dir}/version.txt" 2>/dev/null || true
    fi

    # Installation method detection
    if dpkg -l | grep -q "fub"; then
        echo "dpkg" > "${fub_backup_dir}/install-method.txt"
    elif command_exists snap && snap list | grep -q "fub"; then
        echo "snap" > "${fub_backup_dir}/install-method.txt"
    else
        echo "manual/source" > "${fub_backup_dir}/install-method.txt"
    fi
}

# Backup user data
backup_user_data() {
    local rollback_dir="$1"
    local user_backup_dir="${rollback_dir}/user-data"

    mkdir -p "$user_backup_dir"

    log_debug "Backing up user data"

    # FUB user directories
    local -a user_dirs=(
        "${HOME}/.local/share/fub"
        "${HOME}/.cache/fub"
        "${HOME}/.config/fub"
    )

    for dir in "${user_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local backup_name
            backup_name=$(basename "$dir")
            if tar -czf "${user_backup_dir}/${backup_name}.tar.gz" -C "$(dirname "$dir")" "$(basename "$dir")" 2>/dev/null; then
                log_debug "Backed up user directory: $dir"
            fi
        fi
    done

    # FUB history and logs
    if [[ -d "${HOME}/.local/share/fub/logs" ]]; then
        cp -r "${HOME}/.local/share/fub/logs" "${user_backup_dir}/" 2>/dev/null || true
    fi

    # FUB scheduler data
    if [[ -d "${HOME}/.local/share/fub/scheduler" ]]; then
        cp -r "${HOME}/.local/share/fub/scheduler" "${user_backup_dir}/" 2>/dev/null || true
    fi
}

# Create rollback metadata
create_rollback_metadata() {
    local rollback_dir="$1"
    local rollback_id="$2"
    local description="$3"

    local metadata_file="${rollback_dir}/rollback-metadata.yaml"

    log_debug "Creating rollback metadata: $metadata_file"

    cat > "$metadata_file" << EOF
# FUB Rollback Metadata
# Generated on: $(date)

rollback:
  id: "$rollback_id"
  description: "$description"
  created: "$(date -Iseconds)"
  fub_version: "${FUB_VERSION:-unknown}"

system:
  hostname: "$(hostname)"
  ubuntu_version: "$(lsb_release -rs 2>/dev/null || echo 'unknown')"
  kernel_version: "$(uname -r)"
  architecture: "$(uname -m)"

rollback_contents:
  - configuration_files
  - package_state
  - service_state
  - fub_installation
  - user_data

restoration_commands:
  configuration: "restore_configuration_files"
  packages: "restore_package_state"
  services: "restore_service_state"
  installation: "restore_fub_installation"
  user_data: "restore_user_data"

warnings:
  - "Rollback will undo all changes made after this point"
  - "System restart may be required after rollback"
  - "Some user data may be lost if created after rollback point"
  - "Test rollback in non-production environment first"

EOF

    log_debug "Rollback metadata created"
}

# Perform rollback
perform_rollback() {
    local rollback_id="$1"
    local reason="${2:-Manual rollback request}"

    log_info "Starting rollback: $rollback_id"
    log_info "Reason: $reason"

    local rollback_dir="${FUB_ROLLBACK_DIR}/${rollback_id}"

    if [[ ! -d "$rollback_dir" ]]; then
        log_error "Rollback point not found: $rollback_id"
        return 1
    fi

    # Check if rollback metadata exists
    local metadata_file="${rollback_dir}/rollback-metadata.yaml"
    if [[ ! -f "$metadata_file" ]]; then
        log_error "Rollback metadata not found: $metadata_file"
        return 1
    fi

    # Log rollback start
    {
        echo "Rollback started: $(date)"
        echo "Rollback ID: $rollback_id"
        echo "Reason: $reason"
        echo "Rollback directory: $rollback_dir"
        echo ""
    } >> "$FUB_ROLLBACK_LOG"

    # Set rollback state
    FUB_ROLLBACK_ACTIVE=true
    FUB_ROLLBACK_ID="$rollback_id"
    FUB_ROLLBACK_REASON="$reason"

    # Create pre-rollback backup
    local pre_rollback_id="pre-rollback-$(date +%Y%m%d_%H%M%S)"
    create_rollback_point "$pre_rollback_id" "Automatic backup before rollback: $rollback_id"

    # Perform rollback steps
    local rollback_successful=true

    # 1. Stop FUB services
    log_info "Stopping FUB services..."
    if ! stop_fub_services; then
        log_warning "Failed to stop some FUB services"
    fi

    # 2. Restore FUB installation
    log_info "Restoring FUB installation..."
    if ! restore_fub_installation "$rollback_dir"; then
        log_error "Failed to restore FUB installation"
        rollback_successful=false
    fi

    # 3. Restore configuration files
    log_info "Restoring configuration files..."
    if ! restore_configuration_files "$rollback_dir"; then
        log_error "Failed to restore configuration files"
        rollback_successful=false
    fi

    # 4. Restore package state
    log_info "Restoring package state..."
    if ! restore_package_state "$rollback_dir"; then
        log_error "Failed to restore package state"
        rollback_successful=false
    fi

    # 5. Restore service state
    log_info "Restoring service state..."
    if ! restore_service_state "$rollback_dir"; then
        log_error "Failed to restore service state"
        rollback_successful=false
    fi

    # 6. Restore user data
    log_info "Restoring user data..."
    if ! restore_user_data "$rollback_dir"; then
        log_error "Failed to restore user data"
        rollback_successful=false
    fi

    # 7. Restart services if rollback was successful
    if [[ "$rollback_successful" == true ]]; then
        log_info "Restarting services..."
        restart_fub_services || true
    fi

    # Log rollback completion
    if [[ "$rollback_successful" == true ]]; then
        log_success "Rollback completed successfully: $rollback_id"
        {
            echo "Rollback completed successfully: $(date)"
            echo "Rollback ID: $rollback_id"
            echo "Reason: $reason"
            echo ""
        } >> "$FUB_ROLLBACK_LOG"
        return 0
    else
        log_error "Rollback failed: $rollback_id"
        {
            echo "Rollback failed: $(date)"
            echo "Rollback ID: $rollback_id"
            echo "Reason: $reason"
            echo "Pre-rollback backup: $pre_rollback_id"
            echo ""
        } >> "$FUB_ROLLBACK_LOG"
        return 1
    fi
}

# Restore FUB installation
restore_fub_installation() {
    local rollback_dir="$1"
    local fub_backup_dir="${rollback_dir}/fub-installation"

    if [[ ! -d "$fub_backup_dir" ]]; then
        log_warning "FUB installation backup not found"
        return 1
    fi

    log_debug "Restoring FUB installation from: $fub_backup_dir"

    # Check installation method
    local install_method="manual"
    if [[ -f "${fub_backup_dir}/install-method.txt" ]]; then
        install_method=$(cat "${fub_backup_dir}/install-method.txt")
    fi

    case "$install_method" in
        "dpkg")
            restore_dpkg_installation "$fub_backup_dir"
            ;;
        "snap")
            restore_snap_installation "$fub_backup_dir"
            ;;
        "manual/source")
            restore_manual_installation "$fub_backup_dir"
            ;;
        *)
            log_warning "Unknown installation method: $install_method"
            restore_manual_installation "$fub_backup_dir"
            ;;
    esac
}

# Restore DPKG installation
restore_dpkg_installation() {
    local backup_dir="$1"

    log_debug "Restoring DPKG installation"

    # Get package version from backup
    if [[ -f "${backup_dir}/fub-package-info.txt" ]]; then
        local package_version
        package_version=$(grep "Installed:" "${backup_dir}/fub-package-info.txt" | awk '{print $2}' || echo "")

        if [[ -n "$package_version" ]]; then
            log_info "Restoring FUB package version: $package_version"

            # Try to install specific version
            if ! sudo apt-get install "fub=$package_version" -y 2>/dev/null; then
                # If specific version not available, try latest
                log_warning "Specific version not available, installing latest"
                sudo apt-get install fub -y
            fi
        else
            sudo apt-get install fub -y
        fi
    else
        sudo apt-get install fub -y
    fi
}

# Restore Snap installation
restore_snap_installation() {
    local backup_dir="$1"

    log_debug "Restoring Snap installation"

    # Remove current snap if installed
    if snap list | grep -q "fub"; then
        sudo snap remove fub 2>/dev/null || true
    fi

    # Reinstall from snap store
    sudo snap install fub 2>/dev/null || true
}

# Restore manual/source installation
restore_manual_installation() {
    local backup_dir="$1"

    log_debug "Restoring manual/source installation"

    # Restore backed up files if they exist
    local -a backup_files=(
        "usr-bin-fub.tar.gz"
        "usr-local-bin-fub.tar.gz"
        "etc-fub.tar.gz"
        "usr-share-fub.tar.gz"
    )

    for backup_file in "${backup_files[@]}"; do
        if [[ -f "${backup_dir}/$backup_file" ]]; then
            local target_path
            case "$backup_file" in
                "usr-bin-fub.tar.gz") target_path="/usr/bin/" ;;
                "usr-local-bin-fub.tar.gz") target_path="/usr/local/bin/" ;;
                "etc-fub.tar.gz") target_path="/etc/" ;;
                "usr-share-fub.tar.gz") target_path="/usr/share/" ;;
            esac

            if [[ -n "$target_path" ]]; then
                log_debug "Restoring: $backup_file to $target_path"
                sudo tar -xzf "${backup_dir}/$backup_file" -C "$target_path" 2>/dev/null || true
            fi
        fi
    done
}

# Restore configuration files
restore_configuration_files() {
    local rollback_dir="$1"
    local config_backup_dir="${rollback_dir}/config"

    if [[ ! -d "$config_backup_dir" ]]; then
        log_warning "Configuration backup not found"
        return 1
    fi

    log_debug "Restoring configuration files from: $config_backup_dir"

    # Restore user configurations
    if [[ -d "${config_backup_dir}/home" ]]; then
        local home_config_dir="${config_backup_dir}/home/${USER}/.config/fub"
        if [[ -d "$home_config_dir" ]]; then
            # Backup current config first
            if [[ -d "${HOME}/.config/fub" ]]; then
                mv "${HOME}/.config/fub" "${HOME}/.config/fub.backup.$(date +%Y%m%d_%H%M%S)"
            fi

            # Restore backup
            cp -r "$home_config_dir" "${HOME}/.config/"
            log_info "Restored user configuration"
        fi
    fi

    # Restore system configurations
    if [[ -d "${config_backup_dir}/etc" ]]; then
        local etc_fub_dir="${config_backup_dir}/etc/fub"
        if [[ -d "$etc_fub_dir" ]]; then
            sudo cp -r "$etc_fub_dir"/* "/etc/fub/" 2>/dev/null || true
            log_info "Restored system configuration"
        fi
    fi

    # Restore systemd timers
    if [[ -d "${config_backup_dir}/systemd" ]]; then
        restore_systemd_timers "${config_backup_dir}/systemd"
    fi
}

# Restore systemd timers
restore_systemd_timers() {
    local systemd_backup_dir="$1"

    log_debug "Restoring systemd timers"

    # Stop and disable existing FUB timers
    local -a fub_timers
    readarray -t fub_timers < <(systemctl list-timers --all | awk '/fub/ {print $1}')
    for timer in "${fub_timers[@]}"; do
        if [[ -n "$timer" ]]; then
            sudo systemctl stop "$timer" 2>/dev/null || true
            sudo systemctl disable "$timer" 2>/dev/null || true
        fi
    done

    # Restore timer configurations
    for timer_file in "${systemd_backup_dir}"/*.timer; do
        if [[ -f "$timer_file" ]]; then
            local timer_name
            timer_name=$(basename "$timer_file")
            sudo cp "$timer_file" "/etc/systemd/system/"
            sudo systemctl daemon-reload
            sudo systemctl enable "$timer_name" 2>/dev/null || true
            log_info "Restored timer: $timer_name"
        fi
    done
}

# Restore package state
restore_package_state() {
    local rollback_dir="$1"
    local package_backup_dir="${rollback_dir}/packages"

    if [[ ! -d "$package_backup_dir" ]]; then
        log_warning "Package state backup not found"
        return 1
    fi

    log_debug "Restoring package state from: $package_backup_dir"

    # Restore APT package selections
    if [[ -f "${package_backup_dir}/dpkg-selections.txt" ]]; then
        log_info "Restoring APT package selections"
        sudo dpkg --set-selections < "${package_backup_dir}/dpkg-selections.txt" 2>/dev/null || true
        sudo apt-get dselect-upgrade -y 2>/dev/null || true
    fi

    # Restore package holds
    if [[ -f "${package_backup_dir}/apt-hold.txt" ]]; then
        while IFS= read -r package; do
            if [[ -n "$package" ]]; then
                sudo apt-mark hold "$package" 2>/dev/null || true
            fi
        done < "${package_backup_dir}/apt-hold.txt"
    fi

    # Restore APT sources
    if [[ -f "${package_backup_dir}/apt-sources.tar.gz" ]]; then
        log_info "Restoring APT sources"
        sudo tar -xzf "${package_backup_dir}/apt-sources.tar.gz" -C /etc/apt/ 2>/dev/null || true
        sudo apt-get update 2>/dev/null || true
    fi
}

# Restore service state
restore_service_state() {
    local rollback_dir="$1"
    local service_backup_dir="${rollback_dir}/services"

    if [[ ! -d "$service_backup_dir" ]]; then
        log_warning "Service state backup not found"
        return 1
    fi

    log_debug "Restoring service state from: $service_backup_dir"

    # Restore FUB service states
    local -a fub_services=("fub-cleanup" "fub-monitoring" "fub-scheduler")
    for service in "${fub_services[@]}"; do
        local enabled_file="${service_backup_dir}/${service}-enabled.txt"
        local active_file="${service_backup_dir}/${service}-active.txt"

        if [[ -f "$enabled_file" ]]; then
            local enabled_state
            enabled_state=$(cat "$enabled_file")
            if [[ "$enabled_state" == "enabled" ]]; then
                sudo systemctl enable "$service" 2>/dev/null || true
            elif [[ "$enabled_state" == "disabled" ]]; then
                sudo systemctl disable "$service" 2>/dev/null || true
            fi
        fi

        if [[ -f "$active_file" ]]; then
            local active_state
            active_state=$(cat "$active_file")
            if [[ "$active_state" == "active" ]]; then
                sudo systemctl start "$service" 2>/dev/null || true
            elif [[ "$active_state" == "inactive" ]]; then
                sudo systemctl stop "$service" 2>/dev/null || true
            fi
        fi
    done
}

# Restore user data
restore_user_data() {
    local rollback_dir="$1"
    local user_backup_dir="${rollback_dir}/user-data"

    if [[ ! -d "$user_backup_dir" ]]; then
        log_warning "User data backup not found"
        return 1
    fi

    log_debug "Restoring user data from: $user_backup_dir"

    # Restore user directories
    local -a backup_archives=(
        "fub.tar.gz"
        "cache-fub.tar.gz"
        "config-fub.tar.gz"
    )

    for archive in "${backup_archives[@]}"; do
        if [[ -f "${user_backup_dir}/$archive" ]]; then
            local target_dir="${HOME}"
            case "$archive" in
                "cache-fub.tar.gz") target_dir="${HOME}/.cache" ;;
                "config-fub.tar.gz") target_dir="${HOME}/.config" ;;
            esac

            mkdir -p "$target_dir"
            tar -xzf "${user_backup_dir}/$archive" -C "$target_dir" 2>/dev/null || true
            log_info "Restored user data: $archive"
        fi
    done

    # Restore logs and scheduler data if they exist as directories
    if [[ -d "${user_backup_dir}/logs" ]]; then
        cp -r "${user_backup_dir}/logs" "${HOME}/.local/share/fub/" 2>/dev/null || true
    fi

    if [[ -d "${user_backup_dir}/scheduler" ]]; then
        cp -r "${user_backup_dir}/scheduler" "${HOME}/.local/share/fub/" 2>/dev/null || true
    fi
}

# Stop FUB services
stop_fub_services() {
    log_debug "Stopping FUB services"

    local -a fub_services=("fub-cleanup" "fub-monitoring" "fub-scheduler" "fub-profile")
    for service in "${fub_services[@]}"; do
        if systemctl list-unit-files | grep -q "${service}"; then
            sudo systemctl stop "$service" 2>/dev/null || true
        fi
    done

    # Stop FUB timers
    local -a fub_timers
    readarray -t fub_timers < <(systemctl list-timers --all | awk '/fub/ {print $1}')
    for timer in "${fub_timers[@]}"; do
        if [[ -n "$timer" ]]; then
            sudo systemctl stop "$timer" 2>/dev/null || true
        fi
    done
}

# Restart FUB services
restart_fub_services() {
    log_debug "Restarting FUB services"

    local -a fub_services=("fub-cleanup" "fub-monitoring" "fub-scheduler" "fub-profile")
    for service in "${fub_services[@]}"; do
        if systemctl list-unit-files | grep -q "${service}"; then
            sudo systemctl restart "$service" 2>/dev/null || true
        fi
    done
}

# Emergency rollback
emergency_rollback() {
    local reason="$1"

    if [[ "$FUB_ROLLBACK_ACTIVE" != "true" ]]; then
        log_warning "Emergency rollback triggered: $reason"

        # Find the most recent rollback point
        local latest_rollback
        latest_rollback=$(find "$FUB_ROLLBACK_DIR" -maxdepth 1 -type d -name "auto-*" | sort -r | head -1)

        if [[ -n "$latest_rollback" ]]; then
            local rollback_id
            rollback_id=$(basename "$latest_rollback")
            perform_rollback "$rollback_id" "Emergency rollback: $reason"
        else
            log_error "No rollback points available for emergency rollback"
        fi
    fi
}

# Cleanup old rollbacks
cleanup_old_rollbacks() {
    log_debug "Cleaning up old rollbacks"

    # List rollback directories by date (oldest first)
    local -a rollback_dirs
    readarray -t rollback_dirs < <(find "$FUB_ROLLBACK_DIR" -maxdepth 1 -type d -name "*" ! -name "$(basename "$FUB_ROLLBACK_DIR")" | sort)

    if [[ ${#rollback_dirs[@]} -gt $FUB_MAX_ROLLBACKS ]]; then
        local remove_count=$((${#rollback_dirs[@]} - FUB_MAX_ROLLBACKS))

        for ((i=0; i<remove_count; i++)); do
            local rollback_dir="${rollback_dirs[$i]}"
            log_info "Removing old rollback: $(basename "$rollback_dir")"
            rm -rf "$rollback_dir" 2>/dev/null || true
        done
    fi
}

# List available rollbacks
list_rollbacks() {
    log_info "Available rollback points:"

    if [[ ! -d "$FUB_ROLLBACK_DIR" ]]; then
        log_info "No rollback directory found"
        return 1
    fi

    local rollback_count=0
    for rollback_dir in "$FUB_ROLLBACK_DIR"/*; do
        if [[ -d "$rollback_dir" ]] && [[ "$(basename "$rollback_dir")" != "$(basename "$FUB_ROLLBACK_DIR")" ]]; then
            local rollback_id
            rollback_id=$(basename "$rollback_dir")
            local metadata_file="${rollback_dir}/rollback-metadata.yaml"

            if [[ -f "$metadata_file" ]]; then
                # Extract information from metadata
                local description created fub_version
                description=$(grep "description:" "$metadata_file" | cut -d'"' -f2)
                created=$(grep "created:" "$metadata_file" | cut -d'"' -f2)
                fub_version=$(grep "fub_version:" "$metadata_file" | cut -d'"' -f2)

                echo "  $rollback_id"
                echo "    Description: $description"
                echo "    Created: $created"
                echo "    FUB Version: $fub_version"
                echo ""
            else
                echo "  $rollback_id"
                echo "    No metadata available"
                echo ""
            fi

            ((rollback_count++))
        fi
    done

    if [[ $rollback_count -eq 0 ]]; then
        log_info "No rollback points found"
        return 1
    else
        log_info "Found $rollback_count rollback points"
        return 0
    fi
}

# Export rollback functions
export -f init_rollback_system create_rollback_point perform_rollback
export -f stop_fub_services restart_fub_services emergency_rollback
export -f backup_configuration_files backup_package_state backup_service_state
export -f backup_fub_installation backup_user_data create_rollback_metadata
export -f restore_configuration_files restore_package_state restore_service_state
export -f restore_fub_installation restore_user_data restore_dpkg_installation
export -f restore_snap_installation restore_manual_installation restore_systemd_timers
export -f cleanup_old_rollbacks list_rollbacks

# Initialize rollback system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_rollback_system
    log_debug "FUB rollback system module loaded"
fi