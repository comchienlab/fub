#!/usr/bin/env bash

# FUB Dependencies Cache System
# Caching and performance optimization for dependency operations

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/types/dependency.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/config.sh"

# Cache files
readonly DEPS_CACHE_STATUS_FILE="${DEPS_CACHE_DIR}/status.cache"
readonly DEPS_CACHE_VERSIONS_FILE="${DEPS_CACHE_DIR}/versions.cache"
readonly DEPS_CACHE_PLATFORM_FILE="${DEPS_CACHE_DIR}/platform.cache"
readonly DEPS_CACHE_INDEX_FILE="${DEPS_CACHE_DIR}/index.cache"

# Cache state
DEPS_CACHE_LOADED=false
DEPS_CACHE_VALID=false
DEPS_CACHE_PLATFORM_ID=""
DEPS_CACHE_LAST_UPDATE=0

# Initialize dependency cache system
init_deps_cache() {
    log_deps_debug "Initializing dependency cache system..."

    # Ensure cache directory exists
    ensure_dir "$DEPS_CACHE_DIR"

    # Load cache
    load_deps_cache

    # Validate cache
    validate_deps_cache

    DEPS_CACHE_LOADED=true
    log_deps_debug "Dependency cache system initialized"
}

# Load dependency cache from files
load_deps_cache() {
    log_deps_debug "Loading dependency cache..."

    # Load platform information
    if file_exists "$DEPS_CACHE_PLATFORM_FILE"; then
        DEPS_CACHE_PLATFORM_ID=$(cat "$DEPS_CACHE_PLATFORM_FILE")
        log_deps_debug "Cached platform ID: $DEPS_CACHE_PLATFORM_ID"
    else
        update_platform_cache
    fi

    # Check if cache is valid
    if is_deps_cache_valid && file_exists "$DEPS_CACHE_STATUS_FILE"; then
        load_status_cache
        DEPS_CACHE_VALID=true
        log_deps_debug "Dependency cache is valid and loaded"
    else
        log_deps_debug "Dependency cache is invalid or missing"
    fi
}

# Validate dependency cache
validate_deps_cache() {
    # Check if platform has changed
    local current_platform_id
    current_platform_id=$(get_platform_info | tr '|' '_')

    if [[ "$DEPS_CACHE_PLATFORM_ID" != "$current_platform_id" ]]; then
        log_deps_debug "Platform has changed, invalidating cache"
        invalidate_deps_cache
        DEPS_CACHE_PLATFORM_ID="$current_platform_id"
        update_platform_cache
    fi
}

# Update platform cache
update_platform_cache() {
    log_deps_debug "Updating platform cache..."
    echo "$DEPS_CACHE_PLATFORM_ID" > "$DEPS_CACHE_PLATFORM_FILE"
}

# Load tool status from cache
load_status_cache() {
    log_deps_debug "Loading tool status from cache..."

    if [[ ! -f "$DEPS_CACHE_STATUS_FILE" ]]; then
        log_deps_debug "Status cache file not found"
        return 1
    fi

    local line_num=0
    while IFS='|' read -r tool_name status version path install_method last_check; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "$tool_name" || "$tool_name" == "#" ]] && continue

        # Set tool status from cache
        update_tool_status "$tool_name" "$status" "$version" "$path" "$install_method" "$last_check"

    done < "$DEPS_CACHE_STATUS_FILE"

    log_deps_debug "Loaded status for $line_num tools from cache"
    return 0
}

# Save tool status to cache
save_status_cache() {
    log_deps_debug "Saving tool status to cache..."

    > "$DEPS_CACHE_STATUS_FILE" cat << EOF
# FUB Dependencies Status Cache
# Format: tool_name|status|version|path|install_method|last_check
# Generated: $(date)

EOF

    # Write status for all tools
    for ((i=0; i<DEPS_STATUS_count; i++)); do
        local tool_var="DEPS_STATUS_${i}_tool"
        local status_var="DEPS_STATUS_${i}_status"
        local version_var="DEPS_STATUS_${i}_version"
        local path_var="DEPS_STATUS_${i}_path"
        local method_var="DEPS_STATUS_${i}_install_method"
        local check_var="DEPS_STATUS_${i}_last_check"

        local tool_name="${!tool_var}"
        local status="${!status_var}"
        local version="${!version_var}"
        local path="${!path_var}"
        local install_method="${!method_var}"
        local last_check="${!check_var}"

        echo "$tool_name|$status|$version|$path|$install_method|$last_check" >> "$DEPS_CACHE_STATUS_FILE"
    done

    # Update cache timestamp
    DEPS_CACHE_LAST_UPDATE=$(date +%s)
    echo "$DEPS_CACHE_LAST_UPDATE" > "${DEPS_CACHE_DIR}/last_update"

    log_deps_debug "Tool status saved to cache"
}

