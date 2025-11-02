#!/usr/bin/env bash

# FUB Dependencies Core Configuration
# Core configuration management for the dependency system

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/types/dependency.sh"

# Dependency configuration constants
readonly DEPS_CONFIG_DIR="${FUB_CONFIG_DIR}/dependencies"
readonly DEPS_CACHE_DIR="${FUB_CACHE_DIR}/dependencies"
readonly DEPS_LOG_DIR="${FUB_LOG_DIR}/dependencies"
readonly DEPS_DATA_DIR="${FUB_ROOT_DIR}/data/dependencies"

# Configuration files
readonly DEPS_REGISTRY_FILE="${DEPS_DATA_DIR}/registry.yaml"
readonly DEPS_CONFIG_FILE="${DEPS_CONFIG_DIR}/config.yaml"
readonly DEPS_STATUS_FILE="${DEPS_CACHE_DIR}/status.yaml"
readonly DEPS_RECOMMENDATIONS_FILE="${DEPS_DATA_DIR}/recommendations.yaml"

# Default configuration values
DEPS_CONFIG_auto_check="true"
DEPS_CONFIG_auto_install="false"
DEPS_CONFIG_show_recommendations="true"
DEPS_CONFIG_cache_ttl="3600"  # 1 hour in seconds
DEPS_CONFIG_parallel_checks="true"
DEPS_CONFIG_max_parallel="4"
DEPS_CONFIG_package_manager_preference="apt,snap,flatpak"
DEPS_CONFIG_install_timeout="300"  # 5 minutes
DEPS_config_backup_before_install="true"
DEPS_CONFIG_allow_external_sources="false"
DEPS_CONFIG_update_check_interval="86400"  # 24 hours
DEPS_CONFIG_min_disk_space="100MB"  # Minimum free space required

# User preferences
DEPS_CONFIG_silent_mode="false"
DEPS_CONFIG_verbose_mode="false"
DEPS_CONFIG_preferred_package_manager=""
DEPS_CONFIG_skip_tools=""
DEPS_CONFIG_only_category=""
DEPS_CONFIG_install_all_recommended="false"

# Runtime state
DEPS_CONFIG_loaded=false
DEPS_CONFIG_cache_valid=false
DEPS_CONFIG_last_update=0

# Initialize dependency configuration system
init_deps_config() {
    log_deps_debug "Initializing dependency configuration system..."

    # Ensure directories exist
    ensure_dir "$DEPS_CONFIG_DIR"
    ensure_dir "$DEPS_CACHE_DIR"
    ensure_dir "$DEPS_LOG_DIR"
    ensure_dir "$DEPS_DATA_DIR"

    # Load configuration
    load_deps_config

    # Validate configuration
    validate_deps_config

    DEPS_CONFIG_loaded=true
    log_deps_info "Dependency configuration system initialized"
}

# Load dependency configuration
load_deps_config() {
    log_deps_debug "Loading dependency configuration..."

    # Load from files in order of precedence
    load_default_deps_config
    load_system_deps_config
    load_user_deps_config
    apply_deps_environment_overrides

    log_deps_debug "Dependency configuration loaded"
}

# Load default configuration
load_default_deps_config() {
    log_deps_debug "Loading default dependency configuration..."

    # Set defaults (already defined as variables)
    log_deps_debug "Default configuration values set"
}

# Load system configuration
load_system_deps_config() {
    local config_file="$DEPS_CONFIG_FILE"

    if file_exists "$config_file"; then
        log_deps_debug "Loading system dependency configuration from: $config_file"
        load_deps_yaml_config "$config_file" "system"
    else
        log_deps_debug "System dependency configuration file not found: $config_file"
        create_default_deps_config
    fi
}

# Load user configuration
load_user_deps_config() {
    local user_config_file="${FUB_USER_CONFIG_DIR}/dependencies.yaml"

    if file_exists "$user_config_file"; then
        log_deps_debug "Loading user dependency configuration from: $user_config_file"
        load_deps_yaml_config "$user_config_file" "user"
    else
        log_deps_debug "User dependency configuration file not found: $user_config_file"
    fi
}

