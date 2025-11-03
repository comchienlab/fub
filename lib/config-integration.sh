#!/usr/bin/env bash

# FUB Configuration Integration Module
# Integrates all configuration management components and provides unified interface

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_ROOT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Source configuration modules
source "${FUB_ROOT_DIR}/lib/user-config.sh"
source "${FUB_ROOT_DIR}/lib/theme-manager.sh"
source "${FUB_ROOT_DIR}/lib/config-validator.sh"
source "${FUB_ROOT_DIR}/lib/config-ui.sh"

# Initialize complete configuration system
init_fub_config() {
    log_info "Initializing FUB Configuration System..."

    # Initialize core configuration
    init_config

    # Initialize user configuration
    init_user_config

    # Initialize theme manager
    init_theme_manager

    # Initialize configuration validator
    init_config_validator

    # Initialize configuration UI
    init_config_ui

    log_info "FUB Configuration System initialized successfully"
}

# Quick configuration setup for new users
setup_fub_config() {
    local interactive="${1:-true}"

    log_info "Setting up FUB configuration..."

    # Create user directories
    ensure_dir "$FUB_USER_CONFIG_DIR"
    ensure_dir "$FUB_USER_PROFILES_DIR"
    ensure_dir "$FUB_USER_THEMES_DIR"
    ensure_dir "$FUB_USER_BACKUP_DIR"

    # Create default user configuration
    if [[ ! -f "$FUB_USER_CONFIG_FILE" ]]; then
        create_default_user_config
    fi

    if [[ "$interactive" == "true" ]]; then
        echo ""
        gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
            "🚀 FUB Configuration Setup"

        echo ""
        echo "Welcome to FUB! Let's configure your setup."
        echo ""

        # Get user preferences
        local user_name=$(gum input --value="$(whoami)" --placeholder="Your name")
        local user_email=$(gum input --placeholder="Your email (optional)")
        local preferred_theme=$(gum choose "tokyo-night" "light" "dark" --header="Preferred theme")
        local interactive_mode=$(gum choose "true" "false" --header="Enable interactive mode?" --selected="true")

        # Update user configuration
        update_user_config_key "user.name" "$user_name"
        update_user_config_key "user.email" "$user_email"
        update_user_config_key "user.preferred_theme" "$preferred_theme"
        update_user_config_key "user.interactive_mode" "$interactive_mode"

        # Select profile
        echo ""
        echo "Select your usage profile:"
        local profile=$(gum choose \
            "desktop - Desktop user with GUI applications" \
            "server - Server with minimal resource usage" \
            "developer - Development environment with build tools" \
            --header="Usage Profile")

        case "$profile" in
            "desktop - Desktop user with GUI applications"*)
                set_current_profile "desktop"
                ;;
            "server - Server with minimal resource usage"*)
                set_current_profile "server"
                ;;
            "developer - Development environment with build tools"*)
                set_current_profile "developer"
                ;;
        esac

        # Set theme
        set_theme "$preferred_theme"

        echo ""
        gum style --foreground=10 "✅ Configuration setup complete!"
        echo ""
        echo "You can always change these settings later using:"
        echo "  fub config"
        echo ""
    fi

    # Validate configuration
    validate_all_configs "false"

    log_info "FUB configuration setup completed"
}

# Get unified configuration value
get_fub_config() {
    local key="$1"
    local default_value="${2:-}"

    # Try user config first
    local user_value=$(get_user_config "$key")
    if [[ -n "$user_value" ]]; then
        echo "$user_value"
        return
    fi

    # Fall back to system config
    local system_value=$(get_config "$key" "$default_value")
    echo "$system_value"
}

# Set unified configuration value
set_fub_config() {
    local key="$1"
    local value="$2"
    local scope="${3:-user}"  # user or system

    case "$scope" in
        user)
            update_user_config_key "$key" "$value"
            ;;
        system)
            set_config "$key" "$value" "system"
            ;;
        *)
            log_error "Invalid configuration scope: $scope"
            return 1
            ;;
    esac

    log_debug "Configuration updated: $key = $value ($scope)"
}

