#!/usr/bin/env bash

# FUB Configuration Management Library
# Handles configuration loading, validation, and management

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
fi

# Configuration constants
[[ -z "${FUB_CONFIG_DIR:-}" ]] && readonly FUB_CONFIG_DIR="${FUB_CONFIG_DIR:-${FUB_ROOT_DIR}/config}"
[[ -z "${FUB_USER_CONFIG_DIR:-}" ]] && readonly FUB_USER_CONFIG_DIR="${HOME}/.config/fub"
[[ -z "${FUB_CACHE_DIR:-}" ]] && readonly FUB_CACHE_DIR="${HOME}/.cache/fub"
[[ -z "${FUB_LOG_DIR:-}" ]] && readonly FUB_LOG_DIR="${FUB_CACHE_DIR}/logs"

# Configuration storage (using simple variables for compatibility)
# FUB_CONFIG values will be accessed via individual variables

# Initialize cleanup configuration variables with defaults
FUB_CONFIG_cleanup_retention="7"
FUB_CONFIG_cleanup_temp_retention="7"
FUB_CONFIG_cleanup_log_retention="30"
FUB_CONFIG_cleanup_cache_retention="7"

# Default configuration values (individual variables for bash 3.x compatibility)
if [[ -z "${FUB_DEFAULT_LOG_LEVEL:-}" ]]; then
    FUB_DEFAULT_LOG_LEVEL="INFO"
    FUB_DEFAULT_LOG_FILE="${FUB_LOG_DIR}/fub.log"
    FUB_DEFAULT_LOG_MAX_SIZE="10MB"
    FUB_DEFAULT_LOG_ROTATE="true"
    FUB_DEFAULT_LOG_ROTATE_COUNT="5"
    FUB_DEFAULT_THEME_CONFIG="tokyo-night"
    FUB_DEFAULT_INTERACTIVE="true"
    FUB_DEFAULT_TIMEOUT="30"
    FUB_DEFAULT_DRY_RUN="false"
    FUB_DEFAULT_BACKUP_ENABLED="true"
    FUB_DEFAULT_BACKUP_LOCATION="${HOME}/.local/share/fub/backups"
    FUB_DEFAULT_CLEANUP_TEMP_RETENTION="7"
    FUB_DEFAULT_CLEANUP_LOG_RETENTION="30"
    FUB_DEFAULT_CLEANUP_CACHE_RETENTION="14"
    FUB_DEFAULT_NETWORK_TIMEOUT="10"
    FUB_DEFAULT_NETWORK_RETRIES="3"
    FUB_DEFAULT_SECURITY_AUTO_UPDATE="false"
    FUB_DEFAULT_NOTIFICATIONS_ENABLED="true"
    FUB_DEFAULT_PERFORMANCE_PARALLEL="true"
    FUB_DEFAULT_PERFORMANCE_MAX_JOBS="4"
fi

# Runtime configuration storage (individual variables)
FUB_CONFIG_log_level=""
FUB_CONFIG_log_file=""
FUB_CONFIG_theme=""
FUB_CONFIG_interactive=""
FUB_CONFIG_timeout=""
FUB_CONFIG_dry_run=""

# Initialize configuration system
init_config() {
    log_debug "Initializing configuration system..."

    # Ensure required directories exist
    ensure_dir "$FUB_CONFIG_DIR"
    ensure_dir "$FUB_USER_CONFIG_DIR"
    ensure_dir "$FUB_CACHE_DIR"
    ensure_dir "$FUB_LOG_DIR"

    # Load configuration in order of precedence
    load_default_config
    load_system_config
    load_user_config
    apply_environment_overrides

    # Validate configuration
    validate_config

    log_debug "Configuration system initialized"
}

# Load configuration
load_config() {
    local config_file="${1:-${FUB_CONFIG_DIR}/default.yaml}"

    log_debug "Loading configuration from: $config_file"

    load_default_config
    load_system_config
    load_user_config
    apply_environment_overrides
}