# Apply environment variable overrides
apply_deps_environment_overrides() {
    log_deps_debug "Applying dependency environment variable overrides..."

    # Check environment variables
    if [[ -n "${FUB_DEPS_AUTO_CHECK:-}" ]]; then
        DEPS_CONFIG_auto_check="$FUB_DEPS_AUTO_CHECK"
        log_deps_debug "Environment override: auto_check = $DEPS_CONFIG_auto_check"
    fi

    if [[ -n "${FUB_DEPS_AUTO_INSTALL:-}" ]]; then
        DEPS_CONFIG_auto_install="$FUB_DEPS_AUTO_INSTALL"
        log_deps_debug "Environment override: auto_install = $DEPS_CONFIG_auto_install"
    fi

    if [[ -n "${FUB_DEPS_SILENT:-}" ]]; then
        DEPS_CONFIG_silent_mode="$FUB_DEPS_SILENT"
        log_deps_debug "Environment override: silent_mode = $DEPS_CONFIG_silent_mode"
    fi

    if [[ -n "${FUB_DEPS_VERBOSE:-}" ]]; then
        DEPS_CONFIG_verbose_mode="$FUB_DEPS_VERBOSE"
        log_deps_debug "Environment override: verbose_mode = $DEPS_CONFIG_verbose_mode"
    fi

    if [[ -n "${FUB_DEPS_PACKAGE_MANAGER:-}" ]]; then
        DEPS_CONFIG_preferred_package_manager="$FUB_DEPS_PACKAGE_MANAGER"
        log_deps_debug "Environment override: preferred_package_manager = $DEPS_CONFIG_preferred_package_manager"
    fi
}

# Load YAML configuration file
load_deps_yaml_config() {
    local config_file="$1"
    local source_type="$2"

    log_deps_debug "Loading dependency YAML configuration from $config_file ($source_type)"

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

            log_deps_debug "Deps config: $key = $value"

            # Set the configuration value
            case "$key" in
                "auto_check") DEPS_CONFIG_auto_check="$value" ;;
                "auto_install") DEPS_CONFIG_auto_install="$value" ;;
                "show_recommendations") DEPS_CONFIG_show_recommendations="$value" ;;
                "cache_ttl") DEPS_CONFIG_cache_ttl="$value" ;;
                "parallel_checks") DEPS_CONFIG_parallel_checks="$value" ;;
                "max_parallel") DEPS_CONFIG_max_parallel="$value" ;;
                "package_manager_preference") DEPS_CONFIG_package_manager_preference="$value" ;;
                "install_timeout") DEPS_CONFIG_install_timeout="$value" ;;
                "backup_before_install") DEPS_CONFIG_backup_before_install="$value" ;;
                "allow_external_sources") DEPS_CONFIG_allow_external_sources="$value" ;;
                "update_check_interval") DEPS_CONFIG_update_check_interval="$value" ;;
                "min_disk_space") DEPS_CONFIG_min_disk_space="$value" ;;
                "silent_mode") DEPS_CONFIG_silent_mode="$value" ;;
                "verbose_mode") DEPS_CONFIG_verbose_mode="$value" ;;
                "preferred_package_manager") DEPS_CONFIG_preferred_package_manager="$value" ;;
                "skip_tools") DEPS_CONFIG_skip_tools="$value" ;;
                "only_category") DEPS_CONFIG_only_category="$value" ;;
                "install_all_recommended") DEPS_CONFIG_install_all_recommended="$value" ;;
                *) log_deps_debug "Unknown dependency config key: $key" ;;
            esac
        else
            log_deps_warn "Invalid dependency config line $line_num in $config_file: $line"
        fi
    done < "$config_file"
}

