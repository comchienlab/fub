#!/usr/bin/env bash

# FUB Legacy Mode Implementation
# Provides script compatibility and legacy output formats

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/ui.sh"
source "${FUB_ROOT_DIR}/lib/legacy/compatibility.sh"

# Legacy mode configuration
readonly FUB_LEGACY_MODE_ENABLED="${FUB_LEGACY_MODE:-false}"
readonly FUB_LEGACY_OUTPUT_FORMAT="${FUB_LEGACY_OUTPUT_FORMAT:-text}"
readonly FUB_LEGACY_COLORS="${FUB_LEGACY_COLORS:-false}"
readonly FUB_LEGACY_PROGRESS="${FUB_LEGACY_PROGRESS:-simple}"
readonly FUB_LEGACY_CONFIRMATION="${FUB_LEGACY_CONFIRMATION:-auto}"

# Legacy mode state variables
FUB_LEGACY_ACTIVE=false
FUB_LEGACY_QUIET=false
FUB_LEGACY_VERBATIM=false

# Initialize legacy mode
init_legacy_mode() {
    log_debug "Initializing legacy mode"

    # Check if legacy mode should be enabled
    if [[ "$FUB_LEGACY_MODE_ENABLED" == "true" ]] || \
       [[ "${1:-}" == "--legacy-mode" ]] || \
       [[ "${FUB_NON_INTERACTIVE:-}" == "true" ]] || \
       [[ ! -t 0 ]] || \
       [[ "${TERM:-}" == "dumb" ]]; then

        FUB_LEGACY_ACTIVE=true
        log_info "Legacy mode activated"

        # Configure environment for legacy mode
        export FUB_INTERACTIVE=false
        export FUB_COLORS="$FUB_LEGACY_COLORS"
        export FUB_OUTPUT_FORMAT="$FUB_LEGACY_OUTPUT_FORMAT"

        # Override UI functions for legacy compatibility
        override_ui_functions
    fi

    log_debug "Legacy mode initialization complete (active: $FUB_LEGACY_ACTIVE)"
}

# Override UI functions for legacy compatibility
override_ui_functions() {
    # Override print functions to use simple text output
    print_header() { echo "=== $1 ==="; }
    print_section() { echo "-- $1 --"; }
    print_success() { echo "SUCCESS: $1"; }
    print_warning() { echo "WARNING: $1" >&2; }
    print_error() { echo "ERROR: $1" >&2; }
    print_info() { echo "INFO: $1"; }
    print_bullet() { echo "• $1"; }
    print_indented() { local indent="$1"; shift; printf "%*s%s\n" "$indent" "" "$*"; }

    # Override progress indicators for simple text output
    show_progress() {
        local current="$1"
        local total="$2"
        local message="${3:-Processing}"

        if [[ "$FUB_LEGACY_PROGRESS" == "simple" ]]; then
            local percentage=$((current * 100 / total))
            echo "${message}: ${percentage}% (${current}/${total})"
        elif [[ "$FUB_LEGACY_PROGRESS" == "dots" ]]; then
            echo -n "."
            if [[ $current -eq $total ]]; then
                echo " ${message} complete"
            fi
        fi
    }

    # Override spinner for simple output
    show_spinner() {
        local message="$1"
        local pid="$2"

        if wait "$pid"; then
            echo "${message}: Done"
            return 0
        else
            echo "${message}: Failed"
            return 1
        fi
    }

    # Override confirmation for automatic approval
    ask_confirmation() {
        local message="$1"

        case "$FUB_LEGACY_CONFIRMATION" in
            "auto")
                echo "$message: Auto-approved in legacy mode"
                return 0
                ;;
            "always")
                return 0
                ;;
            "never")
                return 1
                ;;
            *)
                # Fallback to simple yes/no prompt
                echo -n "$message [y/N]: "
                local response
                read -r response
                [[ "$response" =~ ^[Yy] ]]
                ;;
        esac
    }

    # Override table formatting for simple text
    print_table() {
        local -n data_ref=$1
        local headers="$2"

        echo "$headers"
        echo "----------------------------------------"

        for line in "${data_ref[@]}"; do
            echo "$line"
        done
    }

    # Override status formatting
    format_status() {
        local status="$1"
        local message="$2"

        case "$status" in
            "success"|"ok") echo "✓ $message" ;;
            "warning") echo "⚠ $message" ;;
            "error"|"failed") echo "✗ $message" ;;
            "info") echo "ℹ $message" ;;
            *) echo "$message" ;;
        esac
    }
}