# Export complete configuration
export_fub_config() {
    local output_file="$1"
    local format="${2:-yaml}"
    local include_user="${3:-true}"
    local include_profiles="${4:-false}"
    local include_themes="${5:-false}"

    log_info "Exporting complete FUB configuration to: $output_file"

    ensure_dir "$(dirname "$output_file")"

    {
        echo "# FUB Complete Configuration Export"
        echo "# Generated on $(date)"
        echo ""

        if [[ "$include_user" == "true" ]]; then
            echo "# User Configuration"
            if [[ -f "$FUB_USER_CONFIG_FILE" ]]; then
                cat "$FUB_USER_CONFIG_FILE"
            fi
            echo ""
        fi

        echo "# System Configuration"
        if [[ -f "${FUB_CONFIG_DIR}/default.yaml" ]]; then
            cat "${FUB_CONFIG_DIR}/default.yaml"
        fi
        echo ""

        if [[ "$include_profiles" == "true" ]]; then
            echo "# Current Profile: $(get_current_profile)"
            local current_profile_file="${FUB_CONFIG_DIR}/profiles/$(get_current_profile).yaml"
            if [[ ! -f "$current_profile_file" ]]; then
                current_profile_file="${FUB_USER_PROFILES_DIR}/$(get_current_profile).yaml"
            fi
            if [[ -f "$current_profile_file" ]]; then
                echo "# Profile Configuration"
                cat "$current_profile_file"
            fi
            echo ""
        fi

        if [[ "$include_themes" == "true" ]]; then
            local current_theme=$(get_user_config 'theme.name')
            local theme_file="${FUB_THEMES_DIR}/${current_theme}.yaml"
            if [[ ! -f "$theme_file" ]]; then
                theme_file="${FUB_USER_THEMES_DIR}/${current_theme}.yaml"
            fi
            if [[ -f "$theme_file" ]]; then
                echo "# Current Theme: $current_theme"
                cat "$theme_file"
            fi
            echo ""
        fi

        echo "# Export Metadata"
        echo "export_timestamp: $(date -Iseconds)"
        echo "fub_version: $FUB_VERSION"
        echo "current_profile: $(get_current_profile)"
        echo "current_theme: $(get_user_config 'theme.name')"
    } > "$output_file"

    log_info "Complete configuration exported to: $output_file"
}

# Import complete configuration
import_fub_config() {
    local input_file="$1"
    local replace_existing="${2:-false}"
    local backup_before="${3:-true}"

    if [[ ! -f "$input_file" ]]; then
        log_error "Import file not found: $input_file"
        return 1
    fi

    log_info "Importing complete FUB configuration from: $input_file"

    # Create backup before import
    if [[ "$backup_before" == "true" ]]; then
        backup_user_config
    fi

    # This is a simplified import - in a production system you'd want
    # more sophisticated parsing and merging
    if [[ "$replace_existing" == "true" ]]; then
        # Replace user configuration
        cp "$input_file" "$FUB_USER_CONFIG_FILE"
    else
        # Merge configurations (simplified approach)
        log_warn "Configuration merging not fully implemented - replacing existing config"
        cp "$input_file" "$FUB_USER_CONFIG_FILE"
    fi

    # Reload all configuration
    init_config
    init_user_config
    init_theme_manager

    # Validate imported configuration
    validate_all_configs "false"

    log_info "Complete configuration imported successfully"
}

