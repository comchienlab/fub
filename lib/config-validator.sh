#!/usr/bin/env bash

# FUB Configuration Validator Module
# Handles configuration schema validation, error detection, and correction suggestions

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_ROOT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
    source "${FUB_ROOT_DIR}/lib/user-config.sh"
    source "${FUB_ROOT_DIR}/lib/theme-manager.sh"
fi

# Validation constants
readonly FUB_SCHEMA_DIR="${FUB_CONFIG_DIR}/schemas"
readonly FUB_VALIDATION_CACHE_DIR="${FUB_CACHE_DIR}/validation"
readonly FUB_CONFIG_VERSION="1.0.0"

# Validation state
FUB_VALIDATION_ERRORS=0
FUB_VALIDATION_WARNINGS=0
FUB_VALIDATION_SUGGESTIONS=()

# Initialize configuration validator
init_config_validator() {
    log_debug "Initializing configuration validator..."

    # Ensure validation directories exist
    ensure_dir "$FUB_SCHEMA_DIR"
    ensure_dir "$FUB_VALIDATION_CACHE_DIR"

    # Create schema files if they don't exist
    create_config_schemas

    log_debug "Configuration validator initialized"
}

# Create configuration schemas
create_config_schemas() {
    # Main configuration schema
    if [[ ! -f "${FUB_SCHEMA_DIR}/config-schema.yaml" ]]; then
        cat > "${FUB_SCHEMA_DIR}/config-schema.yaml" << 'EOF'
# FUB Configuration Schema
# Defines the structure and validation rules for FUB configuration

schema_version: "1.0.0"
name: "fub-config"

# Configuration sections
sections:
  log:
    description: "Logging configuration"
    required: true
    properties:
      level:
        type: string
        required: true
        enum: ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
        default: "INFO"
      file:
        type: string
        required: true
        pattern: "^.+\\.log$"
        default: "~/.cache/fub/logs/fub.log"
      max_size:
        type: string
        required: false
        pattern: "^[0-9]+[KMGT]?B$"
        default: "10MB"
      rotate:
        type: boolean
        required: false
        default: true
      rotate_count:
        type: integer
        required: false
        min: 1
        max: 20
        default: 5

  theme:
    description: "Theme configuration"
    required: true
    properties:
      name:
        type: string
        required: true
        pattern: "^[a-zA-Z0-9_-]+$"
        default: "tokyo-night"

  interactive:
    description: "Interactive mode settings"
    required: false
    properties:
      enabled:
        type: boolean
        required: false
        default: true
      timeout:
        type: integer
        required: false
        min: 5
        max: 300
        default: 30

  cleanup:
    description: "Cleanup configuration"
    required: false
    properties:
      temp_retention:
        type: integer
        required: false
        min: 1
        max: 365
        default: 7
      log_retention:
        type: integer
        required: false
        min: 1
        max: 365
        default: 30
      cache_retention:
        type: integer
        required: false
        min: 1
        max: 365
        default: 14

  network:
    description: "Network configuration"
    required: false
    properties:
      timeout:
        type: integer
        required: false
        min: 1
        max: 300
        default: 10
      retries:
        type: integer
        required: false
        min: 0
        max: 10
        default: 3

  safety:
    description: "Safety and protection settings"
    required: false
    properties:
      backup_before_cleanup:
        type: boolean
        required: false
        default: true
      confirm_dangerous:
        type: boolean
        required: false
        default: true
      protected_dirs:
        type: array
        required: false
        items:
          type: string
          pattern: "^/.+$"
      exclude_patterns:
        type: array
        required: false
        items:
          type: string
EOF
    fi

    # Profile schema
    if [[ ! -f "${FUB_SCHEMA_DIR}/profile-schema.yaml" ]]; then
        cat > "${FUB_SCHEMA_DIR}/profile-schema.yaml" << 'EOF'
# FUB Profile Schema
# Defines the structure and validation rules for FUB profiles

schema_version: "1.0.0"
name: "fub-profile"

# Profile properties
properties:
  name:
    type: string
    required: true
    pattern: "^[a-z0-9_-]+$"

  description:
    type: string
    required: true
    min_length: 10
    max_length: 200

  schedule:
    type: string
    required: false
    pattern: "^(daily|weekly|monthly)( [0-9]{2}:[0-9]{2})?$"

  operations:
    type: array
    required: true
    min_items: 1
    items:
      type: string
      enum: ["temp", "cache", "logs", "thumbnails", "packages", "docker", "build"]

  notifications:
    type: boolean
    required: false
    default: true

  log_level:
    type: string
    required: false
    enum: ["DEBUG", "INFO", "WARN", "ERROR"]
    default: "INFO"

  resource_limits:
    type: object
    required: false
    properties:
      memory:
        type: string
        pattern: "^[0-9]+[KMGT]?B$"
        default: "512M"
      cpu:
        type: string
        pattern: "^[0-9]+%$"
        default: "50%"
      io_priority:
        type: integer
        min: 0
        max: 7
        default: 7
      nice_level:
        type: integer
        min: -20
        max: 19
        default: 10
      timeout:
        type: integer
        min: 60
        max: 7200
        default: 1800

  conditions:
    type: array
    required: false
    items:
      type: object
      properties:
        ac_power:
          type: boolean
        idle_time:
          type: integer
          min: 0
          max: 3600
        system_load:
          type: string
          pattern: "^< [0-9]+\\.[0-9]+$"
EOF
    fi

    # Theme schema
    if [[ ! -f "${FUB_SCHEMA_DIR}/theme-schema.yaml" ]]; then
        cat > "${FUB_SCHEMA_DIR}/theme-schema.yaml" << 'EOF'
# FUB Theme Schema
# Defines the structure and validation rules for FUB themes

schema_version: "1.0.0"
name: "fub-theme"

# Theme properties
properties:
  name:
    type: string
    required: true
    pattern: "^[a-zA-Z0-9_-]+$"

  description:
    type: string
    required: true
    min_length: 10
    max_length: 200

  version:
    type: string
    required: true
    pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"

  author:
    type: string
    required: false

  # Basic colors
  background:
    type: string
    required: true
    pattern: "^#[0-9a-fA-F]{6}$"

  foreground:
    type: string
    required: true
    pattern: "^#[0-9a-fA-F]{6}$"

  cursor:
    type: string
    required: false
    pattern: "^#[0-9a-fA-F]{6}$"

  # ANSI colors (color0-color15)
  color[0-9]:
    type: string
    required: true
    pattern: "^#[0-9a-fA-F]{6}$"

  color1[0-5]:
    type: string
    required: true
    pattern: "^#[0-9a-fA-F]{6}$"

  # Semantic colors
  semantic:
    type: object
    required: false
    properties:
      success:
        type: string
        pattern: "^#[0-9a-fA-F]{6}$"
      warning:
        type: string
        pattern: "^#[0-9a-fA-F]{6}$"
      error:
        type: string
        pattern: "^#[0-9a-fA-F]{6}$"
      info:
        type: string
        pattern: "^#[0-9a-fA-F]{6}$"
      debug:
        type: string
        pattern: "^#[0-9a-fA-F]{6}$"
      highlight:
        type: string
        pattern: "^#[0-9a-fA-F]{6}$"
EOF
    fi
}

