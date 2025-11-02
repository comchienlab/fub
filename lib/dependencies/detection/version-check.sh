#!/usr/bin/env bash

# FUB Dependencies Version Checking and Compatibility
# Checks tool versions and validates compatibility requirements

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Version checking state
VERSION_CHECK_CACHE_FILE="${DEPS_CACHE_DIR}/versions.cache"
VERSION_UPDATE_CACHE_TTL=86400  # 24 hours

# Initialize version checking system
init_version_check_system() {
    log_deps_debug "Initializing version checking system..."

    # Ensure cache directory exists
    ensure_dir "$DEPS_CACHE_DIR"

    log_deps_debug "Version checking system initialized"
}

# Parse semantic version string
parse_semver() {
    local version="$1"
    local prefix="${2:-}"

    # Remove any prefix if specified
    if [[ -n "$prefix" && "$version" == "$prefix"* ]]; then
        version="${version#$prefix}"
    fi

    # Extract version components
    local major="0"
    local minor="0"
    local patch="0"

    if [[ "$version" =~ ^([0-9]+)(\.([0-9]+))?(\.([0-9]+))? ]]; then
        major="${BASH_REMATCH[1]:-0}"
        minor="${BASH_REMATCH[3]:-0}"
        patch="${BASH_REMATCH[5]:-0}"
    fi

    echo "$major:$minor:$patch"
}

# Compare semantic versions
compare_semver() {
    local version1="$1"
    local operator="$2"
    local version2="$3"

    local semver1 semver2

    # Parse versions
    semver1=$(parse_semver "$version1")
    semver2=$(parse_semver "$version2")

    local major1 minor1 patch1
    local major2 minor2 patch2

    IFS=':' read -r major1 minor1 patch1 <<< "$semver1"
    IFS=':' read -r major2 minor2 patch2 <<< "$semver2"

    # Compare versions
    case "$operator" in
        "=="|"=") [[ $major1 -eq $major2 && $minor1 -eq $minor2 && $patch1 -eq $patch2 ]] ;;
        "!=") [[ $major1 -ne $major2 || $minor1 -ne $minor2 || $patch1 -ne $patch2 ]] ;;
        ">") [[ $major1 -gt $major2 || ($major1 -eq $major2 && $minor1 -gt $minor2) || ($major1 -eq $major2 && $minor1 -eq $minor2 && $patch1 -gt $patch2) ]] ;;
        ">=") [[ $major1 -gt $major2 || ($major1 -eq $major2 && $minor1 -gt $minor2) || ($major1 -eq $major2 && $minor1 -eq $minor2 && $patch1 -ge $patch2) ]] ;;
        "<") [[ $major1 -lt $major2 || ($major1 -eq $major2 && $minor1 -lt $minor2) || ($major1 -eq $major2 && $minor1 -eq $minor2 && $patch1 -lt $patch2) ]] ;;
        "<=") [[ $major1 -lt $major2 || ($major1 -eq $major2 && $minor1 -lt $minor2) || ($major1 -eq $major2 && $minor1 -eq $minor2 && $patch1 -le $patch2) ]] ;;
        "~") [[ $major1 -eq $major2 && $minor1 -eq $minor2 && $patch1 -ge $patch2 ]] ;;  # ~1.2.3 means >=1.2.3 and <1.3.0
        "^") [[ $major1 -eq $major2 && ($minor1 -gt $minor2 || ($minor1 -eq $minor2 && $patch1 -ge $patch2)) ]] ;;  # ^1.2.3 means >=1.2.3 and <2.0.0
        *)
            log_deps_error "Invalid version operator: $operator"
            return 1
            ;;
    esac
}

# Get tool version with caching
get_cached_version() {
    local tool_name="$1"
    local executable="$2"
    local force_check="${3:-false}"

    local cache_key="${tool_name}_${executable}"
    local current_time=$(date +%s)

    # Check cache
    if [[ "$force_check" != "true" && -f "$VERSION_CHECK_CACHE_FILE" ]]; then
        local cached_time cached_version
        cached_time=$(grep "^${cache_key}:" "$VERSION_CHECK_CACHE_FILE" 2>/dev/null | cut -d':' -f2)
        cached_version=$(grep "^${cache_key}:" "$VERSION_CHECK_CACHE_FILE" 2>/dev/null | cut -d':' -f3-)

        if [[ -n "$cached_time" && -n "$cached_version" ]]; then
            local cache_age=$((current_time - cached_time))
            if [[ $cache_age -lt $VERSION_UPDATE_CACHE_TTL ]]; then
                echo "$cached_version"
                return 0
            fi
        fi
    fi

    # Get fresh version
    local version
    version=$(detect_tool_version "$tool_name" "$executable")

    # Update cache
    if [[ -n "$version" ]]; then
        update_version_cache "$cache_key" "$current_time" "$version"
    fi

    echo "$version"
}

