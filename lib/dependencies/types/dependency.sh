#!/usr/bin/env bash

# FUB Dependency Types and Interfaces
# Defines core types and interfaces for the dependency management system

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/../.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
fi

# Dependency type definitions
# Using individual variables for bash 3.x compatibility instead of associative arrays

# Tool categories
readonly DEPS_CATEGORY_CORE="core"           # Essential tools (gum, btop)
readonly DEPS_CATEGORY_ENHANCED="enhanced"   # Enhanced tools (dust, duf, procs)
readonly DEPS_CATEGORY_DEVELOPMENT="development" # Development tools (git-delta, lazygit)
readonly DEPS_CATEGORY_SYSTEM="system"       # System tools (neofetch, hwinfo)
readonly DEPS_CATEGORY_OPTIONAL="optional"   # Optional tools (docker, podman)

# Installation status
readonly DEPS_STATUS_NOT_INSTALLED="not_installed"
readonly DEPS_STATUS_INSTALLED="installed"
readonly DEPS_STATUS_OUTDATED="outdated"
readonly DEPS_STATUS_INCOMPATIBLE="incompatible"
readonly DEPS_STATUS_UNKNOWN="unknown"

# Package manager types
readonly DEPS_PKG_MANAGER_APT="apt"
readonly DEPS_PKG_MANAGER_SNAP="snap"
readonly DEPS_PKG_MANAGER_FLATPAK="flatpak"
readonly DEPS_PKG_MANAGER_BREW="brew"
readonly DEPS_PKG_MANAGER_PACMAN="pacman"
readonly DEPS_PKG_MANAGER_YUM="yum"
readonly DEPS_PKG_MANAGER_DNF="dnf"
readonly DEPS_PKG_MANAGER_UNKNOWN="unknown"

# Dependency registry
# Format: DEPS_TOOL_<name>_<attribute>
DEPS_TOOL_count=0

# Tool data accessors
get_tool_name() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_name"
    echo "${!tool_var:-}"
}

get_tool_category() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_category"
    echo "${!tool_var:-}"
}

get_tool_description() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_description"
    echo "${!tool_var:-}"
}

get_tool_package_names() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_packages"
    echo "${!tool_var:-}"
}

get_tool_min_version() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_min_version"
    echo "${!tool_var:-}"
}

get_tool_max_version() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_max_version"
    echo "${!tool_var:-}"
}

get_tool_executables() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_executables"
    echo "${!tool_var:-}"
}

get_tool_capabilities() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_capabilities"
    echo "${!tool_var:-}"
}

get_tool_benefit() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_benefit"
    echo "${!tool_var:-}"
}

get_tool_priority() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_priority"
    echo "${!tool_var:-50}"
}

get_tool_size() {
    local tool_index="$1"
    local tool_var="DEPS_TOOL_${tool_index}_size"
    echo "${!tool_var:-unknown}"
}

# Tool data setters
register_tool() {
    local name="$1"
    local category="$2"
    local description="$3"
    local packages="$4"
    local min_version="$5"
    local executables="$6"
    local capabilities="$7"
    local benefit="$8"
    local priority="${9:-50}"
    local size="${10:-unknown}"
    local max_version="${11:-}"

    local tool_index="$DEPS_TOOL_count"

    # Set tool data
    printf -v "DEPS_TOOL_${tool_index}_name" '%s' "$name"
    printf -v "DEPS_TOOL_${tool_index}_category" '%s' "$category"
    printf -v "DEPS_TOOL_${tool_index}_description" '%s' "$description"
    printf -v "DEPS_TOOL_${tool_index}_packages" '%s' "$packages"
    printf -v "DEPS_TOOL_${tool_index}_min_version" '%s' "$min_version"
    printf -v "DEPS_TOOL_${tool_index}_max_version" '%s' "$max_version"
    printf -v "DEPS_TOOL_${tool_index}_executables" '%s' "$executables"
    printf -v "DEPS_TOOL_${tool_index}_capabilities" '%s' "$capabilities"
    printf -v "DEPS_TOOL_${tool_index}_benefit" '%s' "$benefit"
    printf -v "DEPS_TOOL_${tool_index}_priority" '%s' "$priority"
    printf -v "DEPS_TOOL_${tool_index}_size" '%s' "$size"

    # Create name to index mapping
    printf -v "DEPS_TOOL_INDEX_${name}" '%s' "$tool_index"

    ((DEPS_TOOL_count++))
    log_debug "Registered tool: $name (index: $tool_index)"
}