# Invalidate dependency cache
invalidate_deps_cache() {
    log_deps_debug "Invalidating dependency cache..."

    # Remove cache files
    rm -f "$DEPS_CACHE_STATUS_FILE"
    rm -f "$DEPS_CACHE_VERSIONS_FILE"
    rm -f "$DEPS_CACHE_INDEX_FILE"

    # Reset cache state
    DEPS_CACHE_VALID=false
    DEPS_CACHE_LAST_UPDATE=0

    # Clear tool status data
    for ((i=0; i<DEPS_STATUS_count; i++)); do
        unset "DEPS_STATUS_${i}_tool"
        unset "DEPS_STATUS_${i}_status"
        unset "DEPS_STATUS_${i}_version"
        unset "DEPS_STATUS_${i}_path"
        unset "DEPS_STATUS_${i}_install_method"
        unset "DEPS_STATUS_${i}_last_check"
    done

    # Reset status count
    DEPS_STATUS_count=0

    log_deps_debug "Dependency cache invalidated"
}

# Check if cache is valid
is_cache_valid() {
    [[ "$DEPS_CACHE_VALID" == "true" ]] && is_deps_cache_valid
}

# Update tool status in cache
update_tool_cache() {
    local tool_name="$1"
    local status="$2"
    local version="${3:-}"
    local path="${4:-}"
    local install_method="${5:-}"

    # Update runtime status
    update_tool_status "$tool_name" "$status" "$version" "$path" "$install_method"

    # Save to cache file if cache is loaded
    if [[ "$DEPS_CACHE_LOADED" == "true" ]]; then
        save_status_cache
    fi

    log_deps_debug "Updated cache for tool: $tool_name = $status"
}

# Get cached tool status
get_cached_tool_status() {
    local tool_name="$1"

    if [[ "$DEPS_CACHE_LOADED" == "true" ]]; then
        get_tool_status "$tool_name"
    else
        echo "$DEPS_STATUS_UNKNOWN"
    fi
}

# Get cached tool version
get_cached_tool_version() {
    local tool_name="$1"

    if [[ "$DEPS_CACHE_LOADED" == "true" ]]; then
        get_tool_version "$tool_name"
    else
        echo ""
    fi
}

# Check if tool was recently checked
was_recently_checked() {
    local tool_name="$1"
    local max_age="${2:-3600}"  # Default 1 hour

    if [[ "$DEPS_CACHE_LOADED" != "true" ]]; then
        return 1
    fi

    local status_var="DEPS_STATUS_INDEX_${tool_name}"
    local status_index="${!status_var:--1}"

    if [[ $status_index -lt 0 ]]; then
        return 1
    fi

    local last_check_var="DEPS_STATUS_${status_index}_last_check"
    local last_check="${!last_check_var:-0}"

    local current_time=$(date +%s)
    local age=$((current_time - last_check))

    [[ $age -lt $max_age ]]
}

# Get cache statistics
get_cache_stats() {
    local total_tools=$DEPS_TOOL_count
    local cached_tools=$DEPS_STATUS_count
    local cache_age=0
    local cache_file_size=0

    if [[ -f "${DEPS_CACHE_DIR}/last_update" ]]; then
        local last_update
        last_update=$(cat "${DEPS_CACHE_DIR}/last_update")
        cache_age=$(($(date +%s) - last_update))
    fi

    if [[ -f "$DEPS_CACHE_STATUS_FILE" ]]; then
        cache_file_size=$(stat -f%z "$DEPS_CACHE_STATUS_FILE" 2>/dev/null || stat -c%s "$DEPS_CACHE_STATUS_FILE" 2>/dev/null || echo "0")
    fi

    echo "total_tools:$total_tools"
    echo "cached_tools:$cached_tools"
    echo "cache_age:$cache_age"
    echo "cache_file_size:$cache_file_size"
    echo "cache_valid:$DEPS_CACHE_VALID"
}