# Update version cache
update_version_cache() {
    local cache_key="$1"
    local timestamp="$2"
    local version="$3"

    # Remove old entry if exists
    if [[ -f "$VERSION_CHECK_CACHE_FILE" ]]; then
        grep -v "^${cache_key}:" "$VERSION_CHECK_CACHE_FILE" > "${VERSION_CHECK_CACHE_FILE}.tmp"
        mv "${VERSION_CHECK_CACHE_FILE}.tmp" "$VERSION_CHECK_CACHE_FILE"
    fi

    # Add new entry
    echo "${cache_key}:${timestamp}:${version}" >> "$VERSION_CHECK_CACHE_FILE"

    log_deps_debug "Updated version cache: $cache_key = $version"
}

# Check tool version compatibility
check_tool_version_compatibility() {
    local tool_name="$1"
    local current_version="$2"

    log_deps_debug "Checking version compatibility for $tool_name: $current_version"

    # Get tool requirements
    local tool_index=$(find_tool_index "$tool_name")
    if [[ $tool_index -lt 0 ]]; then
        log_deps_error "Tool not found in registry: $tool_name"
        return 1
    fi

    local min_version=$(get_tool_min_version "$tool_index")
    local max_version=$(get_tool_max_version "$tool_index")

    # Check minimum version
    if [[ -n "$min_version" ]]; then
        if ! compare_semver "$current_version" ">=" "$min_version"; then
            log_deps_warn "$tool_name version $current_version is below minimum $min_version"
            return 1
        fi
    fi

    # Check maximum version
    if [[ -n "$max_version" ]]; then
        if ! compare_semver "$current_version" "<=" "$max_version"; then
            log_deps_warn "$tool_name version $current_version is above maximum $max_version"
            return 1
        fi
    fi

    log_deps_debug "$tool_name version $current_version is compatible"
    return 0
}

# Check for tool updates
check_tool_updates() {
    local tool_name="$1"
    local current_version="$2"
    local package_manager="$3"

    log_deps_debug "Checking for updates to $tool_name: $current_version"

    # This is a simplified implementation
    # In a real system, you would query package repositories for available versions

    local latest_version=""

    case "$package_manager" in
        "apt")
            if command_exists apt-cache; then
                local package_name
                package_name=$(get_package_name "$tool_name" "$package_manager")
                if [[ -n "$package_name" ]]; then
                    local policy_output
                    policy_output=$(apt-cache policy "$package_name" 2>/dev/null)
                    latest_version=$(echo "$policy_output" | grep "Candidate:" | head -1 | awk '{print $2}')
                fi
            fi
            ;;
        "snap")
            if command_exists snap; then
                local info_output
                info_output=$(snap info "$tool_name" 2>/dev/null)
                latest_version=$(echo "$info_output" | grep "tracking:" | head -1 | awk '{print $2}')
            fi
            ;;
        "brew")
            if command_exists brew; then
                local outdated_output
                outdated_output=$(brew outdated 2>/dev/null | grep "$tool_name")
                if [[ -n "$outdated_output" ]]; then
                    # Mark as outdated (we don't get the exact latest version easily)
                    echo "outdated"
                    return 0
                fi
            fi
            ;;
    esac

    if [[ -n "$latest_version" && "$latest_version" != "$current_version" ]]; then
        echo "$latest_version"
        return 0
    fi

    return 1
}