# Validate configuration file
validate_config_file() {
    local config_file="$1"
    local schema_file="$2"
    local strict="${3:-false}"

    log_debug "Validating configuration: $config_file against schema: $schema_file"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    if [[ ! -f "$schema_file" ]]; then
        log_error "Schema file not found: $schema_file"
        return 1
    fi

    # Reset validation counters
    FUB_VALIDATION_ERRORS=0
    FUB_VALIDATION_WARNINGS=0
    FUB_VALIDATION_SUGGESTIONS=()

    # Parse and validate configuration
    validate_yaml_against_schema "$config_file" "$schema_file" "$strict"

    # Return validation result
    if [[ $FUB_VALIDATION_ERRORS -gt 0 ]]; then
        log_error "Configuration validation failed with $FUB_VALIDATION_ERRORS errors"
        return 1
    elif [[ $FUB_VALIDATION_WARNINGS -gt 0 ]]; then
        log_warn "Configuration validation completed with $FUB_VALIDATION_WARNINGS warnings"
        return 2
    else
        log_debug "Configuration validation passed"
        return 0
    fi
}

# Validate YAML against schema (simplified implementation)
validate_yaml_against_schema() {
    local config_file="$1"
    local schema_file="$2"
    local strict="$3"

    # Load schema configuration
    local schema_version=$(grep "^schema_version:" "$schema_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
    local schema_name=$(grep "^name:" "$schema_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')

    log_debug "Validating against schema: $schema_name v$schema_version"

    # Basic syntax validation
    validate_yaml_syntax "$config_file"

    # Validate required sections
    validate_required_sections "$config_file" "$schema_file"

    # Validate value types and patterns
    validate_values_and_patterns "$config_file" "$schema_file" "$strict"

    # Check for deprecated or unknown keys
    validate_unknown_keys "$config_file" "$schema_file" "$strict"
}

# Validate YAML syntax
validate_yaml_syntax() {
    local config_file="$1"

    log_debug "Validating YAML syntax..."

    local line_num=0
    local in_multiline=false
    local multiline_indent=""

    while IFS= read -r line; do
        ((line_num++))

        # Skip empty lines and comments
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Check for basic YAML syntax issues
        if [[ "$line" =~ ^[[:space:]]*[^[:space:]]+[[:space:]]*:[[:space:]]*$ ]]; then
            # Valid section header
            continue
        elif [[ "$line" =~ ^[[:space:]]*[^[:space:]]+[[:space:]]*:[[:space:]]*[^[:space:]] ]]; then
            # Valid key-value pair
            continue
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]+[^[:space:]] ]]; then
            # Valid list item
            continue
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*$ ]]; then
            # Start of multiline list item
            in_multiline=true
            multiline_indent=$(echo "$line" | sed 's/-.*$//')
            continue
        elif [[ "$in_multiline" == "true" ]]; then
            # Check indentation consistency
            if [[ ! "$line" =~ ^${multiline_indent}[[:space:]]+[^[:space:]] ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                add_validation_error "Invalid indentation in multiline value at line $line_num"
            fi
            if [[ "$line" =~ ^[[:space:]]*[^[:space:]] ]] && [[ ! "$line" =~ ^${multiline_indent} ]]; then
                in_multiline=false
                multiline_indent=""
            fi
            continue
        else
            add_validation_error "Invalid YAML syntax at line $line_num: $line"
        fi
    done < "$config_file"
}

# Validate required sections
validate_required_sections() {
    local config_file="$1"
    local schema_file="$2"

    log_debug "Validating required sections..."

    # Extract required sections from schema
    local required_sections=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*$ ]]; then
            local section="${BASH_REMATCH[1]}"
            local required="false"

            # Look ahead to check if section is required
            local found_section=false
            while IFS= read -r next_line; do
                if [[ "$next_line" =~ ^[[:space:]]*}[[:space:]]*$ ]]; then
                    break
                elif [[ "$next_line" =~ ^[[:space:]]*required:[[:space:]]*(.*)[[:space:]]*$ ]]; then
                    required="${BASH_REMATCH[1]}"
                    found_section=true
                    break
                fi
            done < <(sed -n "/^  ${section}:/,/^  [a-zA-Z]/p" "$schema_file")

            if [[ "$required" == "true" ]]; then
                required_sections+=("$section")
            fi
        fi
    done < "$schema_file"

    # Check if required sections exist in config
    for section in "${required_sections[@]}"; do
        if ! grep -q "^${section}:" "$config_file"; then
            add_validation_error "Required section missing: $section"
        fi
    done
}