# Find tool index by name
find_tool_index() {
    local name="$1"
    local tool_var="DEPS_TOOL_INDEX_${name}"
    echo "${!tool_var:--1}"
}

# List all tools by category
list_tools_by_category() {
    local category="$1"
    local tools=()

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_category=$(get_tool_category "$i")
        if [[ "$tool_category" == "$category" ]]; then
            tools+=("$(get_tool_name "$i")")
        fi
    done

    printf '%s\n' "${tools[@]}"
}

# List all tools
list_all_tools() {
    local tools=()

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        tools+=("$(get_tool_name "$i")")
    done

    printf '%s\n' "${tools[@]}"
}

# Tool status information
# Using individual variables for status tracking
DEPS_STATUS_count=0

set_tool_status() {
    local tool_name="$1"
    local status="$2"
    local version="${3:-}"
    local path="${4:-}"
    local install_method="${5:-}"
    local last_check="${6:-$(date +%s)}"

    local status_index="$DEPS_STATUS_count"

    # Set status data
    printf -v "DEPS_STATUS_${status_index}_tool" '%s' "$tool_name"
    printf -v "DEPS_STATUS_${status_index}_status" '%s' "$status"
    printf -v "DEPS_STATUS_${status_index}_version" '%s' "$version"
    printf -v "DEPS_STATUS_${status_index}_path" '%s' "$path"
    printf -v "DEPS_STATUS_${status_index}_install_method" '%s' "$install_method"
    printf -v "DEPS_STATUS_${status_index}_last_check" '%s' "$last_check"

    # Create tool name to status index mapping
    printf -v "DEPS_STATUS_INDEX_${tool_name}" '%s' "$status_index"

    ((DEPS_STATUS_count++))
    log_debug "Set tool status: $tool_name = $status"
}

get_tool_status() {
    local tool_name="$1"
    local status_var="DEPS_STATUS_INDEX_${tool_name}"
    local status_index="${!status_var:--1}"

    if [[ $status_index -ge 0 ]]; then
        local status_name_var="DEPS_STATUS_${status_index}_status"
        echo "${!status_name_var:-$DEPS_STATUS_UNKNOWN}"
    else
        echo "$DEPS_STATUS_UNKNOWN"
    fi
}

get_tool_version() {
    local tool_name="$1"
    local status_var="DEPS_STATUS_INDEX_${tool_name}"
    local status_index="${!status_var:--1}"

    if [[ $status_index -ge 0 ]]; then
        local version_var="DEPS_STATUS_${status_index}_version"
        echo "${!version_var:-}"
    else
        echo ""
    fi
}

get_tool_path() {
    local tool_name="$1"
    local status_var="DEPS_STATUS_INDEX_${tool_name}"
    local status_index="${!status_var:--1}"

    if [[ $status_index -ge 0 ]]; then
        local path_var="DEPS_STATUS_${status_index}_path"
        echo "${!path_var:-}"
    else
        echo ""
    fi
}

update_tool_status() {
    local tool_name="$1"
    local status="${2:-}"
    local version="${3:-}"
    local path="${4:-}"
    local install_method="${5:-}"
    local last_check="${6:-$(date +%s)}"

    local status_var="DEPS_STATUS_INDEX_${tool_name}"
    local status_index="${!status_var:--1}"

    if [[ $status_index -ge 0 ]]; then
        # Update existing status
        [[ -n "$status" ]] && printf -v "DEPS_STATUS_${status_index}_status" '%s' "$status"
        [[ -n "$version" ]] && printf -v "DEPS_STATUS_${status_index}_version" '%s' "$version"
        [[ -n "$path" ]] && printf -v "DEPS_STATUS_${status_index}_path" '%s' "$path"
        [[ -n "$install_method" ]] && printf -v "DEPS_STATUS_${status_index}_install_method" '%s' "$install_method"
        printf -v "DEPS_STATUS_${status_index}_last_check" '%s' "$last_check"
        log_debug "Updated tool status: $tool_name = $status"
    else
        # Create new status
        set_tool_status "$tool_name" "$status" "$version" "$path" "$install_method" "$last_check"
    fi
}

