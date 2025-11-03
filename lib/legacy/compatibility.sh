#!/usr/bin/env bash

# FUB Legacy Compatibility Module
# Ensures backward compatibility with existing CLI usage and scripts

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/ui.sh"

# Legacy compatibility constants
readonly FUB_LEGACY_MODE="${FUB_LEGACY_MODE:-false}"
readonly FUB_LEGACY_OUTPUT_FORMAT="${FUB_LEGACY_OUTPUT_FORMAT:-text}"
readonly FUB_LEGACY_EXIT_CODES="${FUB_LEGACY_EXIT_CODES:-true}"

# Legacy CLI arguments mapping
declare -A LEGACY_ARG_MAPPING=(
    ["--clean"]="cleanup"
    ["--purge"]="cleanup --force"
    ["--remove"]="cleanup"
    ["--clear"]="cleanup"
    ["--temp"]="cleanup temp"
    ["--cache"]="cleanup cache"
    ["--logs"]="cleanup logs"
    ["--all"]="cleanup all"
    ["--dry"]="--dry-run"
    ["--version"]="--version"
    ["--help"]="--help"
    ["-v"]="--verbose"
    ["-q"]="--quiet"
    ["-h"]="--help"
)

# Legacy command mappings
declare -A LEGACY_CMD_MAPPING=(
    ["clean"]="cleanup"
    ["purge"]="cleanup --force"
    ["clear"]="cleanup"
    ["temp"]="cleanup temp"
    ["cache"]="cleanup cache"
    ["logs"]="cleanup logs"
    ["all"]="cleanup all"
    ["update"]="system update"
    ["upgrade"]="system upgrade"
    ["install"]="package install"
    ["remove"]="package remove"
    ["search"]="package search"
    ["info"]="package info"
    ["status"]="system status"
    ["monitor"]="performance"
    ["scan"]="security scan"
    ["audit"]="security audit"
)

# Legacy exit codes
readonly LEGACY_EXIT_SUCCESS=0
readonly LEGACY_EXIT_WARNING=1
readonly LEGACY_EXIT_ERROR=2
readonly LEGACY_EXIT_CRITICAL=3
readonly LEGACY_EXIT_USAGE=64
readonly LEGACY_EXIT_NOINPUT=66
readonly LEGACY_EXIT_NOUSER=67
readonly LEGACY_EXIT_UNAVAILABLE=69
readonly LEGACY_EXIT_SOFTWARE=70
readonly LEGACY_EXIT_CANTCREAT=73
readonly LEGACY_EXIT_IOERR=74
readonly LEGACY_EXIT_TEMPFAIL=75
readonly LEGACY_EXIT_PROTOCOL=76
readonly LEGACY_EXIT_NOPERM=77
readonly LEGACY_EXIT_CONFIG=78

# Initialize legacy compatibility system
init_legacy_compatibility() {
    log_debug "Initializing legacy compatibility system"

    # Check if we're running in legacy mode
    if [[ "$FUB_LEGACY_MODE" == "true" ]]; then
        log_info "Running in legacy mode for backward compatibility"
        export FUB_INTERACTIVE=false
        export FUB_OUTPUT_FORMAT="$FUB_LEGACY_OUTPUT_FORMAT"
    fi

    # Set up legacy signal handlers
    trap 'handle_legacy_signal' TERM INT

    log_debug "Legacy compatibility system initialized"
}

# Handle legacy signals for script compatibility
handle_legacy_signal() {
    local signal="$1"
    log_debug "Received legacy signal: $signal"

    case "$signal" in
        TERM|INT)
            if [[ "$FUB_LEGACY_MODE" == "true" ]]; then
                echo ""
                print_warning "Operation cancelled by user"
                exit $LEGACY_EXIT_TEMPFAIL
            else
                echo ""
                print_warning "Operation cancelled"
                exit 130
            fi
            ;;
    esac
}