# Legacy command wrapper
execute_legacy_command() {
    local original_command="$1"
    shift
    local args=("$@")

    # Initialize legacy mode if not already active
    if [[ "$FUB_LEGACY_ACTIVE" != "true" ]]; then
        init_legacy_mode --legacy-mode
    fi

    # Map legacy commands to new ones
    local mapped_command
    mapped_command=$(map_legacy_command "$original_command")

    if [[ "$mapped_command" != "$original_command" ]]; then
        show_deprecation_warning "$original_command" "$mapped_command"
    fi

    # Execute the mapped command with legacy context
    log_debug "Executing legacy command: $original_command -> $mapped_command"

    # Set up legacy execution context
    local old_interactive="${FUB_INTERACTIVE:-false}"
    local old_colors="${FUB_COLORS:-true}"
    export FUB_INTERACTIVE=false
    export FUB_COLORS="$FUB_LEGACY_COLORS"

    # Execute the command
    local exit_code=0
    "$mapped_command" "${args[@]}" || exit_code=$?

    # Restore original context
    export FUB_INTERACTIVE="$old_interactive"
    export FUB_COLORS="$old_colors"

    # Handle legacy exit codes
    handle_legacy_exit "$exit_code"
}

# Map legacy commands to new ones
map_legacy_command() {
    local command="$1"

    case "$command" in
        # Cleanup commands
        "clean"|"--clean") echo "cleanup" ;;
        "temp"|"--temp") echo "cleanup temp" ;;
        "cache"|"--cache") echo "cleanup cache" ;;
        "logs"|"--logs") echo "cleanup logs" ;;
        "packages"|"--packages") echo "cleanup packages" ;;
        "thumbnails"|"--thumbnails") echo "cleanup thumbnails" ;;
        "all"|"--all") echo "cleanup all" ;;

        # System commands
        "update") echo "system update" ;;
        "upgrade") echo "system upgrade" ;;
        "status") echo "system status" ;;
        "info") echo "system info" ;;

        # Package commands
        "install") echo "package install" ;;
        "remove") echo "package remove" ;;
        "search") echo "package search" ;;

        # Service commands
        "start") echo "service start" ;;
        "stop") echo "service stop" ;;
        "restart") echo "service restart" ;;

        # Network commands
        "test") echo "network test" ;;
        "speed") echo "network speed" ;;

        # Security commands
        "scan") echo "security scan" ;;
        "audit") echo "security audit" ;;

        # Monitoring commands
        "monitor") echo "monitoring" ;;
        "performance") echo "performance" ;;

        # Pass through unknown commands
        *) echo "$command" ;;
    esac
}

# Legacy output formatter
format_legacy_output() {
    local output_type="$1"
    shift
    local data=("$@")

    case "$FUB_LEGACY_OUTPUT_FORMAT" in
        "text")
            format_legacy_text_output "$output_type" "${data[@]}"
            ;;
        "json")
            format_legacy_json_output "$output_type" "${data[@]}"
            ;;
        "csv")
            format_legacy_csv_output "$output_type" "${data[@]}"
            ;;
        *)
            format_legacy_text_output "$output_type" "${data[@]}"
            ;;
    esac
}

# Format output as plain text (legacy default)
format_legacy_text_output() {
    local output_type="$1"
    shift
    local data=("$@")

    case "$output_type" in
        "cleanup")
            echo "Cleanup Results:"
            for item in "${data[@]}"; do
                echo "  $item"
            done
            ;;
        "system")
            echo "System Information:"
            for item in "${data[@]}"; do
                echo "  $item"
            done
            ;;
        "package")
            echo "Package Information:"
            for item in "${data[@]}"; do
                echo "  $item"
            done
            ;;
        "error")
            echo "ERROR: ${data[*]}" >&2
            ;;
        *)
            for item in "${data[@]}"; do
                echo "$item"
            done
            ;;
    esac
}

