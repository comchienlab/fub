#!/usr/bin/env bash

# FUB Configuration Migration Utilities
# Handles automatic detection and migration of legacy configurations

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/config.sh"
source "${FUB_ROOT_DIR}/lib/legacy/compatibility.sh"

# Migration constants
readonly FUB_MIGRATION_BACKUP_DIR="${FUB_MIGRATION_BACKUP_DIR:-${HOME}/.local/share/fub/migration-backups}"
readonly FUB_MIGRATION_LOG_FILE="${FUB_MIGRATION_LOG_FILE:-${HOME}/.local/share/fub/logs/migration.log}"

# Legacy configuration locations
readonly -a LEGACY_CONFIG_LOCATIONS=(
    "${HOME}/.fubrc"
    "${HOME}/.config/fub/config"
    "${HOME}/.fub/config"
    "/etc/fub/config"
    "/etc/fub.conf"
    "${HOME}/.fub.conf"
)

# Legacy configuration patterns
declare -A LEGACY_CONFIG_PATTERNS=(
    ["CLEANUP_RETENTION_DAYS"]="cleanup_retention"
    ["CLEANUP_VERBOSE"]="ui.verbose"
    ["CLEANUP_DRY_RUN"]="system.dry_run"
    ["CLEANUP_FORCE"]="system.force"
    ["CLEANUP_LOG_RETENTION"]="cleanup.log_retention"
    ["FUB_THEME"]="theme"
    ["FUB_LOG_LEVEL"]="logging.level"
    ["FUB_OUTPUT_FORMAT"]="ui.output_format"
    ["FUB_COLORS"]="ui.colors"
    ["FUB_INTERACTIVE"]="ui.interactive"
    ["FUB_CONFIG_FILE"]="system.config_file"
    ["FUB_BACKUP_ENABLED"]="backup.enabled"
    ["FUB_BACKUP_DIR"]="backup.directory"
    ["FUB_MONITORING_ENABLED"]="monitoring.enabled"
    ["FUB_SCHEDULER_ENABLED"]="scheduler.enabled"
    ["FUB_SAFETY_CHECKS_ENABLED"]="safety.enabled"
)

# Initialize migration system
init_migration_system() {
    log_debug "Initializing configuration migration system"

    # Create migration directories
    mkdir -p "$FUB_MIGRATION_BACKUP_DIR"
    mkdir -p "$(dirname "$FUB_MIGRATION_LOG_FILE")"

    # Initialize migration log
    {
        echo "=== FUB Configuration Migration Log ==="
        echo "Started at: $(date)"
        echo "FUB version: ${FUB_VERSION:-unknown}"
        echo ""
    } >> "$FUB_MIGRATION_LOG_FILE"

    log_debug "Migration system initialized"
}