# Load default configuration
load_default_config() {
    log_debug "Loading default configuration..."

    FUB_CONFIG_log_level="$FUB_DEFAULT_LOG_LEVEL"
    FUB_CONFIG_log_file="$FUB_DEFAULT_LOG_FILE"
    FUB_CONFIG_theme="$FUB_DEFAULT_THEME_CONFIG"
    FUB_CONFIG_interactive="$FUB_DEFAULT_INTERACTIVE"
    FUB_CONFIG_timeout="$FUB_DEFAULT_TIMEOUT"
    FUB_CONFIG_dry_run="$FUB_DEFAULT_DRY_RUN"
}

# Load system configuration from default.yaml
load_system_config() {
    local config_file="${FUB_CONFIG_DIR}/default.yaml"

    if file_exists "$config_file"; then
        log_debug "Loading system configuration from: $config_file"
        load_yaml_config "$config_file" "system"
    else
        log_debug "System configuration file not found: $config_file"
    fi
}

# Load user configuration from ~/.config/fub/
load_user_config() {
    local config_file="${FUB_USER_CONFIG_DIR}/config.yaml"

    if file_exists "$config_file"; then
        log_debug "Loading user configuration from: $config_file"
        load_yaml_config "$config_file" "user"
    else
        log_debug "User configuration file not found: $config_file"
    fi
}

# Apply environment variable overrides
apply_environment_overrides() {
    log_debug "Applying environment variable overrides..."

    # Map environment variables to config keys (simplified for bash 3.x)
    if [[ -n "${FUB_LOG_LEVEL:-}" ]]; then
        log_debug "Environment override: log.level = $FUB_LOG_LEVEL"
        FUB_CONFIG_log_level="$FUB_LOG_LEVEL"
    fi

    if [[ -n "${FUB_LOG_FILE:-}" ]]; then
        log_debug "Environment override: log.file = $FUB_LOG_FILE"
        FUB_CONFIG_log_file="$FUB_LOG_FILE"
    fi

    if [[ -n "${FUB_THEME:-}" ]]; then
        log_debug "Environment override: theme = $FUB_THEME"
        FUB_CONFIG_theme="$FUB_THEME"
    fi

    if [[ -n "${FUB_INTERACTIVE:-}" ]]; then
        log_debug "Environment override: interactive = $FUB_INTERACTIVE"
        FUB_CONFIG_interactive="$FUB_INTERACTIVE"
    fi

    if [[ -n "${FUB_TIMEOUT:-}" ]]; then
        log_debug "Environment override: timeout = $FUB_TIMEOUT"
        FUB_CONFIG_timeout="$FUB_TIMEOUT"
    fi

    if [[ -n "${FUB_DRY_RUN:-}" ]]; then
        log_debug "Environment override: dry_run = $FUB_DRY_RUN"
        FUB_CONFIG_dry_run="$FUB_DRY_RUN"
    fi
}

# Load configuration from YAML file
load_yaml_config() {
    local config_file="$1"
    local source_type="$2"

    log_debug "Loading YAML configuration from $config_file ($source_type)"

    # Simple YAML parsing - for production, consider using a proper YAML parser
    local line_num=0
    local current_section=""

    while IFS= read -r line; do
        ((line_num++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Handle sections
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        # Handle key-value pairs
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_.]*)[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Convert boolean strings
            case "$value" in
                true|True|TRUE) value="true" ;;
                false|False|FALSE) value="false" ;;
            esac

            log_debug "Config: $key = $value"
            # Set the configuration value (simplified approach)
            case "$key" in
                "log.level") FUB_CONFIG_log_level="$value" ;;
                "log.file") FUB_CONFIG_log_file="$value" ;;
                "theme") FUB_CONFIG_theme="$value" ;;
                "interactive") FUB_CONFIG_interactive="$value" ;;
                "timeout") FUB_CONFIG_timeout="$value" ;;
                "dry_run") FUB_CONFIG_dry_run="$value" ;;
                "cleanup.temp_retention") FUB_CONFIG_cleanup_temp_retention="$value" ;;
                "cleanup.log_retention") FUB_CONFIG_cleanup_log_retention="$value" ;;
                "cleanup.cache_retention") FUB_CONFIG_cleanup_cache_retention="$value" ;;
                "network.timeout") FUB_CONFIG_network_timeout="$value" ;;
                "network.retries") FUB_CONFIG_network_retries="$value" ;;
                *) log_debug "Unknown config key: $key" ;;
            esac
        else
            log_warn "Invalid config line $line_num in $config_file: $line"
        fi
    done < "$config_file"
}