# Parse legacy command line arguments
parse_legacy_args() {
    local -a args=("$@")
    local -a new_args=()
    local i=0

    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"

        # Check for legacy arguments that need mapping
        if [[ -n "${LEGACY_ARG_MAPPING[$arg]:-}" ]]; then
            local mapped="${LEGACY_ARG_MAPPING[$arg]}"
            log_debug "Mapping legacy argument: $arg -> $mapped"

            # Split mapped argument if it contains spaces
            if [[ "$mapped" == *" "* ]]; then
                read -ra mapped_parts <<< "$mapped"
                new_args+=("${mapped_parts[@]}")
            else
                new_args+=("$mapped")
            fi
        else
            # Check for legacy commands
            if [[ -n "${LEGACY_CMD_MAPPING[$arg]:-}" ]]; then
                local mapped="${LEGACY_CMD_MAPPING[$arg]}"
                log_debug "Mapping legacy command: $arg -> $mapped"

                # Split mapped command if it contains spaces
                if [[ "$mapped" == *" "* ]]; then
                    read -ra mapped_parts <<< "$mapped"
                    new_args+=("${mapped_parts[@]}")
                else
                    new_args+=("$mapped")
                fi
            else
                # Pass through unrecognized arguments
                new_args+=("$arg")
            fi
        fi

        ((i++))
    done

    # Output the new arguments
    printf '%s\n' "${new_args[@]}"
}

# Show deprecation warning
show_deprecation_warning() {
    local legacy_feature="$1"
    local replacement="${2:-}"
    local version="${3:-2.0.0}"

    if [[ "$FUB_LEGACY_MODE" != "true" ]]; then
        print_warning "DEPRECATION WARNING: '$legacy_feature' is deprecated and will be removed in FUB $version"

        if [[ -n "$replacement" ]]; then
            print_info "Please use '$replacement' instead"
        fi

        echo ""
    fi
}

# Legacy output formatter for script compatibility
format_legacy_output() {
    local output_type="$1"
    local data="$2"

    case "$output_type" in
        "cleanup_summary")
            format_legacy_cleanup_summary "$data"
            ;;
        "system_info")
            format_legacy_system_info "$data"
            ;;
        "package_info")
            format_legacy_package_info "$data"
            ;;
        "service_status")
            format_legacy_service_status "$data"
            ;;
        "error")
            format_legacy_error "$data"
            ;;
        *)
            echo "$data"
            ;;
    esac
}

# Format cleanup summary in legacy format
format_legacy_cleanup_summary() {
    local data="$1"

    # Parse data (expecting format: "files_removed:123,space_freed:456789")
    local files_removed=$(echo "$data" | grep -o 'files_removed:[0-9]*' | cut -d: -f2)
    local space_freed=$(echo "$data" | grep -o 'space_freed:[0-9]*' | cut -d: -f2)

    echo "Cleanup Summary:"
    echo "  Files removed: ${files_removed:-0}"
    echo "  Space freed: ${space_freed:-0} bytes"
}

# Format system info in legacy format
format_legacy_system_info() {
    local data="$1"

    echo "System Information:"
    echo "$data" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo "  $line"
        fi
    done
}

# Format package info in legacy format
format_legacy_package_info() {
    local data="$1"

    echo "Package Information:"
    echo "$data" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo "  $line"
        fi
    done
}

# Format service status in legacy format
format_legacy_service_status() {
    local data="$1"

    echo "Service Status:"
    echo "$data" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo "  $line"
        fi
    done
}

# Format error in legacy format
format_legacy_error() {
    local data="$1"

    echo "ERROR: $data" >&2
}

# Legacy exit code handler
handle_legacy_exit() {
    local exit_code="$1"
    local message="${2:-}"

    if [[ "$FUB_LEGACY_EXIT_CODES" == "true" ]] && [[ "$FUB_LEGACY_MODE" == "true" ]]; then
        case "$exit_code" in
            0) exit $LEGACY_EXIT_SUCCESS ;;
            1)
                [[ -n "$message" ]] && echo "WARNING: $message" >&2
                exit $LEGACY_EXIT_WARNING
                ;;
            2)
                [[ -n "$message" ]] && echo "ERROR: $message" >&2
                exit $LEGACY_EXIT_ERROR
                ;;
            3)
                [[ -n "$message" ]] && echo "CRITICAL: $message" >&2
                exit $LEGACY_EXIT_CRITICAL
                ;;
            *)
                exit "$exit_code"
                ;;
        esac
    else
        exit "$exit_code"
    fi
}