# Get version compatibility report
get_version_compatibility_report() {
    local tool_name="$1"

    local tool_index=$(find_tool_index "$tool_name")
    if [[ $tool_index -lt 0 ]]; then
        echo "error:tool not found"
        return 1
    fi

    local current_version=$(get_cached_tool_version "$tool_name")
    local min_version=$(get_tool_min_version "$tool_index")
    local max_version=$(get_tool_max_version "$tool_index")
    local status=$(get_cached_tool_status "$tool_name")

    echo "tool:$tool_name"
    echo "current_version:$current_version"
    echo "min_version:$min_version"
    echo "max_version:$max_version"
    echo "status:$status"

    # Check compatibility
    if [[ -n "$current_version" ]]; then
        if check_tool_version_compatibility "$tool_name" "$current_version"; then
            echo "compatible:true"
        else
            echo "compatible:false"
        fi

        # Check for updates
        local install_method=$(get_tool_path "$tool_name")
        if [[ -n "$install_method" ]]; then
            local package_manager
            package_manager=$(detect_install_method "$install_method")
            local update_version
            update_version=$(check_tool_updates "$tool_name" "$current_version" "$package_manager")
            if [[ -n "$update_version" ]]; then
                if [[ "$update_version" == "outdated" ]]; then
                    echo "update_available:true"
                    echo "update_version:unknown"
                else
                    echo "update_available:true"
                    echo "update_version:$update_version"
                fi
            else
                echo "update_available:false"
            fi
        fi
    else
        echo "compatible:unknown"
        echo "update_available:false"
    fi
}

# Show version compatibility report
show_version_compatibility_report() {
    local tool_name="${1:-}"

    if [[ -n "$tool_name" ]]; then
        # Show report for specific tool
        echo ""
        echo "${BOLD}${CYAN}Version Compatibility Report${RESET}"
        echo "==============================="
        echo ""

        if ! tool_exists "$tool_name"; then
            echo "${RED}Tool not found: $tool_name${RESET}"
            return 1
        fi

        local report
        report=$(get_version_compatibility_report "$tool_name")

        local current_version=$(echo "$report" | grep "current_version:" | cut -d':' -f2)
        local min_version=$(echo "$report" | grep "min_version:" | cut -d':' -f2)
        local max_version=$(echo "$report" | grep "max_version:" | cut -d':' -f2)
        local status=$(echo "$report" | grep "status:" | cut -d':' -f2)
        local compatible=$(echo "$report" | grep "compatible:" | cut -d':' -f2)
        local update_available=$(echo "$report" | grep "update_available:" | cut -d':' -f2)

        echo "${YELLOW}Tool:${RESET} $tool_name"
        echo "${YELLOW}Status:${RESET} $status"
        echo "${YELLOW}Current Version:${RESET} ${current_version:-Not detected}"

        if [[ -n "$min_version" ]]; then
            echo "${YELLOW}Minimum Version:${RESET} $min_version"
        fi

        if [[ -n "$max_version" ]]; then
            echo "${YELLOW}Maximum Version:${RESET} $max_version"
        fi

        # Compatibility status
        case "$compatible" in
            "true")
                echo "${GREEN}Compatibility:${RESET} ✅ Compatible"
                ;;
            "false")
                echo "${RED}Compatibility:${RESET} ❌ Incompatible"
                ;;
            "unknown")
                echo "${GRAY}Compatibility:${RESET} ❓ Unknown"
                ;;
        esac

        # Update availability
        case "$update_available" in
            "true")
                local update_version=$(echo "$report" | grep "update_version:" | cut -d':' -f2)
                if [[ "$update_version" != "unknown" ]]; then
                    echo "${YELLOW}Update Available:${RESET} $update_version"
                else
                    echo "${YELLOW}Update Available:${RESET} Yes"
                fi
                ;;
            "false")
                echo "${GREEN}Update Available:${RESET} No"
                ;;
        esac

    else
        # Show summary for all tools
        echo ""
        echo "${BOLD}${CYAN}Version Compatibility Summary${RESET}"
        echo "================================="
        echo ""

        local total_tools=0
        local compatible_tools=0
        local incompatible_tools=0
        local outdated_tools=0
        local unknown_tools=0

        ensure_registry_loaded

        printf "${GREEN}%-20s${RESET} ${CYAN}%-15s${RESET} ${YELLOW}%-12s${RESET} ${MAGENTA}%-10s${RESET}\n" \
               "Tool" "Version" "Compatible" "Update"
        echo "--------------------------------------------------------------------------------"

        for ((i=0; i<DEPS_TOOL_count; i++)); do
            local tool_name=$(get_tool_name "$i")
            local status=$(get_cached_tool_status "$tool_name")

            if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
                continue
            fi

            local report
            report=$(get_version_compatibility_report "$tool_name")

            local current_version=$(echo "$report" | grep "current_version:" | cut -d':' -f2)
            local compatible=$(echo "$report" | grep "compatible:" | cut -d':' -f2)
            local update_available=$(echo "$report" | grep "update_available:" | cut -d':' -f2)

            ((total_tools++))

            # Format version
            local version_display="${current_version:-N/A}"
            if [[ ${#version_display} -gt 15 ]]; then
                version_display="${version_display:0:12}..."
            fi

            # Format compatibility
            local compat_display="❓"
            local compat_color="$GRAY"
            case "$compatible" in
                "true") compat_display="✅"; compat_color="$GREEN" ;;
                "false") compat_display="❌"; compat_color="$RED" ;;
            esac

            # Format update status
            local update_display=""
            case "$update_available" in
                "true") update_display="${YELLOW}Update${RESET}" ;;
                "false") update_display="${GREEN}Current${RESET}" ;;
            esac

            printf "${GREEN}%-20s${RESET} ${CYAN}%-15s${RESET} ${compat_color}%-12s${RESET} ${MAGENTA}%-10s${RESET}\n" \
                   "$tool_name" "$version_display" "$compat_display" "$update_display"

            # Count categories
            case "$compatible" in
                "true") ((compatible_tools++)) ;;
                "false") ((incompatible_tools++)) ;;
                *) ((unknown_tools++)) ;;
            esac

            if [[ "$update_available" == "true" ]]; then
                ((outdated_tools++))
            fi
        done

        echo ""
        echo "${YELLOW}Summary:${RESET}"
        echo "  Total checked: $total_tools"
        echo "  ${GREEN}Compatible: $compatible_tools${RESET}"
        echo "  ${RED}Incompatible: $incompatible_tools${RESET}"
        echo "  ${YELLOW}Updates available: $outdated_tools${RESET}"
        echo "  ${GRAY}Unknown status: $unknown_tools${RESET}"
    fi

    echo ""
}