# Package manager information
detect_package_manager() {
    if command_exists apt; then
        echo "$DEPS_PKG_MANAGER_APT"
    elif command_exists snap; then
        echo "$DEPS_PKG_MANAGER_SNAP"
    elif command_exists flatpak; then
        echo "$DEPS_PKG_MANAGER_FLATPAK"
    elif command_exists brew; then
        echo "$DEPS_PKG_MANAGER_BREW"
    elif command_exists pacman; then
        echo "$DEPS_PKG_MANAGER_PACMAN"
    elif command_exists yum; then
        echo "$DEPS_PKG_MANAGER_YUM"
    elif command_exists dnf; then
        echo "$DEPS_PKG_MANAGER_DNF"
    else
        echo "$DEPS_PKG_MANAGER_UNKNOWN"
    fi
}

# Platform detection
get_platform_info() {
    local platform="unknown"
    local distro="unknown"
    local version="unknown"
    local arch="unknown"

    # Get basic platform info
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        platform="$ID"
        distro="$ID"
        version="$VERSION_ID"
    fi

    # Get architecture
    arch=$(uname -m 2>/dev/null || echo "unknown")

    echo "$platform|$distro|$version|$arch"
}

# Capability checking
check_capability() {
    local tool_name="$1"
    local capability="$2"

    local tool_index=$(find_tool_index "$tool_name")
    if [[ $tool_index -lt 0 ]]; then
        return 1
    fi

    local capabilities=$(get_tool_capabilities "$tool_index")

    # Simple capability check (comma-separated list)
    case "$capabilities" in
        *"$capability"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Tool compatibility checking
check_tool_compatibility() {
    local tool_name="$1"
    local platform="$2"
    local version="$3"

    local tool_index=$(find_tool_index "$tool_name")
    if [[ $tool_index -lt 0 ]]; then
        return 1
    fi

    # Check if tool is compatible with platform
    # This is a simplified check - in production, you'd have platform-specific data
    case "$platform" in
        ubuntu|debian|fedora|centos|arch|macos) return 0 ;;
        *) return 1 ;;
    esac
}

# Utility functions
format_file_size() {
    local size="$1"

    case "$size" in
        unknown) echo "Unknown size" ;;
        *KB) echo "$size" ;;
        *MB) echo "$size" ;;
        *GB) echo "$size" ;;
        *) echo "${size}B" ;;
    esac
}

format_priority() {
    local priority="$1"

    if [[ $priority -ge 80 ]]; then
        echo "Critical"
    elif [[ $priority -ge 60 ]]; then
        echo "High"
    elif [[ $priority -ge 40 ]]; then
        echo "Medium"
    elif [[ $priority -ge 20 ]]; then
        echo "Low"
    else
        echo "Optional"
    fi
}

# Logging for dependency operations
log_deps_info() {
    log_info "[DEPS] $*"
}

log_deps_debug() {
    log_debug "[DEPS] $*"
}

log_deps_warn() {
    log_warn "[DEPS] $*"
}

log_deps_error() {
    log_error "[DEPS] $*"
}

# Export functions
export -f get_tool_name get_tool_category get_tool_description get_tool_package_names
export -f get_tool_min_version get_tool_max_version get_tool_executables get_tool_capabilities
export -f get_tool_benefit get_tool_priority get_tool_size register_tool find_tool_index
export -f list_tools_by_category list_all_tools set_tool_status get_tool_status get_tool_version
export -f get_tool_path update_tool_status detect_package_manager get_platform_info
export -f check_capability check_tool_compatibility format_file_size format_priority
export -f log_deps_info log_deps_debug log_deps_warn log_deps_error

log_deps_debug "Dependency types and interfaces loaded"