# Show cache information
show_cache_info() {
    local section="${1:-overview}"

    echo ""
    echo "${BOLD}${CYAN}FUB Dependencies Cache${RESET}"
    echo "========================="
    echo ""

    case "$section" in
        overview)
            echo "${YELLOW}Cache Overview:${RESET}"

            # Get statistics
            local stats
            stats=$(get_cache_stats)
            local total_tools=$(echo "$stats" | grep "total_tools:" | cut -d':' -f2)
            local cached_tools=$(echo "$stats" | grep "cached_tools:" | cut -d':' -f2)
            local cache_age=$(echo "$stats" | grep "cache_age:" | cut -d':' -f2)
            local cache_file_size=$(echo "$stats" | grep "cache_file_size:" | cut -d':' -f2)
            local cache_valid=$(echo "$stats" | grep "cache_valid:" | cut -d':' -f2)

            echo "  Total tools: $total_tools"
            echo "  Cached tools: $cached_tools"
            echo "  Cache valid: $( [[ "$cache_valid" == "true" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"

            if [[ $cache_age -gt 0 ]]; then
                local age_minutes=$((cache_age / 60))
                local age_hours=$((age_minutes / 60))
                echo "  Cache age: ${age_minutes} minutes (${age_hours} hours)"
            fi

            if [[ $cache_file_size -gt 0 ]]; then
                echo "  Cache size: $(numfmt --to=iec $cache_file_size 2>/dev/null || echo "${cache_file_size} bytes")"
            fi

            echo ""
            echo "${YELLOW}Cache Files:${RESET}"
            echo "  Status cache: $DEPS_CACHE_STATUS_FILE"
            echo "  Platform cache: $DEPS_CACHE_PLATFORM_FILE"
            echo "  Cache directory: $DEPS_CACHE_DIR"
            ;;
        status)
            echo "${YELLOW}Cached Tool Status:${RESET}"
            echo ""

            if [[ ! -f "$DEPS_CACHE_STATUS_FILE" ]]; then
                echo "  ${GRAY}No cache file found${RESET}"
                return 0
            fi

            printf "${GREEN}%-20s${RESET} ${CYAN}%-12s${RESET} ${YELLOW}%-15s${RESET} ${GRAY}%-10s${RESET}\n" \
                   "Tool" "Status" "Version" "Last Check"
            echo "--------------------------------------------------------------------------------"

            while IFS='|' read -r tool_name status version path install_method last_check; do
                [[ -z "$tool_name" || "$tool_name" == "#" ]] && continue

                local status_color=""
                case "$status" in
                    "$DEPS_STATUS_INSTALLED") status_color="$GREEN" ;;
                    "$DEPS_STATUS_OUTDATED") status_color="$YELLOW" ;;
                    "$DEPS_STATUS_NOT_INSTALLED") status_color="$RED" ;;
                    "$DEPS_STATUS_INCOMPATIBLE") status_color="$MAGENTA" ;;
                    *) status_color="$GRAY" ;;
                esac

                local check_time="Never"
                if [[ -n "$last_check" && "$last_check" != "0" ]]; then
                    check_time=$(date -d "@$last_check" "+%H:%M:%S" 2>/dev/null || date -r "$last_check" "+%H:%M:%S" 2>/dev/null || echo "$last_check")
                fi

                printf "${GREEN}%-20s${RESET} ${status_color}%-12s${RESET} ${YELLOW}%-15s${RESET} ${GRAY}%-10s${RESET}\n" \
                       "$tool_name" "$status" "${version:-N/A}" "$check_time"
            done < "$DEPS_CACHE_STATUS_FILE"
            ;;
        *)
            log_deps_error "Unknown cache section: $section"
            return 1
            ;;
    esac

    echo ""
}

# Clear cache
clear_cache() {
    local scope="${1:-all}"

    case "$scope" in
        all)
            log_deps_info "Clearing all dependency cache..."
            invalidate_deps_cache
            rm -f "${DEPS_CACHE_DIR}/last_update"
            ;;
        status)
            log_deps_info "Clearing status cache..."
            rm -f "$DEPS_CACHE_STATUS_FILE"
            DEPS_CACHE_VALID=false
            ;;
        platform)
            log_deps_info "Clearing platform cache..."
            rm -f "$DEPS_CACHE_PLATFORM_FILE"
            ;;
        *)
            log_deps_error "Unknown cache scope: $scope"
            return 1
            ;;
    esac

    log_deps_info "Cache cleared ($scope scope)"
}

# Refresh cache
refresh_cache() {
    log_deps_info "Refreshing dependency cache..."

    # Invalidate current cache
    invalidate_deps_cache

    # Update platform info
    update_platform_cache

    log_deps_info "Dependency cache refreshed"
}

# Export functions
export -f init_deps_cache load_deps_cache validate_deps_cache update_platform_cache
export -f load_status_cache save_status_cache invalidate_deps_cache is_cache_valid
export -f update_tool_cache get_cached_tool_status get_cached_tool_version was_recently_checked
export -f get_cache_stats show_cache_info clear_cache refresh_cache

log_deps_debug "Dependency cache system loaded"