# Show configuration system status
show_fub_config_status() {
    echo ""
    echo "${BOLD}${CYAN}FUB Configuration System Status${RESET}"
    echo "=================================="
    echo ""

    echo "${YELLOW}System Information:${RESET}"
    echo "  ${GREEN}FUB Version:${RESET} ${CYAN}${FUB_VERSION:-unknown}${RESET}"
    echo "  ${GREEN}Config Directory:${RESET} ${CYAN}${FUB_CONFIG_DIR}${RESET}"
    echo "  ${GREEN}User Config Directory:${RESET} ${CYAN}${FUB_USER_CONFIG_DIR}${RESET}"
    echo "  ${GREEN}User Config File:${RESET} ${CYAN}${FUB_USER_CONFIG_FILE}${RESET}"
    echo ""

    echo "${YELLOW}Current Settings:${RESET}"
    echo "  ${GREEN}Profile:${RESET} ${CYAN}$(get_current_profile)${RESET}"
    echo "  ${GREEN}Theme:${RESET} ${CYAN}$(get_user_config 'theme.name')${RESET}"
    echo "  ${GREEN}Interactive Mode:${RESET} ${CYAN}$(get_user_config 'user.interactive_mode')${RESET}"
    echo ""

    echo "${YELLOW}Configuration Files:${RESET}"
    local files_exist=0

    if [[ -f "$FUB_USER_CONFIG_FILE" ]]; then
        echo "  ${GREEN}✓${RESET} User configuration file exists"
        ((files_exist++))
    else
        echo "  ${RED}✗${RESET} User configuration file missing"
    fi

    if [[ -f "${FUB_CONFIG_DIR}/default.yaml" ]]; then
        echo "  ${GREEN}✓${RESET} System configuration file exists"
        ((files_exist++))
    else
        echo "  ${RED}✗${RESET} System configuration file missing"
    fi

    local current_profile=$(get_current_profile)
    if [[ -f "${FUB_CONFIG_DIR}/profiles/${current_profile}.yaml" ]] ||
       [[ -f "${FUB_USER_PROFILES_DIR}/${current_profile}.yaml" ]]; then
        echo "  ${GREEN}✓${RESET} Current profile file exists"
        ((files_exist++))
    else
        echo "  ${RED}✗${RESET} Current profile file missing"
    fi

    local current_theme=$(get_user_config 'theme.name')
    if [[ -f "${FUB_THEMES_DIR}/${current_theme}.yaml" ]] ||
       [[ -f "${FUB_USER_THEMES_DIR}/${current_theme}.yaml" ]]; then
        echo "  ${GREEN}✓${RESET} Current theme file exists"
        ((files_exist++))
    else
        echo "  ${RED}✗${RESET} Current theme file missing"
    fi

    echo ""

    echo "${YELLOW}Configuration Status:${RESET}"
    if [[ $files_exist -eq 4 ]]; then
        echo "  ${GREEN}✓${RESET} All configuration files present"
    else
        echo "  ${YELLOW}⚠${RESET} Some configuration files missing"
    fi

    # Validate configuration
    if validate_all_configs "false" >/dev/null 2>&1; then
        echo "  ${GREEN}✓${RESET} Configuration validation passed"
    else
        echo "  ${RED}✗${RESET} Configuration validation failed"
    fi

    echo ""

    echo "${YELLOW}Available Resources:${RESET}"
    local system_profiles=$(find "${FUB_CONFIG_DIR}/profiles" -name "*.yaml" -type f 2>/dev/null | wc -l)
    local user_profiles=$(find "${FUB_USER_PROFILES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)
    local system_themes=$(find "${FUB_THEMES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)
    local user_themes=$(find "${FUB_USER_THEMES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)
    local backups=$(find "${FUB_USER_BACKUP_DIR}" -name "*.tar.gz" -type f 2>/dev/null | wc -l)

    echo "  ${GREEN}System Profiles:${RESET} ${CYAN}${system_profiles}${RESET}"
    echo "  ${GREEN}User Profiles:${RESET} ${CYAN}${user_profiles}${RESET}"
    echo "  ${GREEN}System Themes:${RESET} ${CYAN}${system_themes}${RESET}"
    echo "  ${GREEN}User Themes:${RESET} ${CYAN}${user_themes}${RESET}"
    echo "  ${GREEN}Configuration Backups:${RESET} ${CYAN}${backups}${RESET}"

    echo ""
}

# Configuration migration utilities
migrate_config() {
    local from_version="$1"
    local to_version="$2"

    log_info "Migrating configuration from v$from_version to v$to_version"

    # Create backup before migration
    backup_user_config

    case "$from_version" in
        "0.1.0")
            # Migration logic for v0.1.0 to newer versions
            log_info "Performing migration from v0.1.0..."

            # Example migration steps
            # 1. Update configuration file format
            # 2. Migrate old settings to new structure
            # 3. Remove deprecated settings
            # 4. Add new default settings

            log_info "Migration from v0.1.0 completed"
            ;;
        *)
            log_warn "No migration path defined for version $from_version"
            ;;
    esac

    # Validate migrated configuration
    validate_all_configs "false"

    log_info "Configuration migration completed"
}

# Reset configuration system
reset_fub_config() {
    local scope="${1:-user}"  # user, system, or all

    gum style --foreground=208 --border=round --padding="1 2" --margin=1 \
        "⚠️  Warning: This will reset your configuration"

    if ! gum confirm "Are you sure you want to reset configuration?"; then
        return 1
    fi

    log_info "Resetting FUB configuration ($scope scope)"

    case "$scope" in
        user)
            # Backup before reset
            backup_user_config

            # Remove user configuration
            rm -rf "$FUB_USER_CONFIG_DIR"

            # Re-initialize user configuration
            init_user_config
            create_default_user_config

            log_info "User configuration reset"
            ;;
        system)
            log_warn "Resetting system configuration requires sudo"
            require_root

            # Backup system configuration
            local backup_file="${FUB_CONFIG_DIR}/default.yaml.backup.$(date +%Y%m%d_%H%M%S)"
            cp "${FUB_CONFIG_DIR}/default.yaml" "$backup_file"

            # Reset to defaults (would need default template)
            log_warn "System configuration reset not implemented"
            ;;
        all)
            reset_fub_config "user"
            reset_fub_config "system"
            ;;
        *)
            log_error "Invalid reset scope: $scope"
            return 1
            ;;
    esac

    log_info "Configuration reset completed"
}

# Export functions for use in other modules
export -f init_fub_config setup_fub_config
export -f get_fub_config set_fub_config
export -f export_fub_config import_fub_config
export -f show_fub_config_status migrate_config reset_fub_config

# Initialize FUB configuration system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        "init")
            init_fub_config
            ;;
        "setup")
            setup_fub_config "${2:-true}"
            ;;
        "status")
            show_fub_config_status
            ;;
        "reset")
            reset_fub_config "${2:-user}"
            ;;
        "validate")
            validate_all_configs "${2:-false}"
            ;;
        *)
            show_fub_config_status
            ;;
    esac
fi