# Validate configuration values
validate_config() {
    log_debug "Validating configuration..."

    local validation_errors=0

    # Validate log level
    local log_level="${FUB_CONFIG[log.level]}"
    case "$log_level" in
        DEBUG|INFO|WARN|ERROR|FATAL) ;;
        *)
            log_error "Invalid log level: $log_level"
            ((validation_errors++))
            ;;
    esac

    # Validate timeout
    local timeout="${FUB_CONFIG[timeout]}"
    if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        log_error "Invalid timeout value: $timeout"
        ((validation_errors++))
    fi

    # Validate theme
    local theme="${FUB_CONFIG[theme]}"
    local theme_file="${FUB_CONFIG_DIR}/themes/${theme}.yaml"
    if [[ ! -f "$theme_file" ]]; then
        log_warn "Theme file not found: $theme_file"
    fi

    # Validate backup location
    local backup_location="${FUB_CONFIG[backup.location]}"
    if [[ ! -d "$backup_location" ]]; then
        log_debug "Creating backup directory: $backup_location"
        ensure_dir "$backup_location"
    fi

    # Validate cleanup retention periods
    local retention_keys=("cleanup.temp_retention" "cleanup.log_retention" "cleanup.cache_retention")
    for key in "${retention_keys[@]}"; do
        local value="${FUB_CONFIG[$key]}"
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            log_error "Invalid retention period for $key: $value"
            ((validation_errors++))
        fi
    done

    # Validate network settings
    local network_timeout="${FUB_CONFIG[network.timeout]}"
    local network_retries="${FUB_CONFIG[network.retries]}"

    if ! [[ "$network_timeout" =~ ^[0-9]+$ ]]; then
        log_error "Invalid network timeout: $network_timeout"
        ((validation_errors++))
    fi

    if ! [[ "$network_retries" =~ ^[0-9]+$ ]]; then
        log_error "Invalid network retries: $network_retries"
        ((validation_errors++))
    fi

    if [[ $validation_errors -gt 0 ]]; then
        log_error "Configuration validation failed with $validation_errors errors"
        exit 1
    fi

    log_debug "Configuration validation passed"
}

# Get configuration value
get_config() {
    local key="$1"
    local default_value="${2:-}"

    # Convert key to variable name (replace dots with underscores)
    local var_name="FUB_CONFIG_${key//./_}"

    # Check if variable is set
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
    else
        echo "$default_value"
    fi
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    local scope="${3:-runtime}"  # runtime, user, or system

    # Convert key to variable name
    local var_name="FUB_CONFIG_${key//./_}"

    case "$scope" in
        runtime)
            printf -v "$var_name" '%s' "$value"
            log_debug "Runtime config: $key = $value"
            ;;
        user)
            printf -v "$var_name" '%s' "$value"
            write_config_file "${FUB_USER_CONFIG_DIR}/config.yaml" "$key" "$value"
            log_debug "User config: $key = $value"
            ;;
        system)
            printf -v "$var_name" '%s' "$value"
            write_config_file "${FUB_CONFIG_DIR}/default.yaml" "$key" "$value"
            log_debug "System config: $key = $value"
            ;;
        *)
            log_error "Invalid config scope: $scope"
            return 1
            ;;
    esac
}

# Write configuration value to file
write_config_file() {
    local config_file="$1"
    local key="$2"
    local value="$3"

    # Ensure directory exists
    ensure_dir "$(dirname "$config_file")"

    # Create file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        touch "$config_file"
    fi

    # Update or add the key
    if grep -q "^${key}:" "$config_file"; then
        # Update existing key
        sed -i "s|^${key}:.*|${key}: ${value}|" "$config_file"
    else
        # Add new key
        echo "${key}: ${value}" >> "$config_file"
    fi

    log_debug "Written to config file: $config_file, $key = $value"
}

# Reset configuration to defaults
reset_config() {
    local scope="${1:-runtime}"

    log_info "Resetting configuration to defaults ($scope scope)"

    case "$scope" in
        runtime)
            load_default_config
            ;;
        user)
            rm -f "${FUB_USER_CONFIG_DIR}/config.yaml"
            load_default_config
            ;;
        system)
            log_warn "Resetting system configuration requires sudo"
            require_root
            rm -f "${FUB_CONFIG_DIR}/default.yaml"
            load_default_config
            ;;
        *)
            log_error "Invalid config scope for reset: $scope"
            return 1
            ;;
    esac
}