# Format output as JSON (for script parsing)
format_legacy_json_output() {
    local output_type="$1"
    shift
    local data=("$@")

    echo "{"
    echo "  \"type\": \"$output_type\","
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"data\": ["

    local first=true
    for item in "${data[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo ","
        fi
        echo "    \"$(echo "$item" | sed 's/"/\\"/g')\""
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Format output as CSV (for spreadsheet import)
format_legacy_csv_output() {
    local output_type="$1"
    shift
    local data=("$@")

    echo "timestamp,type,item"
    local timestamp
    timestamp=$(date -Iseconds)

    for item in "${data[@]}"; do
        echo "\"$timestamp\",\"$output_type\",\"$(echo "$item" | sed 's/"/""/g')\""
    done
}

# Legacy script execution wrapper
execute_legacy_script() {
    local script_path="$1"
    shift
    local script_args=("$@")

    if [[ ! -f "$script_path" ]]; then
        echo "ERROR: Script not found: $script_path" >&2
        exit $LEGACY_EXIT_NOINPUT
    fi

    # Set up legacy environment for script execution
    export FUB_LEGACY_MODE=true
    export FUB_INTERACTIVE=false
    export FUB_COLORS="$FUB_LEGACY_COLORS"
    export FUB_OUTPUT_FORMAT="$FUB_LEGACY_OUTPUT_FORMAT"

    # Make script executable if needed
    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path"
    fi

    # Execute script with legacy environment
    log_debug "Executing legacy script: $script_path ${script_args[*]}"

    # Create temporary wrapper for legacy command handling
    local temp_wrapper
    temp_wrapper=$(mktemp)
    cat > "$temp_wrapper" << 'EOF'
#!/bin/bash
# Legacy script wrapper for FUB

# Override fub command for legacy compatibility
fub() {
    # Source legacy compatibility if not already loaded
    if [[ -z "${FUB_LEGACY_LOADED:-}" ]]; then
        source "${FUB_ROOT_DIR}/lib/legacy/legacy-mode.sh"
        export FUB_LEGACY_LOADED=true
    fi

    # Execute with legacy mode
    execute_legacy_command "$@"
}

# Execute the original script with our wrapper
EOF

    # Add script execution to wrapper
    echo "\"$script_path\" \"${script_args[@]}\"" >> "$temp_wrapper"

    # Make wrapper executable
    chmod +x "$temp_wrapper"

    # Execute wrapper and capture exit code
    local exit_code=0
    "$temp_wrapper" || exit_code=$?

    # Clean up temporary wrapper
    rm -f "$temp_wrapper"

    # Handle legacy exit codes
    handle_legacy_exit "$exit_code"
}

# Legacy performance characteristics
set_legacy_performance_mode() {
    local mode="${1:-compatible}"

    case "$mode" in
        "compatible")
            # Prioritize compatibility over performance
            export FUB_PARALLEL_OPERATIONS=false
            export FUB_CACHING=false
            export FUB_PROGRESS_INDICATORS=false
            ;;
        "balanced")
            # Balance compatibility and performance
            export FUB_PARALLEL_OPERATIONS=true
            export FUB_CACHING=true
            export FUB_PROGRESS_INDICATORS=false
            ;;
        "performance")
            # Prioritize performance (may affect compatibility)
            export FUB_PARALLEL_OPERATIONS=true
            export FUB_CACHING=true
            export FUB_PROGRESS_INDICATORS=true
            ;;
    esac

    log_debug "Legacy performance mode set to: $mode"
}

# Legacy error handling
handle_legacy_error() {
    local error_type="$1"
    local error_message="$2"
    local exit_code="${3:-$LEGACY_EXIT_ERROR}"

    case "$error_type" in
        "permission")
            echo "ERROR: Permission denied - $error_message" >&2
            exit $LEGACY_EXIT_NOPERM
            ;;
        "file_not_found")
            echo "ERROR: File not found - $error_message" >&2
            exit $LEGACY_EXIT_NOINPUT
            ;;
        "command_not_found")
            echo "ERROR: Command not found - $error_message" >&2
            exit $LEGACY_EXIT_UNAVAILABLE
            ;;
        "invalid_argument")
            echo "ERROR: Invalid argument - $error_message" >&2
            exit $LEGACY_EXIT_USAGE
            ;;
        "configuration")
            echo "ERROR: Configuration error - $error_message" >&2
            exit $LEGACY_EXIT_CONFIG
            ;;
        *)
            echo "ERROR: $error_message" >&2
            exit "$exit_code"
            ;;
    esac
}

# Export legacy mode functions
export -f init_legacy_mode execute_legacy_command map_legacy_command
export -f format_legacy_output format_legacy_text_output
export -f format_legacy_json_output format_legacy_csv_output
export -f execute_legacy_script set_legacy_performance_mode
export -f handle_legacy_error

# Initialize legacy mode if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_legacy_mode
    log_debug "FUB legacy mode module loaded"
fi