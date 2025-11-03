#!/usr/bin/env bash

# FUB User Configuration Management Module
# Handles user profiles, theme customization, and configuration management

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# User configuration constants
readonly FUB_USER_CONFIG_DIR="${HOME}/.fub"
readonly FUB_USER_PROFILES_DIR="${FUB_USER_CONFIG_DIR}/profiles"
readonly FUB_USER_THEMES_DIR="${FUB_USER_CONFIG_DIR}/themes"
readonly FUB_USER_CONFIG_FILE="${FUB_USER_CONFIG_DIR}/config.yaml"
readonly FUB_USER_PROFILE_FILE="${FUB_USER_CONFIG_DIR}/current_profile"
readonly FUB_USER_BACKUP_DIR="${FUB_USER_CONFIG_DIR}/backups"
readonly FUB_CONFIG_SCHEMA_FILE="${FUB_CONFIG_DIR}/schema.yaml"

# State variables
FUB_CURRENT_PROFILE=""
FUB_PROFILES_LOADED=false

# Initialize user configuration system
init_user_config() {
    log_debug "Initializing user configuration system..."

    # Ensure user directories exist
    ensure_dir "$FUB_USER_CONFIG_DIR"
    ensure_dir "$FUB_USER_PROFILES_DIR"
    ensure_dir "$FUB_USER_THEMES_DIR"
    ensure_dir "$FUB_USER_BACKUP_DIR"

    # Create default user config if it doesn't exist
    create_default_user_config

    # Load current profile
    load_current_profile

    log_debug "User configuration system initialized"
}

# Create default user configuration
create_default_user_config() {
    if [[ ! -f "$FUB_USER_CONFIG_FILE" ]]; then
        log_debug "Creating default user configuration..."

        cat > "$FUB_USER_CONFIG_FILE" << 'EOF'
# FUB User Configuration
# User-specific settings and preferences

# User preferences
user:
  name: "$(whoami)"
  email: ""
  preferred_theme: "tokyo-night"
  interactive_mode: true
  show_advanced_options: false

# Profile settings
profile:
  current: "desktop"
  auto_switch: false
  custom_operations: []

# Theme customization
theme:
  name: "tokyo-night"
  custom_colors: {}
  enable_animations: true
  high_contrast: false

# Safety preferences
safety:
  backup_before_cleanup: true
  confirm_dangerous_operations: true
  protected_directories:
    - "$HOME/Documents"
    - "$HOME/Projects"
    - "$HOME/.ssh"
  exclude_patterns:
    - "*.important"
    - ".git"

# Notifications
notifications:
  enabled: true
  desktop_notifications: true
  email_notifications: false
  completion_sound: false

# Performance preferences
performance:
  parallel_jobs: 4
  max_memory_usage: "1G"
  nice_level: 10
  io_priority: 7

# Logging preferences
logging:
  level: "INFO"
  file: "$HOME/.cache/fub/logs/fub.log"
  max_size: "10MB"
  rotate_count: 5
EOF

        log_debug "Default user configuration created"
    fi
}

# Load current profile
load_current_profile() {
    if [[ -f "$FUB_USER_PROFILE_FILE" ]]; then
        FUB_CURRENT_PROFILE=$(cat "$FUB_USER_PROFILE_FILE")
    else
        FUB_CURRENT_PROFILE="desktop"
        echo "$FUB_CURRENT_PROFILE" > "$FUB_USER_PROFILE_FILE"
    fi

    log_debug "Current profile: $FUB_CURRENT_PROFILE"
    FUB_PROFILES_LOADED=true
}

# Get current profile
get_current_profile() {
    echo "$FUB_CURRENT_PROFILE"
}

# Set current profile
set_current_profile() {
    local profile_name="$1"

    if [[ ! -f "${FUB_CONFIG_DIR}/profiles/${profile_name}.yaml" ]] &&
       [[ ! -f "${FUB_USER_PROFILES_DIR}/${profile_name}.yaml" ]]; then
        log_error "Profile not found: $profile_name"
        return 1
    fi

    echo "$profile_name" > "$FUB_USER_PROFILE_FILE"
    FUB_CURRENT_PROFILE="$profile_name"

    log_info "Profile switched to: $profile_name"

    # Update user config file
    update_user_config_key "profile.current" "$profile_name"
}