# Detect legacy configuration files
detect_legacy_configs() {
    log_debug "Detecting legacy configuration files"

    local -a found_configs=()

    for config_location in "${LEGACY_CONFIG_LOCATIONS[@]}"; do
        if [[ -f "$config_location" ]]; then
            found_configs+=("$config_location")
            log_debug "Found legacy configuration: $config_location"
        fi
    done

    if [[ ${#found_configs[@]} -gt 0 ]]; then
        printf '%s\n' "${found_configs[@]}"
        return 0
    else
        log_debug "No legacy configuration files found"
        return 1
    fi
}

# Validate legacy configuration format
validate_legacy_config() {
    local config_file="$1"

    log_debug "Validating legacy configuration: $config_file"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$config_file" ]]; then
        log_error "Configuration file not readable: $config_file"
        return 1
    fi

    # Basic syntax validation
    local syntax_errors=0
    local line_number=0

    while IFS= read -r line; do
        ((line_number++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for basic key=value pattern
        if [[ ! "$line" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*.*$ ]]; then
            log_error "Syntax error at line $line_number: $line"
            ((syntax_errors++))
        fi
    done < "$config_file"

    if [[ $syntax_errors -gt 0 ]]; then
        log_error "Found $syntax_errors syntax errors in $config_file"
        return 1
    fi

    log_debug "Legacy configuration validation passed"
    return 0
}

# Parse legacy configuration
parse_legacy_config() {
    local config_file="$1"
    local -A parsed_config=()

    log_debug "Parsing legacy configuration: $config_file"

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Parse key=value pairs
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"

            # Convert boolean values
            case "${value,,}" in
                "true"|"yes"|"on"|"1") value="true" ;;
                "false"|"no"|"off"|"0") value="false" ;;
            esac

            parsed_config["$key"]="$value"
            log_debug "Parsed: $key = $value"
        fi
    done < "$config_file"

    # Output parsed configuration as YAML
    output_yaml_config parsed_config
}

# Convert parsed configuration to YAML format
output_yaml_config() {
    local -n config_ref=$1

    echo "# Migrated from legacy FUB configuration"
    echo "# Migration date: $(date)"
    echo "# FUB version: ${FUB_VERSION:-unknown}"
    echo ""

    # Organize configuration into sections
    echo "# System configuration"
    if [[ -n "${config_ref[CLEANUP_DRY_RUN]:-}" ]]; then
        echo "system:"
        echo "  dry_run: ${config_ref[CLEANUP_DRY_RUN]}"
    fi
    if [[ -n "${config_ref[CLEANUP_FORCE]:-}" ]]; then
        [[ -z "${config_ref[CLEANUP_DRY_RUN]:-}" ]] && echo "system:"
        echo "  force: ${config_ref[CLEANUP_FORCE]}"
    fi
    if [[ -n "${config_ref[FUB_CONFIG_FILE]:-}" ]]; then
        [[ -z "${config_ref[CLEANUP_DRY_RUN]:-}" ]] && [[ -z "${config_ref[CLEANUP_FORCE]:-}" ]] && echo "system:"
        echo "  config_file: ${config_ref[FUB_CONFIG_FILE]}"
    fi

    echo ""
    echo "# User interface configuration"
    local ui_section=false
    if [[ -n "${config_ref[CLEANUP_VERBOSE]:-}" ]]; then
        echo "ui:"
        echo "  verbose: ${config_ref[CLEANUP_VERBOSE]}"
        ui_section=true
    fi
    if [[ -n "${config_ref[FUB_COLORS]:-}" ]]; then
        [[ "$ui_section" == false ]] && echo "ui:"
        echo "  colors: ${config_ref[FUB_COLORS]}"
        ui_section=true
    fi
    if [[ -n "${config_ref[FUB_INTERACTIVE]:-}" ]]; then
        [[ "$ui_section" == false ]] && echo "ui:"
        echo "  interactive: ${config_ref[FUB_INTERACTIVE]}"
        ui_section=true
    fi
    if [[ -n "${config_ref[FUB_OUTPUT_FORMAT]:-}" ]]; then
        [[ "$ui_section" == false ]] && echo "ui:"
        echo "  output_format: ${config_ref[FUB_OUTPUT_FORMAT]}"
    fi

    echo ""
    echo "# Theme configuration"
    if [[ -n "${config_ref[FUB_THEME]:-}" ]]; then
        echo "theme: ${config_ref[FUB_THEME]}"
    fi

    echo ""
    echo "# Logging configuration"
    if [[ -n "${config_ref[FUB_LOG_LEVEL]:-}" ]]; then
        echo "logging:"
        echo "  level: ${config_ref[FUB_LOG_LEVEL]}"
    fi

    echo ""
    echo "# Cleanup configuration"
    if [[ -n "${config_ref[CLEANUP_RETENTION_DAYS]:-}" ]]; then
        echo "cleanup_retention: ${config_ref[CLEANUP_RETENTION_DAYS]}"
    fi
    if [[ -n "${config_ref[CLEANUP_LOG_RETENTION]:-}" ]]; then
        echo "cleanup:"
        echo "  log_retention: ${config_ref[CLEANUP_LOG_RETENTION]}"
    fi

    echo ""
    echo "# Backup configuration"
    local backup_section=false
    if [[ -n "${config_ref[FUB_BACKUP_ENABLED]:-}" ]]; then
        echo "backup:"
        echo "  enabled: ${config_ref[FUB_BACKUP_ENABLED]}"
        backup_section=true
    fi
    if [[ -n "${config_ref[FUB_BACKUP_DIR]:-}" ]]; then
        [[ "$backup_section" == false ]] && echo "backup:"
        echo "  directory: ${config_ref[FUB_BACKUP_DIR]}"
    fi

    echo ""
    echo "# Monitoring configuration"
    if [[ -n "${config_ref[FUB_MONITORING_ENABLED]:-}" ]]; then
        echo "monitoring:"
        echo "  enabled: ${config_ref[FUB_MONITORING_ENABLED]}"
    fi

    echo ""
    echo "# Scheduler configuration"
    if [[ -n "${config_ref[FUB_SCHEDULER_ENABLED]:-}" ]]; then
        echo "scheduler:"
        echo "  enabled: ${config_ref[FUB_SCHEDULER_ENABLED]}"
    fi

    echo ""
    echo "# Safety configuration"
    if [[ -n "${config_ref[FUB_SAFETY_CHECKS_ENABLED]:-}" ]]; then
        echo "safety:"
        echo "  enabled: ${config_ref[FUB_SAFETY_CHECKS_ENABLED]}"
    fi

    # Handle unknown configuration keys
    echo ""
    echo "# Unknown/legacy configuration keys (may need manual migration)"
    for key in "${!config_ref[@]}"; do
        local known=false
        for known_key in "${!LEGACY_CONFIG_PATTERNS[@]}"; do
            if [[ "$key" == "$known_key" ]]; then
                known=true
                break
            fi
        done

        if [[ "$known" == false ]]; then
            echo "# $key: ${config_ref[$key]}"
        fi
    done
}

# Backup existing configuration
backup_configuration() {
    local config_file="$1"
    local backup_name="$2"

    local backup_file="${FUB_MIGRATION_BACKUP_DIR}/${backup_name}.yaml"

    log_debug "Backing up configuration: $config_file -> $backup_file"

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_file"
        log_info "Configuration backed up to: $backup_file"
        return 0
    else
        log_debug "No configuration file to backup: $config_file"
        return 1
    fi
}

# Migrate configuration
migrate_configuration() {
    local legacy_config="$1"
    local new_config="$2"
    local backup_name="${3:-migration-$(date +%Y%m%d_%H%M%S)}"

    log_info "Starting configuration migration"
    log_info "Source: $legacy_config"
    log_info "Target: $new_config"
    log_info "Backup name: $backup_name"

    # Log migration start
    {
        echo "Migration started: $(date)"
        echo "Legacy config: $legacy_config"
        echo "New config: $new_config"
        echo "Backup name: $backup_name"
        echo ""
    } >> "$FUB_MIGRATION_LOG_FILE"

    # Validate legacy configuration
    if ! validate_legacy_config "$legacy_config"; then
        log_error "Legacy configuration validation failed"
        return 1
    fi

    # Create target directory if needed
    local target_dir
    target_dir="$(dirname "$new_config")"
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        log_debug "Created target directory: $target_dir"
    fi

    # Backup existing new configuration
    if [[ -f "$new_config" ]]; then
        backup_configuration "$new_config" "existing-config-${backup_name}"
    fi

    # Backup legacy configuration
    backup_configuration "$legacy_config" "legacy-config-${backup_name}"

    # Perform migration
    if parse_legacy_config "$legacy_config" > "$new_config"; then
        log_info "Configuration migrated successfully"

        # Validate new configuration
        if validate_new_config "$new_config"; then
            log_info "New configuration validated successfully"

            # Log success
            {
                echo "Migration completed successfully: $(date)"
                echo "Configuration file: $new_config"
                echo ""
            } >> "$FUB_MIGRATION_LOG_FILE"

            return 0
        else
            log_error "New configuration validation failed"
            return 1
        fi
    else
        log_error "Configuration migration failed"
        return 1
    fi
}

# Validate new YAML configuration
validate_new_config() {
    local config_file="$1"

    log_debug "Validating new configuration: $config_file"

    # Check if file exists and is readable
    if [[ ! -f "$config_file" ]] || [[ ! -r "$config_file" ]]; then
        log_error "Configuration file not accessible: $config_file"
        return 1
    fi

    # Basic YAML validation (check for obvious syntax errors)
    local yaml_errors=0
    local line_number=0
    local indent_level=0

    while IFS= read -r line; do
        ((line_number++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for basic YAML structure
        if [[ "$line" =~ ^[[:space:]]*[^:]+:[[:space:]]*.*$ ]]; then
            # Valid key-value pair
            local current_indent
            current_indent=$(echo "$line" | sed 's/^\(\s*\).*$/\1/' | wc -c)
            current_indent=$((current_indent - 1))

            # Check indentation consistency
            if [[ $current_indent -gt $((indent_level + 2)) ]]; then
                log_error "Indentation error at line $line_number: too much indentation"
                ((yaml_errors++))
            fi

            indent_level=$current_indent
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]+.*$ ]]; then
            # Valid list item
            continue
        else
            log_error "YAML syntax error at line $line_number: $line"
            ((yaml_errors++))
        fi
    done < "$config_file"

    if [[ $yaml_errors -gt 0 ]]; then
        log_error "Found $yaml_errors YAML syntax errors"
        return 1
    fi

    log_debug "New configuration validation passed"
    return 0
}

# Automatic migration of all detected legacy configurations
migrate_all_legacy_configs() {
    log_info "Starting automatic migration of all legacy configurations"

    local -a legacy_configs
    if ! readarray -t legacy_configs < <(detect_legacy_configs); then
        log_info "No legacy configurations found to migrate"
        return 0
    fi

    local migration_count=0
    local error_count=0

    for legacy_config in "${legacy_configs[@]}"; do
        log_info "Processing legacy configuration: $legacy_config"

        # Determine new configuration location
        local new_config
        case "$legacy_config" in
            "${HOME}/.fubrc"|"${HOME}/.fub.conf"|"${HOME}/.config/fub/config")
                new_config="${HOME}/.config/fub/config.yaml"
                ;;
            "${HOME}/.fub/config")
                new_config="${HOME}/.config/fub/config.yaml"
                ;;
            "/etc/fub/config"|"/etc/fub.conf")
                new_config="/etc/fub/config.yaml"
                ;;
            *)
                # Default to user config
                new_config="${HOME}/.config/fub/config.yaml"
                ;;
        esac

        # Perform migration
        if migrate_configuration "$legacy_config" "$new_config" "auto-$(basename "$legacy_config")-$(date +%Y%m%d_%H%M%S)"; then
            ((migration_count++))
            log_success "Successfully migrated: $legacy_config -> $new_config"
        else
            ((error_count++))
            log_error "Failed to migrate: $legacy_config"
        fi
    done

    # Log summary
    {
        echo "Automatic migration summary: $(date)"
        echo "Total configurations processed: ${#legacy_configs[@]}"
        echo "Successful migrations: $migration_count"
        echo "Failed migrations: $error_count"
        echo ""
    } >> "$FUB_MIGRATION_LOG_FILE"

    log_info "Migration summary: $migration_count successful, $error_count failed"

    if [[ $error_count -gt 0 ]]; then
        log_warning "Some migrations failed. Check the migration log: $FUB_MIGRATION_LOG_FILE"
        return 1
    else
        log_success "All legacy configurations migrated successfully"
        return 0
    fi
}