# Export configuration to file
export_config() {
    local output_file="$1"
    local format="${2:-yaml}"  # yaml, json, or shell

    log_info "Exporting configuration to $output_file ($format format)"

    ensure_dir "$(dirname "$output_file")"

    case "$format" in
        yaml)
            > "$output_file" cat << EOF
# FUB Configuration Export
# Generated on $(date)

$(for key in $(printf '%s\n' "${!FUB_CONFIG[@]}" | sort); do
    value="${FUB_CONFIG[$key]}"
    echo "${key}: ${value}"
done)
EOF
            ;;
        json)
            # Simple JSON export
            > "$output_file" cat << EOF
{
  "fub_config": {
$(local first=true
for key in $(printf '%s\n' "${!FUB_CONFIG[@]}" | sort); do
    value="${FUB_CONFIG[$key]}"
    if [[ "$first" == "true" ]]; then
        first=false
    else
        echo ","
    fi
    echo "    \"${key}\": \"${value}\""
done)
  }
}
EOF
            ;;
        shell)
            > "$output_file" cat << EOF
#!/bin/bash
# FUB Configuration Export
# Generated on $(date)

$(for key in $(printf '%s\n' "${!FUB_CONFIG[@]}" | sort); do
    value="${FUB_CONFIG[$key]}"
    echo "FUB_CONFIG_${key//./_}=\"${value}\""
done)
EOF
            ;;
        *)
            log_error "Unsupported export format: $format"
            return 1
            ;;
    esac

    log_info "Configuration exported to $output_file"
}

# Import configuration from file
import_config() {
    local input_file="$1"
    local format="${2:-auto}"  # auto, yaml, json, or shell

    log_info "Importing configuration from $input_file"

    if [[ ! -f "$input_file" ]]; then
        log_error "Configuration file not found: $input_file"
        return 1
    fi

    # Auto-detect format if needed
    if [[ "$format" == "auto" ]]; then
        case "$input_file" in
            *.yaml|*.yml) format="yaml" ;;
            *.json) format="json" ;;
            *.sh) format="shell" ;;
            *) format="yaml" ;;  # Default to YAML
        esac
    fi

    case "$format" in
        yaml)
            load_yaml_config "$input_file" "import"
            ;;
        json)
            log_error "JSON import not yet implemented"
            return 1
            ;;
        shell)
            # Source shell config file
            source "$input_file"
            log_debug "Shell configuration imported from $input_file"
            ;;
        *)
            log_error "Unsupported import format: $format"
            return 1
            ;;
    esac

    validate_config
    log_info "Configuration imported successfully"
}

# Show current configuration
show_config() {
    local section="${1:-all}"

    echo ""
    echo "${BOLD}${CYAN}FUB Configuration${RESET}"
    echo "=================="
    echo ""

    case "$section" in
        all)
            echo "${YELLOW}All Configuration:${RESET}"
            echo ""
            for key in $(printf '%s\n' "${!FUB_CONFIG[@]}" | sort); do
                value="${FUB_CONFIG[$key]}"
                printf "  ${GREEN}%-25s${RESET}: ${CYAN}%s${RESET}\n" "$key" "$value"
            done
            ;;
        log)
            echo "${YELLOW}Logging Configuration:${RESET}"
            for key in log.level log.file log.max_size log.rotate log.rotate_count; do
                value="${FUB_CONFIG[$key]}"
                printf "  ${GREEN}%-25s${RESET}: ${CYAN}%s${RESET}\n" "$key" "$value"
            done
            ;;
        theme)
            echo "${YELLOW}Theme Configuration:${RESET}"
            echo "  ${GREEN}theme${RESET}: ${CYAN}${FUB_CONFIG[theme]}${RESET}"
            ;;
        backup)
            echo "${YELLOW}Backup Configuration:${RESET}"
            for key in backup.enabled backup.location; do
                value="${FUB_CONFIG[$key]}"
                printf "  ${GREEN}%-25s${RESET}: ${CYAN}%s${RESET}\n" "$key" "$value"
            done
            ;;
        cleanup)
            echo "${YELLOW}Cleanup Configuration:${RESET}"
            for key in cleanup.temp_retention cleanup.log_retention cleanup.cache_retention; do
                value="${FUB_CONFIG[$key]}"
                printf "  ${GREEN}%-25s${RESET}: ${CYAN}%s${RESET}\n" "$key" "$value"
            done
            ;;
        network)
            echo "${YELLOW}Network Configuration:${RESET}"
            for key in network.timeout network.retries; do
                value="${FUB_CONFIG[$key]}"
                printf "  ${GREEN}%-25s${RESET}: ${CYAN}%s${RESET}\n" "$key" "$value"
            done
            ;;
        *)
            log_error "Unknown configuration section: $section"
            return 1
            ;;
    esac

    echo ""
}