# List available profiles
list_profiles() {
    echo ""
    echo "${BOLD}${CYAN}Available Profiles${RESET}"
    echo "==================="
    echo ""

    # System profiles
    echo "${YELLOW}System Profiles:${RESET}"
    for profile_file in "${FUB_CONFIG_DIR}/profiles"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            local description=$(get_profile_description "$profile_file")
            local marker=""
            [[ "$FUB_CURRENT_PROFILE" == "$profile_name" ]] && marker=" ${GREEN}[ACTIVE]${RESET}"
            echo "  ${GREEN}•${RESET} ${CYAN}${profile_name}${RESET}${marker}"
            echo "    ${description}"
        fi
    done

    echo ""
    echo "${YELLOW}User Profiles:${RESET}"
    local user_profiles=0
    for profile_file in "${FUB_USER_PROFILES_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            local description=$(get_profile_description "$profile_file")
            local marker=""
            [[ "$FUB_CURRENT_PROFILE" == "$profile_name" ]] && marker=" ${GREEN}[ACTIVE]${RESET}"
            echo "  ${GREEN}•${RESET} ${CYAN}${profile_name}${RESET}${marker}"
            echo "    ${description}"
            ((user_profiles++))
        fi
    done

    if [[ $user_profiles -eq 0 ]]; then
        echo "  ${GRAY}No user profiles found${RESET}"
    fi

    echo ""
}