# Rollback configuration migration
rollback_configuration() {
    local config_file="$1"
    local backup_name="$2"

    log_info "Rolling back configuration migration"
    log_info "Config file: $config_file"
    log_info "Backup name: $backup_name"

    local backup_file="${FUB_MIGRATION_BACKUP_DIR}/${backup_name}.yaml"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Backup current configuration before rollback
    local rollback_backup="rollback-before-$(date +%Y%m%d_%H%M%S)"
    backup_configuration "$config_file" "$rollback_backup"

    # Restore from backup
    if cp "$backup_file" "$config_file"; then
        log_info "Configuration rollback completed successfully"

        # Log rollback
        {
            echo "Rollback completed: $(date)"
            echo "Config file: $config_file"
            echo "Backup used: $backup_name"
            echo "Rollback backup: $rollback_backup"
            echo ""
        } >> "$FUB_MIGRATION_LOG_FILE"

        return 0
    else
        log_error "Configuration rollback failed"
        return 1
    fi
}

# List available migration backups
list_migration_backups() {
    log_info "Available migration backups:"

    if [[ ! -d "$FUB_MIGRATION_BACKUP_DIR" ]]; then
        log_info "No backup directory found"
        return 1
    fi

    local backup_count=0
    for backup_file in "$FUB_MIGRATION_BACKUP_DIR"/*.yaml; do
        if [[ -f "$backup_file" ]]; then
            local backup_name
            backup_name=$(basename "$backup_file" .yaml)
            local backup_date
            backup_date=$(stat -c %y "$backup_file" 2>/dev/null || stat -f %Sm "$backup_file" 2>/dev/null)
            local backup_size
            backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)

            echo "  $backup_name"
            echo "    Date: $backup_date"
            echo "    Size: $backup_size"
            echo ""

            ((backup_count++))
        fi
    done

    if [[ $backup_count -eq 0 ]]; then
        log_info "No migration backups found"
        return 1
    else
        log_info "Found $backup_count migration backups"
        return 0
    fi
}

# Export migration functions
export -f init_migration_system detect_legacy_configs validate_legacy_config
export -f parse_legacy_config output_yaml_config backup_configuration
export -f migrate_configuration validate_new_config migrate_all_legacy_configs
export -f rollback_configuration list_migration_backups

# Initialize migration system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_migration_system
    log_debug "FUB configuration migration module loaded"
fi