#!/usr/bin/env bash

# FUB Profile-Based Scheduling Library
# Handles different scheduling profiles for various use cases

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Source systemd integration
source "${FUB_ROOT_DIR}/lib/scheduler/systemd-integration.sh"

# Profile constants
readonly FUB_PROFILE_CONFIG_DIR="${FUB_CONFIG_DIR}/profiles"
readonly FUB_PROFILE_USER_DIR="${HOME}/.config/fub/profiles"
readonly FUB_PROFILES_DB="${HOME}/.local/share/fub/profiles.db"

# Profile state
FUB_PROFILE_CURRENT=""
FUB_PROFILES_LOADED=false

# Default profile configurations
declare -A FUB_DEFAULT_PROFILES
FUB_DEFAULT_PROFILES[desktop]="
name: desktop
description: Desktop user profile with evening cleanup and notifications
schedule: daily 18:00
operations:
  - temp
  - cache
  - thumbnails
notifications: true
log_level: INFO
resource_limits:
  memory: 512M
  cpu: 50%
conditions:
  - on_ac_power: true
  - idle_time: 300
"

FUB_DEFAULT_PROFILES[server]="
name: server
description: Server profile with off-peak scheduling and minimal resource usage
schedule: daily 02:00
operations:
  - temp
  - cache
  - logs
notifications: false
log_level: WARN
resource_limits:
  memory: 256M
  cpu: 30%
conditions:
  - system_load: < 0.8
"

FUB_DEFAULT_PROFILES[developer]="
name: developer
description: Developer profile with frequent cache cleanup and development-aware scheduling
schedule: hourly
operations:
  - temp
  - build_cache
  - npm_cache
  - docker_cache
notifications: true
log_level: INFO
resource_limits:
  memory: 1G
  cpu: 60%
conditions:
  - no_git_operations: true
  - no_active_compilation: true
"

FUB_DEFAULT_PROFILES[minimal]="
name: minimal
description: Minimal profile with essential cleanup only
schedule: weekly
operations:
  - temp
notifications: false
log_level: ERROR
resource_limits:
  memory: 128M
  cpu: 20%
"

# Initialize profiles system
init_profiles() {
    if [[ "$FUB_PROFILES_LOADED" == true ]]; then
        return 0
    fi

    log_debug "Initializing profiles system"

    # Create profile directories
    mkdir -p "$FUB_PROFILE_CONFIG_DIR"
    mkdir -p "$FUB_PROFILE_USER_DIR"
    mkdir -p "$(dirname "$FUB_PROFILES_DB")"

    # Initialize profiles database
    if [[ ! -f "$FUB_PROFILES_DB" ]]; then
        touch "$FUB_PROFILES_DB"
        log_debug "Created profiles database: $FUB_PROFILES_DB"
    fi

    # Create default profile files if they don't exist
    create_default_profile_files

    FUB_PROFILES_LOADED=true
    log_debug "Profiles system initialized"
}

# Create default profile configuration files
create_default_profile_files() {
    local profile_name

    for profile_name in "${!FUB_DEFAULT_PROFILES[@]}"; do
        local profile_file="${FUB_PROFILE_CONFIG_DIR}/${profile_name}.yaml"

        if [[ ! -f "$profile_file" ]]; then
            echo "${FUB_DEFAULT_PROFILES[$profile_name]}" > "$profile_file"
            log_debug "Created default profile: $profile_name"
        fi
    done
}

# Load profile configuration
load_profile() {
    local profile_name="$1"
    local profile_file

    # Look in user directory first, then system directory
    profile_file="${FUB_PROFILE_USER_DIR}/${profile_name}.yaml"
    if [[ ! -f "$profile_file" ]]; then
        profile_file="${FUB_PROFILE_CONFIG_DIR}/${profile_name}.yaml"
    fi

    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile not found: $profile_name"
        return 1
    fi

    log_debug "Loading profile: $profile_name"

    # For now, use simple key-value parsing (could be enhanced with YAML parser)
    # This is a simplified implementation
    export FUB_CURRENT_PROFILE_NAME="$profile_name"
    export FUB_CURRENT_PROFILE_FILE="$profile_file"

    FUB_PROFILE_CURRENT="$profile_name"
    return 0
}

# Get profile property
get_profile_property() {
    local profile_name="$1"
    local property="$2"
    local profile_file

    # Find profile file
    profile_file="${FUB_PROFILE_USER_DIR}/${profile_name}.yaml"
    if [[ ! -f "$profile_file" ]]; then
        profile_file="${FUB_PROFILE_CONFIG_DIR}/${profile_name}.yaml"
    fi

    if [[ ! -f "$profile_file" ]]; then
        echo ""
        return 1
    fi

    # Simple YAML-like parsing (basic implementation)
    case "$property" in
        "name")
            grep "^name:" "$profile_file" | cut -d' ' -f2- | tr -d '"' || echo "$profile_name"
            ;;
        "description")
            grep "^description:" "$profile_file" | cut -d' ' -f2- | tr -d '"' || echo "No description"
            ;;
        "schedule")
            grep "^schedule:" "$profile_file" | cut -d' ' -f2- | tr -d '"' || echo "daily"
            ;;
        "operations")
            grep -A 10 "^operations:" "$profile_file" | grep "^  - " | cut -d' ' -f3- || echo ""
            ;;
        "notifications")
            grep "^notifications:" "$profile_file" | cut -d' ' -f2- | tr -d '"' || echo "true"
            ;;
        "log_level")
            grep "^log_level:" "$profile_file" | cut -d' ' -f2- | tr -d '"' || echo "INFO"
            ;;
        *)
            log_warn "Unknown profile property: $property"
            echo ""
            return 1
            ;;
    esac
}