# Validate values and patterns
validate_values_and_patterns() {
    local config_file="$1"
    local schema_file="$2"
    local strict="$3"

    log_debug "Validating values and patterns..."

    # This is a simplified implementation
    # In a production system, you'd want a more sophisticated YAML schema parser

    # Validate log level
    local log_level=$(grep "^log.level:" "$config_file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    if [[ -n "$log_level" ]]; then
        case "$log_level" in
            DEBUG|INFO|WARN|ERROR|FATAL) ;;
            *) add_validation_error "Invalid log.level: $log_level. Must be one of: DEBUG, INFO, WARN, ERROR, FATAL" ;;
        esac
    fi

    # Validate theme name
    local theme=$(grep "^theme:" "$config_file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    if [[ -n "$theme" ]]; then
        if [[ ! "$theme" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            add_validation_error "Invalid theme name: $theme. Must contain only alphanumeric characters, underscores, and hyphens"
        fi
    fi

    # Validate timeout values
    local timeout=$(grep "^timeout:" "$config_file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    if [[ -n "$timeout" ]]; then
        if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
            add_validation_error "Invalid timeout: $timeout. Must be a positive integer"
        elif [[ $timeout -lt 5 || $timeout -gt 300 ]]; then
            add_validation_warning "Timeout value $timeout is outside recommended range (5-300 seconds)"
        fi
    fi

    # Validate cleanup retention periods
    local retention_keys=("cleanup.temp_retention" "cleanup.log_retention" "cleanup.cache_retention")
    for key in "${retention_keys[@]}"; do
        local value=$(grep "^${key}:" "$config_file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
        if [[ -n "$value" ]]; then
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                add_validation_error "Invalid retention period for $key: $value. Must be a positive integer"
            elif [[ $value -lt 1 || $value -gt 365 ]]; then
                add_validation_warning "Retention period for $key ($value days) is outside recommended range (1-365 days)"
            fi
        fi
    done

    # Validate file paths
    local log_file=$(grep "^log.file:" "$config_file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    if [[ -n "$log_file" ]]; then
        # Expand environment variables
        log_file=$(eval echo "$log_file")
        local log_dir=$(dirname "$log_file")

        if [[ ! -d "$log_dir" ]]; then
            add_validation_suggestion "Log directory does not exist: $log_dir. Consider creating it or changing the log file path."
        fi

        if [[ ! "$log_file" =~ \.log$ ]]; then
            add_validation_warning "Log file should have .log extension: $log_file"
        fi
    fi
}

# Validate unknown keys
validate_unknown_keys() {
    local config_file="$1"
    local schema_file="$2"
    local strict="$3"

    log_debug "Validating unknown keys..."

    # Extract known keys from schema (simplified)
    local known_keys=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_.]*)[[:space:]]*:[[:space:]] ]]; then
            known_keys+=("${BASH_REMATCH[1]}")
        fi
    done < "$schema_file"

    # Check for unknown keys in config
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_.]*)[[:space:]]*: ]]; then
            local config_key="${BASH_REMATCH[1]}"
            local known=false

            for known_key in "${known_keys[@]}"; do
                if [[ "$config_key" == "$known_key" ]]; then
                    known=true
                    break
                fi
            done

            if [[ "$known" == "false" ]]; then
                if [[ "$strict" == "true" ]]; then
                    add_validation_error "Unknown configuration key: $config_key"
                else
                    add_validation_warning "Unknown configuration key: $config_key"
                fi
            fi
        fi
    done < "$config_file"
}