# Create default dependency configuration file
create_default_deps_config() {
    log_deps_info "Creating default dependency configuration file: $DEPS_CONFIG_FILE"

    > "$DEPS_CONFIG_FILE" cat << 'EOF'
# FUB Dependencies Configuration
# This file controls how the dependency management system behaves

# Automatic checking
auto_check: true                    # Automatically check for dependencies on startup
auto_install: false                 # Never auto-install without explicit permission

# User interface
show_recommendations: true           # Show tool recommendations to users
silent_mode: false                  # Suppress non-critical messages
verbose_mode: false                 # Show detailed operation information

# Performance
cache_ttl: 3600                     # Cache dependency status for 1 hour (seconds)
parallel_checks: true               # Check multiple tools in parallel
max_parallel: 4                     # Maximum number of parallel checks

# Package management
package_manager_preference: "apt,snap,flatpak"  # Preferred package managers
install_timeout: 300                # Installation timeout in seconds
backup_before_install: true         # Create backup before installing tools
allow_external_sources: false       # Only install from trusted sources

# Update checking
update_check_interval: 86400        # Check for tool updates every 24 hours
min_disk_space: "100MB"             # Minimum free space required

# User preferences
skip_tools: ""                      # Comma-separated list of tools to skip
only_category: ""                   # Only check tools in this category
install_all_recommended: false      # Install all recommended tools without prompting
preferred_package_manager: ""       # Force specific package manager
EOF

    log_deps_info "Default dependency configuration file created"
}

# Validate dependency configuration
validate_deps_config() {
    log_deps_debug "Validating dependency configuration..."

    local validation_errors=0

    # Validate boolean values
    for config_var in auto_check auto_install show_recommendations parallel_checks \
                      backup_before_install allow_external_sources silent_mode \
                      verbose_mode install_all_recommended; do
        local var_value="DEPS_CONFIG_${config_var}"
        local value="${!var_value}"

        case "$value" in
            true|false) ;;
            *)
                log_deps_error "Invalid boolean value for $config_var: $value"
                ((validation_errors++))
                ;;
        esac
    done

    # Validate numeric values
    for config_var in cache_ttl max_parallel install_timeout update_check_interval; do
        local var_value="DEPS_CONFIG_${config_var}"
        local value="${!var_value}"

        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            log_deps_error "Invalid numeric value for $config_var: $value"
            ((validation_errors++))
        fi
    done

    # Validate ranges
    if [[ $DEPS_CONFIG_max_parallel -lt 1 ]] || [[ $DEPS_CONFIG_max_parallel -gt 10 ]]; then
        log_deps_error "max_parallel must be between 1 and 10: $DEPS_CONFIG_max_parallel"
        ((validation_errors++))
    fi

    if [[ $DEPS_CONFIG_cache_ttl -lt 60 ]]; then
        log_deps_error "cache_ttl must be at least 60 seconds: $DEPS_CONFIG_cache_ttl"
        ((validation_errors++))
    fi

    if [[ $DEPS_CONFIG_install_timeout -lt 30 ]] || [[ $DEPS_CONFIG_install_timeout -gt 1800 ]]; then
        log_deps_error "install_timeout must be between 30 and 1800 seconds: $DEPS_CONFIG_install_timeout"
        ((validation_errors++))
    fi

    # Validate disk space format
    if ! [[ "$DEPS_CONFIG_min_disk_space" =~ ^[0-9]+[KMGT]?B?$ ]]; then
        log_deps_error "Invalid min_disk_space format: $DEPS_CONFIG_min_disk_space"
        ((validation_errors++))
    fi

    if [[ $validation_errors -gt 0 ]]; then
        log_deps_error "Dependency configuration validation failed with $validation_errors errors"
        exit 1
    fi

    log_deps_debug "Dependency configuration validation passed"
}

# Get dependency configuration value
get_deps_config() {
    local key="$1"
    local default_value="${2:-}"

    local var_name="DEPS_CONFIG_${key}"
    local value="${!var_name:-$default_value}"
    echo "$value"
}

# Set dependency configuration value
set_deps_config() {
    local key="$1"
    local value="$2"
    local scope="${3:-runtime}"  # runtime, user, or system

    local var_name="DEPS_CONFIG_${key}"

    case "$scope" in
        runtime)
            printf -v "$var_name" '%s' "$value"
            log_deps_debug "Runtime deps config: $key = $value"
            ;;
        user)
            printf -v "$var_name" '%s' "$value"
            write_deps_config_file "${FUB_USER_CONFIG_DIR}/dependencies.yaml" "$key" "$value"
            log_deps_debug "User deps config: $key = $value"
            ;;
        system)
            printf -v "$var_name" '%s' "$value"
            write_deps_config_file "$DEPS_CONFIG_FILE" "$key" "$value"
            log_deps_debug "System deps config: $key = $value"
            ;;
        *)
            log_deps_error "Invalid dependency config scope: $scope"
            return 1
            ;;
    esac
}