# Check for legacy configuration files
detect_legacy_config() {
    local -a legacy_configs=(
        "${HOME}/.fubrc"
        "${HOME}/.config/fub/config"
        "${HOME}/.fub/config"
        "/etc/fub/config"
        "/etc/fub.conf"
    )

    for config in "${legacy_configs[@]}"; do
        if [[ -f "$config" ]]; then
            echo "$config"
            return 0
        fi
    done

    return 1
}

# Migrate legacy configuration to new format
migrate_legacy_config() {
    local legacy_config="$1"
    local new_config="${2:-${FUB_CONFIG_FILE}}"

    if [[ ! -f "$legacy_config" ]]; then
        log_error "Legacy configuration file not found: $legacy_config"
        return 1
    fi

    log_info "Migrating legacy configuration from $legacy_config to $new_config"

    # Backup new config if it exists
    if [[ -f "$new_config" ]]; then
        local backup_file="${new_config}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$new_config" "$backup_file"
        log_info "Backed up existing configuration to $backup_file"
    fi

    # Create new config directory if needed
    local config_dir
    config_dir="$(dirname "$new_config")"
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"
    fi

    # Read legacy config and convert to new format
    {
        echo "# Migrated from legacy configuration: $legacy_config"
        echo "# Migration date: $(date)"
        echo ""

        # Parse legacy config
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue

            # Parse key=value pairs
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"

                # Remove quotes if present
                value="${value%\"}"
                value="${value#\"}"
                value="${value%\'}"
                value="${value#\'}"

                # Map legacy keys to new structure
                case "$key" in
                    CLEANUP_RETENTION_DAYS)
                        echo "cleanup_retention: $value"
                        ;;
                    CLEANUP_VERBOSE)
                        echo "ui:"
                        echo "  verbose: $value"
                        ;;
                    CLEANUP_DRY_RUN)
                        echo "system:"
                        echo "  dry_run: $value"
                        ;;
                    FUB_THEME)
                        echo "theme: $value"
                        ;;
                    FUB_LOG_LEVEL)
                        echo "logging:"
                        echo "  level: $value"
                        ;;
                    *)
                        # Unknown key, add as is with comment
                        echo "# Legacy configuration (may need manual migration)"
                        echo "$key: $value"
                        ;;
                esac
            else
                # Unparseable line, add as comment
                echo "# Unparsed legacy configuration: $line"
            fi
        done < "$legacy_config"

    } > "$new_config"

    log_info "Legacy configuration migrated successfully"
    return 0
}

# Validate legacy script compatibility
validate_legacy_script() {
    local script_path="$1"

    log_debug "Validating legacy script compatibility: $script_path"

    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi

    # Check for common legacy patterns
    local -a deprecated_patterns=(
        "fub --clean"
        "fub --purge"
        "fub --temp"
        "fub --cache"
        "fub --logs"
        "fub --all"
        "fub clean"
        "fub purge"
        "fub temp"
        "fub cache"
        "fub logs"
        "fub all"
    )

    local warnings_found=0

    for pattern in "${deprecated_patterns[@]}"; do
        if grep -q "$pattern" "$script_path" 2>/dev/null; then
            print_warning "Found deprecated pattern in $script_path: $pattern"
            ((warnings_found++))
        fi
    done

    if [[ $warnings_found -gt 0 ]]; then
        print_info "Run 'fub migrate-script $script_path' to update the script"
        return 1
    else
        print_success "Script appears compatible with new FUB version"
        return 0
    fi
}

# Export legacy compatibility functions
export -f init_legacy_compatibility parse_legacy_args
export -f show_deprecation_warning format_legacy_output
export -f handle_legacy_exit detect_legacy_config migrate_legacy_config
export -f validate_legacy_script

# Initialize legacy compatibility if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_legacy_compatibility
    log_debug "FUB legacy compatibility module loaded"
fi