# List available profiles
list_profiles() {
    log_info "Available FUB profiles:"

    local profiles=()
    local profile_file

    # Collect profiles from system directory
    for profile_file in "${FUB_PROFILE_CONFIG_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    # Collect profiles from user directory (override system ones)
    for profile_file in "${FUB_PROFILE_USER_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            if [[ ! " ${profiles[*]} " =~ " $profile_name " ]]; then
                profiles+=("$profile_name")
            fi
        fi
    done

    # Display profiles
    for profile_name in "${profiles[@]}"; do
        local description
        description=$(get_profile_property "$profile_name" "description")
        local schedule
        schedule=$(get_profile_property "$profile_name" "schedule")
        local active_indicator=""

        # Check if profile is currently active
        if systemctl --user is-active --quiet "fub-${profile_name}.timer" 2>/dev/null; then
            active_indicator=" [ACTIVE]"
        fi

        printf "  %-12s %s\n" "$profile_name$active_indicator" "$description"
        printf "  %-12s Schedule: %s\n" "" "$schedule"
        echo ""
    done
}

# Create custom profile
create_profile() {
    local profile_name="$1"
    local description="$2"
    local schedule="${3:-daily}"
    local operations="${4:-temp cache}"

    log_info "Creating custom profile: $profile_name"

    if [[ -z "$profile_name" ]]; then
        log_error "Profile name is required"
        return 1
    fi

    # Validate profile name
    if [[ ! "$profile_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Profile name must contain only alphanumeric characters, hyphens, and underscores"
        return 1
    fi

    local profile_file="${FUB_PROFILE_USER_DIR}/${profile_name}.yaml"

    if [[ -f "$profile_file" ]]; then
        log_error "Profile already exists: $profile_name"
        return 1
    fi

    # Create profile file
    cat > "$profile_file" << EOF
name: $profile_name
description: $description
schedule: $schedule
operations:
$(echo "$operations" | tr ' ' '\n' | sed 's/^/  - /')
notifications: true
log_level: INFO
resource_limits:
  memory: 512M
  cpu: 50%
conditions: []
EOF

    log_info "Created profile: $profile_file"
}

# Delete custom profile
delete_profile() {
    local profile_name="$1"

    log_info "Deleting custom profile: $profile_name"

    # Don't allow deleting default profiles
    if [[ -f "${FUB_PROFILE_CONFIG_DIR}/${profile_name}.yaml" ]]; then
        log_error "Cannot delete default profile: $profile_name"
        return 1
    fi

    local profile_file="${FUB_PROFILE_USER_DIR}/${profile_name}.yaml"

    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile not found: $profile_name"
        return 1
    fi

    # Check if profile is active
    if systemctl --user is-active --quiet "fub-${profile_name}.timer" 2>/dev/null; then
        log_warn "Profile '$profile_name' is currently active. Deactivating first..."
        uninstall_systemd_timer "$profile_name"
    fi

    rm -f "$profile_file"
    log_info "Deleted profile: $profile_name"
}

# Activate profile
activate_profile() {
    local profile_name="$1"

    log_info "Activating profile: $profile_name"

    init_profiles

    # Load profile
    if ! load_profile "$profile_name"; then
        return 1
    }

    # Get profile properties
    local schedule
    schedule=$(get_profile_property "$profile_name" "schedule")
    local operations
    operations=$(get_profile_property "$profile_name" "operations")
    local log_level
    log_level=$(get_profile_property "$profile_name" "log_level")

    if [[ -z "$schedule" ]]; then
        log_error "Profile '$profile_name' has no schedule defined"
        return 1
    fi

    # Build command with operations
    local command="${FUB_ROOT_DIR}/bin/fub --non-interactive --log-level=$log_level cleanup"
    for operation in $operations; do
        command="$command $operation"
    done

    # Install systemd timer
    if install_systemd_timer "$profile_name" "$schedule" "$command"; then
        # Record activation in database
        record_profile_activation "$profile_name"
        log_info "Profile '$profile_name' activated successfully"
    else
        log_error "Failed to activate profile: $profile_name"
        return 1
    fi
}

# Deactivate profile
deactivate_profile() {
    local profile_name="$1"

    log_info "Deactivating profile: $profile_name"

    if uninstall_systemd_timer "$profile_name"; then
        # Record deactivation in database
        record_profile_deactivation "$profile_name"
        log_info "Profile '$profile_name' deactivated successfully"
    else
        log_error "Failed to deactivate profile: $profile_name"
        return 1
    fi
}

# Get active profiles
get_active_profiles() {
    local active_profiles=()

    # Check systemd timers
    while IFS= read -r timer; do
        if [[ "$timer" == "${FUB_SYSTEMD_TIMER_PREFIX}"* && "$timer" == *.timer ]]; then
            local profile_name
            profile_name=$(echo "$timer" | sed "s/${FUB_SYSTEMD_TIMER_PREFIX}//" | sed 's/\.timer$//')

            if systemctl --user is-active --quiet "$timer" 2>/dev/null; then
                active_profiles+=("$profile_name")
            fi
        fi
    done < <(systemctl --user list-timers --all 2>/dev/null | awk '{print $2}' || true)

    echo "${active_profiles[@]}"
}

# Get profile status
get_profile_status() {
    local profile_name="$1"

    echo "Profile Status: $profile_name"
    echo "=========================="

    # Check if profile exists
    if ! get_profile_property "$profile_name" "name" >/dev/null; then
        echo "Status: Profile not found"
        return 1
    fi

    # Check if active
    if systemctl --user is-active --quiet "fub-${profile_name}.timer" 2>/dev/null; then
        echo "Status: Active"
        echo "Timer Status: Running"

        # Show next run time
        local next_run
        next_run=$(systemctl --user show "fub-${profile_name}.timer" -p NextElapseUSecMonotonic --value 2>/dev/null || echo "Unknown")
        echo "Next Run: $next_run"

        # Show last run status
        local last_status
        last_status=$(systemctl --user is-failed --quiet "fub-${profile_name}.service" 2>/dev/null && echo "Failed" || echo "Success")
        echo "Last Run: $last_status"
    else
        echo "Status: Inactive"
        echo "Timer Status: Not running"
    fi

    # Show profile configuration
    echo ""
    echo "Configuration:"
    echo "  Description: $(get_profile_property "$profile_name" "description")"
    echo "  Schedule: $(get_profile_property "$profile_name" "schedule")"
    echo "  Operations: $(get_profile_property "$profile_name" "operations")"
    echo "  Notifications: $(get_profile_property "$profile_name" "notifications")"
    echo "  Log Level: $(get_profile_property "$profile_name" "log_level")"
}

# Record profile activation in database
record_profile_activation() {
    local profile_name="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "$timestamp,ACTIVATE,$profile_name" >> "$FUB_PROFILES_DB"
}

# Record profile deactivation in database
record_profile_deactivation() {
    local profile_name="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "$timestamp,DEACTIVATE,$profile_name" >> "$FUB_PROFILES_DB"
}

# Get profile history
get_profile_history() {
    local profile_name="${1:-}"
    local limit="${2:-20}"

    if [[ -f "$FUB_PROFILES_DB" ]]; then
        if [[ -n "$profile_name" ]]; then
            grep ",$profile_name$" "$FUB_PROFILES_DB" | tail -n "$limit"
        else
            tail -n "$limit" "$FUB_PROFILES_DB"
        fi
    fi
}

# Detect system type and suggest profile
suggest_profile() {
    log_info "Analyzing system to suggest appropriate profile..."

    local suggestions=()
    local system_type=""

    # Check for desktop environment
    if [[ -n "${DESKTOP_SESSION:-}" || -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        suggestions+=("desktop")
        system_type="Desktop"
    fi

    # Check for server characteristics
    if [[ -z "${DESKTOP_SESSION:-}" && -z "${XDG_CURRENT_DESKTOP:-}" ]]; then
        suggestions+=("server")
        system_type="Server"
    fi

    # Check for development tools
    if command -v git >/dev/null 2>&1 || \
       command -v node >/dev/null 2>&1 || \
       command -v docker >/dev/null 2>&1 || \
       [[ -d "/home/${USER}/projects" || -d "/home/${USER}/dev" ]]; then
        suggestions+=("developer")
        if [[ -z "$system_type" ]]; then
            system_type="Development"
        fi
    fi

    # Check system resources
    local total_memory
    total_memory=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/[A-Za-z]//g' 2>/dev/null || echo "unknown")

    # Convert to number (simplified)
    local memory_gb
    memory_gb=$(echo "$total_memory" | sed 's/G//' | sed 's/M//g' | awk '{printf "%.0f", $1/1024}' 2>/dev/null || echo "unknown")

    echo "System Analysis:"
    echo "  Type: $system_type"
    echo "  Total Memory: ${total_memory}"

    if [[ $memory_gb -lt 2 ]]; then
        suggestions+=("minimal")
        echo "  Note: Low memory detected, minimal profile recommended"
    fi

    echo ""
    echo "Recommended Profiles:"
    for suggestion in "${suggestions[@]}"; do
        local description
        description=$(get_profile_property "$suggestion" "description")
        echo "  - $suggestion: $description"
    done
}

# Export functions
export -f init_profiles
export -f load_profile
export -f get_profile_property
export -f list_profiles
export -f create_profile
export -f delete_profile
export -f activate_profile
export -f deactivate_profile
export -f get_active_profiles
export -f get_profile_status
export -f record_profile_activation
export -f record_profile_deactivation
export -f get_profile_history
export -f suggest_profile