# Write configuration value to file
write_deps_config_file() {
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

    log_deps_debug "Written to dependency config file: $config_file, $key = $value"
}

# Check if configuration cache is valid
is_deps_cache_valid() {
    local current_time=$(date +%s)
    local cache_age=$((current_time - DEPS_CONFIG_last_update))
    local cache_ttl=$(get_deps_config cache_ttl)

    [[ $cache_age -lt $cache_ttl ]]
}

# Reset configuration to defaults
reset_deps_config() {
    local scope="${1:-runtime}"

    log_deps_info "Resetting dependency configuration to defaults ($scope scope)"

    case "$scope" in
        runtime)
            load_default_deps_config
            ;;
        user)
            rm -f "${FUB_USER_CONFIG_DIR}/dependencies.yaml"
            load_default_deps_config
            ;;
        system)
            log_deps_warn "Resetting system dependency configuration requires sudo"
            require_root
            rm -f "$DEPS_CONFIG_FILE"
            create_default_deps_config
            load_default_deps_config
            ;;
        *)
            log_deps_error "Invalid dependency config scope for reset: $scope"
            return 1
            ;;
    esac
}

# Show current dependency configuration
show_deps_config() {
    local section="${1:-all}"

    echo ""
    echo "${BOLD}${CYAN}FUB Dependencies Configuration${RESET}"
    echo "================================="
    echo ""

    case "$section" in
        all)
            echo "${YELLOW}All Configuration:${RESET}"
            echo ""
            echo "${GREEN}Automatic Checking:${RESET}"
            echo "  auto_check: $(get_deps_config auto_check)"
            echo "  auto_install: $(get_deps_config auto_install)"
            echo "  show_recommendations: $(get_deps_config show_recommendations)"
            echo ""
            echo "${GREEN}User Interface:${RESET}"
            echo "  silent_mode: $(get_deps_config silent_mode)"
            echo "  verbose_mode: $(get_deps_config verbose_mode)"
            echo ""
            echo "${GREEN}Performance:${RESET}"
            echo "  cache_ttl: $(get_deps_config cache_ttl) seconds"
            echo "  parallel_checks: $(get_deps_config parallel_checks)"
            echo "  max_parallel: $(get_deps_config max_parallel)"
            echo ""
            echo "${GREEN}Package Management:${RESET}"
            echo "  package_manager_preference: $(get_deps_config package_manager_preference)"
            echo "  install_timeout: $(get_deps_config install_timeout) seconds"
            echo "  backup_before_install: $(get_deps_config backup_before_install)"
            echo "  allow_external_sources: $(get_deps_config allow_external_sources)"
            echo ""
            echo "${GREEN}Update Checking:${RESET}"
            echo "  update_check_interval: $(get_deps_config update_check_interval) seconds"
            echo "  min_disk_space: $(get_deps_config min_disk_space)"
            ;;
        auto)
            echo "${YELLOW}Automatic Checking Configuration:${RESET}"
            echo "  auto_check: $(get_deps_config auto_check)"
            echo "  auto_install: $(get_deps_config auto_install)"
            echo "  show_recommendations: $(get_deps_config show_recommendations)"
            ;;
        performance)
            echo "${YELLOW}Performance Configuration:${RESET}"
            echo "  cache_ttl: $(get_deps_config cache_ttl) seconds"
            echo "  parallel_checks: $(get_deps_config parallel_checks)"
            echo "  max_parallel: $(get_deps_config max_parallel)"
            ;;
        package)
            echo "${YELLOW}Package Management Configuration:${RESET}"
            echo "  package_manager_preference: $(get_deps_config package_manager_preference)"
            echo "  install_timeout: $(get_deps_config install_timeout) seconds"
            echo "  backup_before_install: $(get_deps_config backup_before_install)"
            echo "  allow_external_sources: $(get_deps_config allow_external_sources)"
            ;;
        *)
            log_deps_error "Unknown dependency configuration section: $section"
            return 1
            ;;
    esac

    echo ""
}

# Export functions
export -f init_deps_config load_deps_config get_deps_config set_deps_config
export -f write_deps_config_file is_deps_cache_valid reset_deps_config show_deps_config

log_deps_debug "Dependency configuration system loaded"