# Validate all tool versions
validate_all_tool_versions() {
    log_deps_info "Validating all tool versions..."

    ensure_registry_loaded

    local validation_errors=0
    local total_tools=0

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_name=$(get_tool_name "$i")
        local status=$(get_cached_tool_status "$tool_name")

        if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
            continue
        fi

        ((total_tools++))

        local current_version=$(get_cached_tool_version "$tool_name")
        if [[ -n "$current_version" ]]; then
            if ! check_tool_version_compatibility "$tool_name" "$current_version"; then
                log_deps_error "Version compatibility issue: $tool_name $current_version"
                ((validation_errors++))
            fi
        else
            log_deps_warn "Could not detect version for: $tool_name"
        fi
    done

    log_deps_info "Version validation completed: $total_tools tools checked, $validation_errors errors"

    if [[ $validation_errors -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Clear version cache
clear_version_cache() {
    log_deps_info "Clearing version cache..."

    rm -f "$VERSION_CHECK_CACHE_FILE"

    log_deps_info "Version cache cleared"
}

# Show version cache status
show_version_cache_status() {
    echo ""
    echo "${BOLD}${CYAN}Version Cache Status${RESET}"
    echo "====================="
    echo ""

    if [[ -f "$VERSION_CHECK_CACHE_FILE" ]]; then
        local cache_size
        cache_size=$(wc -l < "$VERSION_CHECK_CACHE_FILE")
        local cache_file_size
        cache_file_size=$(stat -f%z "$VERSION_CHECK_CACHE_FILE" 2>/dev/null || stat -c%s "$VERSION_CHECK_CACHE_FILE" 2>/dev/null || echo "0")

        echo "${YELLOW}Cache File:${RESET} $VERSION_CHECK_CACHE_FILE"
        echo "${YELLOW}Entries:${RESET} $cache_size"
        echo "${YELLOW}File Size:${RESET} $(numfmt --to=iec $cache_file_size 2>/dev/null || echo "${cache_file_size} bytes")"
        echo ""

        echo "${YELLOW}Recent Entries:${RESET}"
        tail -10 "$VERSION_CHECK_CACHE_FILE" | while IFS=':' read -r key timestamp version; do
            local cache_date
            cache_date=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
            printf "${CYAN}%-20s${RESET} ${GRAY}%s${RESET} ${GREEN}%s${RESET}\n" "$key" "$cache_date" "$version"
        done
    else
        echo "${GRAY}Version cache is empty${RESET}"
    fi

    echo ""
}

# Export functions
export -f init_version_check_system parse_semver compare_semver get_cached_version
export -f update_version_cache check_tool_version_compatibility check_tool_updates
export -f get_version_compatibility_report show_version_compatibility_report
export -f validate_all_tool_versions clear_version_cache show_version_cache_status

log_deps_debug "Version checking and compatibility system loaded"