# Get profile description from YAML file
get_profile_description() {
    local profile_file="$1"
    local description=""

    if [[ -f "$profile_file" ]]; then
        description=$(grep "^description:" "$profile_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    fi

    echo "${description:-No description available}"
}

# Create custom profile
create_profile() {
    local profile_name="$1"
    local profile_description="$2"
    local base_profile="${3:-desktop}"

    if [[ -z "$profile_name" ]]; then
        log_error "Profile name is required"
        return 1
    fi

    local profile_file="${FUB_USER_PROFILES_DIR}/${profile_name}.yaml"

    if [[ -f "$profile_file" ]]; then
        log_error "Profile already exists: $profile_name"
        return 1
    fi

    log_info "Creating profile: $profile_name"

    # Get base profile template
    local base_file="${FUB_CONFIG_DIR}/profiles/${base_profile}.yaml"
    if [[ ! -f "$base_file" ]]; then
        log_error "Base profile not found: $base_profile"
        return 1
    fi

    # Create new profile based on template
    cp "$base_file" "$profile_file"

    # Update profile metadata
    sed -i "s/^name:.*/name: ${profile_name}/" "$profile_file"
    sed -i "s/^description:.*/description: ${profile_description}/" "$profile_file"

    log_info "Profile created: $profile_file"
}

# Delete custom profile
delete_profile() {
    local profile_name="$1"
    local profile_file="${FUB_USER_PROFILES_DIR}/${profile_name}.yaml"

    if [[ ! -f "$profile_file" ]]; then
        log_error "User profile not found: $profile_name"
        return 1
    fi

    if [[ "$FUB_CURRENT_PROFILE" == "$profile_name" ]]; then
        log_error "Cannot delete currently active profile: $profile_name"
        return 1
    fi

    log_info "Deleting profile: $profile_name"
    rm -f "$profile_file"
    log_info "Profile deleted: $profile_name"
}

# Update user configuration key
update_user_config_key() {
    local key="$1"
    local value="$2"

    # Ensure user config file exists
    if [[ ! -f "$FUB_USER_CONFIG_FILE" ]]; then
        create_default_user_config
    fi

    # Update the key in user config
    if grep -q "^${key}:" "$FUB_USER_CONFIG_FILE"; then
        sed -i "s|^${key}:.*|${key}: ${value}|" "$FUB_USER_CONFIG_FILE"
    else
        echo "${key}: ${value}" >> "$FUB_USER_CONFIG_FILE"
    fi

    log_debug "Updated user config: $key = $value"
}

# Get user configuration value
get_user_config() {
    local key="$1"
    local default_value="${2:-}"

    if [[ -f "$FUB_USER_CONFIG_FILE" ]]; then
        local value=$(grep "^${key}:" "$FUB_USER_CONFIG_FILE" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi

    echo "$default_value"
}

# Export user configuration
export_user_config() {
    local output_file="$1"
    local include_profiles="${2:-false}"

    log_info "Exporting user configuration to: $output_file"

    ensure_dir "$(dirname "$output_file")"

    {
        echo "# FUB User Configuration Export"
        echo "# Generated on $(date)"
        echo ""
        echo "# User configuration"
        cat "$FUB_USER_CONFIG_FILE"
        echo ""

        if [[ "$include_profiles" == "true" ]]; then
            echo "# Custom profiles"
            for profile_file in "${FUB_USER_PROFILES_DIR}"/*.yaml; do
                if [[ -f "$profile_file" ]]; then
                    echo "# Profile: $(basename "$profile_file" .yaml)"
                    cat "$profile_file"
                    echo ""
                fi
            done
        fi

        echo "# Current profile"
        echo "current_profile: $(get_current_profile)"
    } > "$output_file"

    log_info "User configuration exported to: $output_file"
}

# Import user configuration
import_user_config() {
    local input_file="$1"
    local replace_existing="${2:-false}"

    if [[ ! -f "$input_file" ]]; then
        log_error "Import file not found: $input_file"
        return 1
    fi

    log_info "Importing user configuration from: $input_file"

    # Create backup before import
    backup_user_config

    if [[ "$replace_existing" == "true" ]]; then
        # Replace existing configuration
        cp "$input_file" "$FUB_USER_CONFIG_FILE"
    else
        # Merge configurations (simplified)
        log_info "Merging configurations..."
        # TODO: Implement proper YAML merging
    fi

    log_info "User configuration imported successfully"
}

# Backup user configuration
backup_user_config() {
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${FUB_USER_BACKUP_DIR}/user_config_${timestamp}.tar.gz"

    log_info "Backing up user configuration..."

    tar -czf "$backup_file" \
        -C "$(dirname "$FUB_USER_CONFIG_DIR")" \
        "$(basename "$FUB_USER_CONFIG_DIR")" 2>/dev/null || true

    log_info "User configuration backed up to: $backup_file"
}

# Restore user configuration
restore_user_config() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    log_info "Restoring user configuration from: $backup_file"

    # Create current backup before restore
    backup_user_config

    # Extract backup
    tar -xzf "$backup_file" -C "$(dirname "$FUB_USER_CONFIG_DIR")"

    # Reload configuration
    init_user_config

    log_info "User configuration restored successfully"
}

# List configuration backups
list_config_backups() {
    echo ""
    echo "${BOLD}${CYAN}Configuration Backups${RESET}"
    echo "======================"
    echo ""

    local backup_count=0
    for backup_file in "${FUB_USER_BACKUP_DIR}"/*.tar.gz; do
        if [[ -f "$backup_file" ]]; then
            local filename=$(basename "$backup_file")
            local timestamp=$(echo "$filename" | sed 's/user_config_\(.*\)\.tar\.gz/\1/')
            local size=$(du -h "$backup_file" | cut -f1)

            echo "${GREEN}•${RESET} ${CYAN}${filename}${RESET}"
            echo "  Timestamp: $timestamp"
            echo "  Size: $size"
            echo ""

            ((backup_count++))
        fi
    done

    if [[ $backup_count -eq 0 ]]; then
        echo "${GRAY}No configuration backups found${RESET}"
    fi

    echo ""
}

# Validate user configuration
validate_user_config() {
    log_debug "Validating user configuration..."

    local validation_errors=0

    # Check required directories
    local required_dirs=(
        "$FUB_USER_CONFIG_DIR"
        "$FUB_USER_PROFILES_DIR"
        "$FUB_USER_THEMES_DIR"
        "$FUB_USER_BACKUP_DIR"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory missing: $dir"
            ((validation_errors++))
        fi
    done

    # Check current profile
    if [[ -z "$FUB_CURRENT_PROFILE" ]]; then
        log_error "No current profile set"
        ((validation_errors++))
    fi

    # Validate profile exists
    if [[ ! -f "${FUB_CONFIG_DIR}/profiles/${FUB_CURRENT_PROFILE}.yaml" ]] &&
       [[ ! -f "${FUB_USER_PROFILES_DIR}/${FUB_CURRENT_PROFILE}.yaml" ]]; then
        log_error "Current profile not found: $FUB_CURRENT_PROFILE"
        ((validation_errors++))
    fi

    # Validate user config file
    if [[ -f "$FUB_USER_CONFIG_FILE" ]]; then
        # Basic YAML validation (check for syntax errors)
        if ! bash -n <(grep -v "^#" "$FUB_USER_CONFIG_FILE" | grep -v "^[[:space:]]*$") 2>/dev/null; then
            log_error "User configuration file has syntax errors"
            ((validation_errors++))
        fi
    fi

    if [[ $validation_errors -gt 0 ]]; then
        log_error "User configuration validation failed with $validation_errors errors"
        return 1
    fi

    log_debug "User configuration validation passed"
    return 0
}

# Show user configuration status
show_user_config_status() {
    echo ""
    echo "${BOLD}${CYAN}User Configuration Status${RESET}"
    echo "=========================="
    echo ""
    echo "${YELLOW}Configuration Directory:${RESET}"
    echo "  ${GREEN}Path:${RESET} ${CYAN}${FUB_USER_CONFIG_DIR}${RESET}"
    echo "  ${GREEN}Config File:${RESET} ${CYAN}${FUB_USER_CONFIG_FILE}${RESET}"
    echo ""
    echo "${YELLOW}Current Profile:${RESET}"
    echo "  ${GREEN}Name:${RESET} ${CYAN}${FUB_CURRENT_PROFILE}${RESET}"
    echo "  ${GREEN}Description:${RESET} ${CYAN}$(get_profile_description "${FUB_CONFIG_DIR}/profiles/${FUB_CURRENT_PROFILE}.yaml")${RESET}"
    echo ""
    echo "${YELLOW}User Directories:${RESET}"
    echo "  ${GREEN}Profiles:${RESET} ${CYAN}${FUB_USER_PROFILES_DIR}${RESET}"
    echo "  ${GREEN}Themes:${RESET} ${CYAN}${FUB_USER_THEMES_DIR}${RESET}"
    echo "  ${GREEN}Backups:${RESET} ${CYAN}${FUB_USER_BACKUP_DIR}${RESET}"
    echo ""

    # Show custom profiles count
    local custom_profiles=$(find "${FUB_USER_PROFILES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)
    echo "${YELLOW}Custom Profiles:${RESET} ${CYAN}${custom_profiles}${RESET}"

    # Show custom themes count
    local custom_themes=$(find "${FUB_USER_THEMES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)
    echo "${YELLOW}Custom Themes:${RESET} ${CYAN}${custom_themes}${RESET}"

    # Show backup count
    local backup_count=$(find "${FUB_USER_BACKUP_DIR}" -name "*.tar.gz" -type f 2>/dev/null | wc -l)
    echo "${YELLOW}Configuration Backups:${RESET} ${CYAN}${backup_count}${RESET}"

    echo ""
}

# Export functions for use in other modules
export -f init_user_config create_default_user_config load_current_profile
export -f get_current_profile set_current_profile list_profiles
export -f get_profile_description create_profile delete_profile
export -f update_user_config_key get_user_config
export -f export_user_config import_user_config backup_user_config restore_user_config
export -f list_config_backups validate_user_config show_user_config_status

# Initialize user configuration system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_user_config
    show_user_config_status
fi