# Add validation error
add_validation_error() {
    local message="$1"
    ((FUB_VALIDATION_ERRORS++))
    log_error "Validation Error: $message"
}

# Add validation warning
add_validation_warning() {
    local message="$1"
    ((FUB_VALIDATION_WARNINGS++))
    log_warn "Validation Warning: $message"
}

# Add validation suggestion
add_validation_suggestion() {
    local message="$1"
    FUB_VALIDATION_SUGGESTIONS+=("$message")
    log_info "Suggestion: $message"
}

# Validate all configuration files
validate_all_configs() {
    local strict="${1:-false}"

    log_info "Validating all configuration files..."

    local overall_errors=0
    local overall_warnings=0

    # Validate main configuration
    echo "Validating main configuration..."
    if validate_config_file "${FUB_CONFIG_DIR}/default.yaml" "${FUB_SCHEMA_DIR}/config-schema.yaml" "$strict"; then
        echo "✓ Main configuration valid"
    else
        echo "✗ Main configuration has issues"
        ((overall_errors += FUB_VALIDATION_ERRORS))
        ((overall_warnings += FUB_VALIDATION_WARNINGS))
    fi

    # Validate user configuration
    if [[ -f "$FUB_USER_CONFIG_FILE" ]]; then
        echo "Validating user configuration..."
        if validate_config_file "$FUB_USER_CONFIG_FILE" "${FUB_SCHEMA_DIR}/config-schema.yaml" "$strict"; then
            echo "✓ User configuration valid"
        else
            echo "✗ User configuration has issues"
            ((overall_errors += FUB_VALIDATION_ERRORS))
            ((overall_warnings += FUB_VALIDATION_WARNINGS))
        fi
    fi

    # Validate current profile
    local current_profile=$(get_current_profile)
    local profile_file="${FUB_CONFIG_DIR}/profiles/${current_profile}.yaml"
    if [[ ! -f "$profile_file" ]]; then
        profile_file="${FUB_USER_PROFILES_DIR}/${current_profile}.yaml"
    fi

    if [[ -f "$profile_file" ]]; then
        echo "Validating current profile: $current_profile"
        if validate_config_file "$profile_file" "${FUB_SCHEMA_DIR}/profile-schema.yaml" "$strict"; then
            echo "✓ Profile $current_profile valid"
        else
            echo "✗ Profile $current_profile has issues"
            ((overall_errors += FUB_VALIDATION_ERRORS))
            ((overall_warnings += FUB_VALIDATION_WARNINGS))
        fi
    fi

    # Validate current theme
    local current_theme=$(get_user_config "theme.name" "tokyo-night")
    local theme_file="${FUB_THEMES_DIR}/${current_theme}.yaml"
    if [[ ! -f "$theme_file" ]]; then
        theme_file="${FUB_USER_THEMES_DIR}/${current_theme}.yaml"
    fi

    if [[ -f "$theme_file" ]]; then
        echo "Validating current theme: $current_theme"
        if validate_config_file "$theme_file" "${FUB_SCHEMA_DIR}/theme-schema.yaml" "$strict"; then
            echo "✓ Theme $current_theme valid"
        else
            echo "✗ Theme $current_theme has issues"
            ((overall_errors += FUB_VALIDATION_ERRORS))
            ((overall_warnings += FUB_VALIDATION_WARNINGS))
        fi
    fi

    # Show overall result
    echo ""
    echo "${BOLD}${CYAN}Validation Summary${RESET}"
    echo "=================="
    echo "Errors: ${RED}${overall_errors}${RESET}"
    echo "Warnings: ${YELLOW}${overall_warnings}${RESET}"

    if [[ ${#FUB_VALIDATION_SUGGESTIONS[@]} -gt 0 ]]; then
        echo ""
        echo "${YELLOW}Suggestions:${RESET}"
        for suggestion in "${FUB_VALIDATION_SUGGESTIONS[@]}"; do
            echo "  • ${CYAN}${suggestion}${RESET}"
        done
    fi

    echo ""

    if [[ $overall_errors -gt 0 ]]; then
        return 1
    elif [[ $overall_warnings -gt 0 ]]; then
        return 2
    else
        return 0
    fi
}

# Auto-fix configuration issues
auto_fix_config() {
    local config_file="$1"
    local backup_suffix=".backup.$(date +%Y%m%d_%H%M%S)"

    log_info "Auto-fixing configuration: $config_file"

    # Create backup
    cp "$config_file" "${config_file}${backup_suffix}"
    log_info "Configuration backed up to: ${config_file}${backup_suffix}"

    # Fix common issues
    local fixed=false

    # Fix log level case
    if grep -q "^log.level:" "$config_file"; then
        sed -i 's/^log.level:.*/\L&/' "$config_file"
        sed -i 's/log.level: debug/log.level: DEBUG/' "$config_file"
        sed -i 's/log.level: info/log.level: INFO/' "$config_file"
        sed -i 's/log.level: warn/log.level: WARN/' "$config_file"
        sed -i 's/log.level: error/log.level: ERROR/' "$config_file"
        sed -i 's/log.level: fatal/log.level: FATAL/' "$config_file"
        fixed=true
    fi

    # Fix boolean values
    sed -i 's/true/true/g' "$config_file"
    sed -i 's/false/false/g' "$config_file"

    # Fix indentation (2 spaces)
    sed -i 's/^\t/  /g' "$config_file"

    if [[ "$fixed" == "true" ]]; then
        log_info "Configuration auto-fixed: $config_file"
        return 0
    else
        log_info "No auto-fixable issues found in: $config_file"
        return 1
    fi
}

# Show validation help
show_validation_help() {
    echo ""
    echo "${BOLD}${CYAN}Configuration Validation Help${RESET}"
    echo "==============================="
    echo ""
    echo "${YELLOW}Validation Levels:${RESET}"
    echo "  ${GREEN}•${RESET} Errors - Critical issues that must be fixed"
    echo "  ${YELLOW}•${RESET} Warnings - Non-critical issues that should be reviewed"
    echo "  ${CYAN}•${RESET} Suggestions - Recommendations for improvement"
    echo ""
    echo "${YELLOW}Common Issues:${RESET}"
    echo "  ${GREEN}•${RESET} Invalid log level - Must be DEBUG, INFO, WARN, ERROR, or FATAL"
    echo "  ${GREEN}•${RESET} Invalid timeout - Must be a positive integer (5-300 recommended)"
    echo "  ${GREEN}•${RESET} Invalid theme name - Must contain only alphanumeric characters, underscores, and hyphens"
    echo "  ${GREEN}•${RESET} Invalid retention period - Must be a positive integer (1-365 days)"
    echo "  ${GREEN}•${RESET} Missing required sections - Check schema for required configuration keys"
    echo ""
    echo "${YELLOW}Auto-Fix:${RESET}"
    echo "  The validator can automatically fix some common issues:"
    echo "  ${GREEN}•${RESET} Fix log level capitalization"
    echo "  ${GREEN}•${RESET} Fix boolean value formatting"
    echo "  ${GREEN}•${RESET} Fix indentation issues"
    echo ""
    echo "${YELLOW}Schema Files:${RESET}"
    echo "  ${GREEN}•${RESET} Config schema: ${FUB_SCHEMA_DIR}/config-schema.yaml"
    echo "  ${GREEN}•${RESET} Profile schema: ${FUB_SCHEMA_DIR}/profile-schema.yaml"
    echo "  ${GREEN}•${RESET} Theme schema: ${FUB_SCHEMA_DIR}/theme-schema.yaml"
    echo ""
}

# Export functions for use in other modules
export -f init_config_validator create_config_schemas
export -f validate_config_file validate_yaml_against_schema
export -f validate_yaml_syntax validate_required_sections
export -f validate_values_and_patterns validate_unknown_keys
export -f add_validation_error add_validation_warning add_validation_suggestion
export -f validate_all_configs auto_fix_config show_validation_help

# Initialize configuration validator if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_config_validator
    validate_all_configs "${1:-false}"
fi