# Configuration backup and restore
backup_config() {
    local backup_dir="$1"

    log_info "Backing up configuration to $backup_dir"

    ensure_dir "$backup_dir"

    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${backup_dir}/fub_config_${timestamp}.tar.gz"

    tar -czf "$backup_file" \
        "${FUB_CONFIG_DIR}/default.yaml" 2>/dev/null || true \
        "${FUB_USER_CONFIG_DIR}/config.yaml" 2>/dev/null || true

    log_info "Configuration backed up to $backup_file"
}

restore_config() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    log_info "Restoring configuration from $backup_file"

    # Extract backup
    tar -xzf "$backup_file" -C /

    # Reload configuration
    init_config

    log_info "Configuration restored successfully"
}

# Configuration validation for specific modules
validate_module_config() {
    local module="$1"

    log_debug "Validating configuration for module: $module"

    case "$module" in
        cleanup)
            validate_cleanup_config
            ;;
        network)
            validate_network_config
            ;;
        security)
            validate_security_config
            ;;
        backup)
            validate_backup_config
            ;;
        *)
            log_debug "No specific validation for module: $module"
            ;;
    esac
}

# Module-specific validation functions
validate_cleanup_config() {
    local temp_retention="${FUB_CONFIG_cleanup_temp_retention}"
    local log_retention="${FUB_CONFIG_cleanup_log_retention}"
    local cache_retention="${FUB_CONFIG_cleanup_cache_retention}"

    # Validate retention periods
    for retention in "$temp_retention" "$log_retention" "$cache_retention"; do
        if ! [[ "$retention" =~ ^[0-9]+$ ]] || [[ $retention -lt 1 ]]; then
            log_error "Invalid retention period: $retention (must be >= 1)"
            return 1
        fi
    done
}

validate_network_config() {
    local timeout="${FUB_CONFIG[network.timeout]}"
    local retries="${FUB_CONFIG[network.retries]}"

    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [[ $timeout -lt 1 ]] || [[ $timeout -gt 300 ]]; then
        log_error "Invalid network timeout: $timeout (must be 1-300 seconds)"
        return 1
    fi

    if ! [[ "$retries" =~ ^[0-9]+$ ]] || [[ $retries -lt 0 ]] || [[ $retries -gt 10 ]]; then
        log_error "Invalid network retries: $retries (must be 0-10)"
        return 1
    fi
}

validate_security_config() {
    local auto_update="${FUB_CONFIG[security.auto_update]}"

    case "$auto_update" in
        true|false) ;;
        *)
            log_error "Invalid security.auto_update value: $auto_update (must be true or false)"
            return 1
            ;;
    esac
}

validate_backup_config() {
    local backup_enabled="${FUB_CONFIG[backup.enabled]}"
    local backup_location="${FUB_CONFIG[backup.location]}"

    case "$backup_enabled" in
        true|false) ;;
        *)
            log_error "Invalid backup.enabled value: $backup_enabled (must be true or false)"
            return 1
            ;;
    esac

    if [[ "$backup_enabled" == "true" ]]; then
        ensure_dir "$backup_location"
    fi
}

# Export functions for use in other modules
export -f init_config load_config get_config set_config write_config_file
export -f reset_config export_config import_config show_config
export -f validate_module_config

# Initialize configuration system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_config
    show_config "${1:-all}"
fi