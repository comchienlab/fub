#!/usr/bin/env bash

# FUB Dependencies Capability Detection
# Analyzes tool capabilities and system capabilities

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Capability categories
readonly CAP_CATEGORY_UI="ui"
readonly CAP_CATEGORY_MONITORING="monitoring"
readonly CAP_CATEGORY_SEARCH="search"
readonly CAP_CATEGORY_FILE_OPS="file-ops"
readonly CAP_CATEGORY_SYSTEM="system"
readonly CAP_CATEGORY_DEVELOPMENT="development"
readonly CAP_CATEGORY_CONTAINERIZATION="containerization"

# System capabilities cache
SYSTEM_CAPABILITIES_DETECTED=false
SYSTEM_CAPABILITIES=()

# Initialize capability detection system
init_capability_detection() {
    log_deps_debug "Initializing capability detection system..."

    # Detect system capabilities
    detect_system_capabilities

    SYSTEM_CAPABILITIES_DETECTED=true
    log_deps_debug "Capability detection system initialized"
}

# Detect system-wide capabilities
detect_system_capabilities() {
    log_deps_debug "Detecting system capabilities..."

    SYSTEM_CAPABILITIES=()

    # Hardware capabilities
    if [[ -d /sys/class/dmi ]]; then
        SYSTEM_CAPABILITIES+=("hardware-info")
    fi

    # Display capabilities
    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        SYSTEM_CAPABILITIES+=("graphical-display")
    fi

    # Container detection
    if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
        SYSTEM_CAPABILITIES+=("container-environment")
    fi

    # Virtualization detection
    if command_exists systemd-detect-virt; then
        local virt_type
        virt_type=$(systemd-detect-virt 2>/dev/null || echo "none")
        if [[ "$virt_type" != "none" ]]; then
            SYSTEM_CAPABILITIES+=("virtualization:$virt_type")
        fi
    fi

    # Package manager capabilities
    if command_exists apt; then
        SYSTEM_CAPABILITIES+=("package-manager:apt")
        if [[ -w /var/lib/dpkg ]]; then
            SYSTEM_CAPABILITIES+=("package-install:apt")
        fi
    fi

    if command_exists snap; then
        SYSTEM_CAPABILITIES+=("package-manager:snap")
        if snap list >/dev/null 2>&1; then
            SYSTEM_CAPABILITIES+=("package-install:snap")
        fi
    fi

    if command_exists flatpak; then
        SYSTEM_CAPABILITIES+=("package-manager:flatpak")
        if flatpak list >/dev/null 2>&1; then
            SYSTEM_CAPABILITIES+=("package-install:flatpak")
        fi
    fi

    if command_exists brew; then
        SYSTEM_CAPABILITIES+=("package-manager:brew")
        SYSTEM_CAPABILITIES+=("package-install:brew")
    fi

    # Development capabilities
    if command_exists git; then
        SYSTEM_CAPABILITIES+=("version-control:git")
    fi

    if command_exists docker; then
        SYSTEM_CAPABILITIES+=("container-runtime:docker")
    fi

    if command_exists podman; then
        SYSTEM_CAPABILITIES+=("container-runtime:podman")
    fi

    # Network capabilities
    if is_connected; then
        SYSTEM_CAPABILITIES+=("network-access")
    fi

    # Terminal capabilities
    if [[ -t 1 ]]; then
        SYSTEM_CAPABILITIES+=("interactive-terminal")
    fi

    if command_exists tput; then
        local colors
        colors=$(tput colors 2>/dev/null || echo "0")
        if [[ $colors -ge 256 ]]; then
            SYSTEM_CAPABILITIES+=("terminal-colors:256")
        elif [[ $colors -ge 8 ]]; then
            SYSTEM_CAPABILITIES+=("terminal-colors:8")
        fi
    fi

    log_deps_debug "Detected ${#SYSTEM_CAPABILITIES[@]} system capabilities"
}

# Check if system has a specific capability
has_system_capability() {
    local capability="$1"

    if [[ "$SYSTEM_CAPABILITIES_DETECTED" != "true" ]]; then
        detect_system_capabilities
    fi

    for sys_cap in "${SYSTEM_CAPABILITIES[@]}"; do
        if [[ "$sys_cap" == "$capability" ]] || [[ "$sys_cap" == "$capability:"* ]]; then
            return 0
        fi
    done

    return 1
}

# Get system capability value
get_system_capability_value() {
    local capability="$1"

    if [[ "$SYSTEM_CAPABILITIES_DETECTED" != "true" ]]; then
        detect_system_capabilities
    fi

    for sys_cap in "${SYSTEM_CAPABILITIES[@]}"; do
        if [[ "$sys_cap" == "$capability:"* ]]; then
            echo "${sys_cap#*:}"
            return 0
        fi
    done

    return 1
}

# Analyze tool capabilities for a given tool
analyze_tool_capabilities() {
    local tool_name="$1"

    log_deps_debug "Analyzing capabilities for tool: $tool_name"

    if ! tool_exists "$tool_name"; then
        log_deps_error "Tool not found in registry: $tool_name"
        return 1
    fi

    local tool_index=$(find_tool_index "$tool_name")
    local capabilities=$(get_tool_capabilities "$tool_index")
    local status=$(get_cached_tool_status "$tool_name")

    # Parse capabilities
    local capability_list=()
    IFS=',' read -ra capability_list <<< "$capabilities"

    echo "tool:$tool_name"
    echo "status:$status"
    echo "capabilities:${capabilities:-none}"

    # Analyze each capability
    for capability in "${capability_list[@]}"; do
        capability=$(trim "$capability")

        # Check if capability is available
        if is_capability_available "$tool_name" "$capability"; then
            echo "capability:$capability:available"
        else
            echo "capability:$capability:unavailable"
        fi

        # Get capability details
        get_capability_details "$capability"
    done
}

# Check if a specific capability is available for a tool
is_capability_available() {
    local tool_name="$1"
    local capability="$2"

    # Tool must be installed
    local status=$(get_cached_tool_status "$tool_name")
    if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
        return 1
    fi

    # Check tool-specific capability logic
    case "$capability" in
        "interactive-ui")
            [[ -t 0 && -t 1 ]]
            ;;
        "monitoring")
            # Check if we can read system stats
            [[ -r /proc/meminfo && -r /proc/cpuinfo ]]
            ;;
        "system-stats")
            [[ -r /proc/stat && -r /proc/meminfo ]]
            ;;
        "resource-usage")
            command_exists ps && [[ -r /proc ]]
            ;;
        "file-search")
            command_exists find && [[ -r / ]]
            ;;
        "text-search")
            command_exists grep
            ;;
        "syntax-highlighting")
            # Check for common syntax highlighting tools
            command_exists pygmentize || command_exists highlight || command_exists source-highlight
            ;;
        "git")
            command_exists git
            ;;
        "git-ui")
            command_exists git && [[ -t 1 ]]
            ;;
        "containers")
            command_exists docker || command_exists podman
            ;;
        "containerization")
            command_exists docker || command_exists podman
            ;;
        "fuzzy-finder")
            command_exists fzf
            ;;
        "disk-usage")
            command_exists du && [[ -r / ]]
            ;;
        "system-info")
            [[ -r /etc/os-release || -r /proc/version ]]
            ;;
        *)
            # Default check: assume capability is available if tool is installed
            [[ "$status" == "$DEPS_STATUS_INSTALLED" ]]
            ;;
    esac
}

# Get details about a capability
get_capability_details() {
    local capability="$1"

    case "$capability" in
        "interactive-ui")
            echo "capability_detail:$capability:Provides interactive user interface elements"
            ;;
        "tui")
            echo "capability_detail:$capability:Text-based user interface"
            ;;
        "dialogs")
            echo "capability_detail:$capability:Interactive dialog boxes and prompts"
            ;;
        "forms")
            echo "capability_detail:$capability:Interactive form input and validation"
            ;;
        "monitoring")
            echo "capability_detail:$capability:System and process monitoring"
            ;;
        "system-stats")
            echo "capability_detail:$capability:System resource statistics"
            ;;
        "resource-usage")
            echo "capability_detail:$capability:Resource usage analysis"
            ;;
        "file-search")
            echo "capability_detail:$capability:File searching and indexing"
            ;;
        "find-alternative")
            echo "capability_detail:$capability:Alternative to standard find command"
            ;;
        "search")
            echo "capability_detail:$capability:General search functionality"
            ;;
        "text-search")
            echo "capability_detail:$capability:Text pattern searching"
            ;;
        "grep-alternative")
            echo "capability_detail:$capability:Alternative to standard grep command"
            ;;
        "syntax-highlighting")
            echo "capability_detail:$capability:Code syntax highlighting"
            ;;
        "file-viewer")
            echo "capability_detail:$capability:Enhanced file viewing"
            ;;
        "cat-alternative")
            echo "capability_detail:$capability:Alternative to standard cat command"
            ;;
        "git")
            echo "capability_detail:$capability:Git version control integration"
            ;;
        "git-ui")
            echo "capability_detail:$capability:Git user interface"
            ;;
        "version-control")
            echo "capability_detail:$capability:Version control operations"
            ;;
        "containers")
            echo "capability_detail:$capability:Container management"
            ;;
        "containerization")
            echo "capability_detail:$capability:Container runtime support"
            ;;
        "fuzzy-finder")
            echo "capability_detail:$capability:Interactive fuzzy searching"
            ;;
        "interactive-search")
            echo "capability_detail:$capability:Interactive search interface"
            ;;
        "disk-usage")
            echo "capability_detail:$capability:Disk usage analysis"
            ;;
        "du-alternative")
            echo "capability_detail:$capability:Alternative to standard du command"
            ;;
        "storage-analysis")
            echo "capability_detail:$capability:Storage space analysis"
            ;;
        "system-info")
            echo "capability_detail:$capability:System information display"
            ;;
        "system-display")
            echo "capability_detail:$capability:System status display"
            ;;
        "ascii-art")
            echo "capability_detail:$capability:ASCII art generation"
            ;;
        "hardware-info")
            echo "capability_detail:$capability:Hardware information probing"
            ;;
        "system-probing")
            echo "capability_detail:$capability:System capability probing"
            ;;
        "device-info")
            echo "capability_detail:$capability:Device information display"
            ;;
        *)
            echo "capability_detail:$capability:No detailed description available"
            ;;
    esac
}

# Find tools by capability
find_tools_by_capability() {
    local capability="$1"
    local only_available="${2:-false}"

    log_deps_debug "Finding tools with capability: $capability (available only: $only_available)"

    local matching_tools=()
    ensure_registry_loaded

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_name=$(get_tool_name "$i")
        local tool_capabilities=$(get_tool_capabilities "$i")

        if check_capability "$tool_name" "$capability"; then
            if [[ "$only_available" == "true" ]]; then
                if is_capability_available "$tool_name" "$capability"; then
                    matching_tools+=("$tool_name")
                fi
            else
                matching_tools+=("$tool_name")
            fi
        fi
    done

    printf '%s\n' "${matching_tools[@]}"
}

# Get capability matrix for all tools
get_capability_matrix() {
    echo "capability_matrix:"
    ensure_registry_loaded

    # Collect all unique capabilities
    local all_capabilities=()
    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_capabilities=$(get_tool_capabilities "$i")
        IFS=',' read -ra tool_cap_list <<< "$tool_capabilities"
        for cap in "${tool_cap_list[@]}"; do
            cap=$(trim "$cap")
            if [[ -n "$cap" && ! " ${all_capabilities[*]} " =~ " $cap " ]]; then
                all_capabilities+=("$cap")
            fi
        done
    done

    # Generate matrix
    for capability in "${all_capabilities[@]}"; do
        local tools_with_cap=()
        for ((i=0; i<DEPS_TOOL_count; i++)); do
            local tool_name=$(get_tool_name "$i")
            if check_capability "$tool_name" "$capability"; then
                local status=$(get_cached_tool_status "$tool_name")
                if [[ "$status" == "$DEPS_STATUS_INSTALLED" ]]; then
                    tools_with_cap+=("${tool_name}:✓")
                else
                    tools_with_cap+=("${tool_name}:✗")
                fi
            fi
        done

        if [[ ${#tools_with_cap[@]} -gt 0 ]]; then
            echo "capability:$capability:$(IFS=','; echo "${tools_with_cap[*]}")"
        fi
    done
}

# Show capability analysis
show_capability_analysis() {
    local tool_name="${1:-}"

    echo ""
    echo "${BOLD}${CYAN}Capability Analysis${RESET}"
    echo "===================="
    echo ""

    if [[ -n "$tool_name" ]]; then
        # Analyze specific tool
        if ! tool_exists "$tool_name"; then
            echo "${RED}Tool not found: $tool_name${RESET}"
            return 1
        fi

        echo "${YELLOW}Tool:${RESET} $tool_name"
        echo ""

        local analysis
        analysis=$(analyze_tool_capabilities "$tool_name")

        local status=$(echo "$analysis" | grep "status:" | cut -d':' -f2-)
        local capabilities=$(echo "$analysis" | grep "capabilities:" | cut -d':' -f2-)

        echo "${YELLOW}Status:${RESET} $status"
        echo "${YELLOW}Capabilities:${RESET} ${capabilities:-none}"

        if [[ -n "$capabilities" && "$capabilities" != "none" ]]; then
            echo ""
            echo "${YELLOW}Capability Details:${RESET}"
            IFS=',' read -ra cap_list <<< "$capabilities"
            for cap in "${cap_list[@]}"; do
                cap=$(trim "$cap")
                local cap_available=$(echo "$analysis" | grep "capability:$cap:" | cut -d':' -f3)
                local cap_detail=$(echo "$analysis" | grep "capability_detail:$cap:" | cut -d':' -f3-)

                local status_icon="✗"
                local status_color="$RED"
                if [[ "$cap_available" == "available" ]]; then
                    status_icon="✓"
                    status_color="$GREEN"
                fi

                printf "  ${status_color}%s${RESET} ${CYAN}%-20s${RESET} %s\n" "$status_icon" "$cap" "$cap_detail"
            done
        fi
    else
        # Show system capabilities
        echo "${YELLOW}System Capabilities:${RESET}"
        if [[ ${#SYSTEM_CAPABILITIES[@]} -gt 0 ]]; then
            for capability in "${SYSTEM_CAPABILITIES[@]}"; do
                printf "  ${GREEN}✓${RESET} %s\n" "$capability"
            done
        else
            echo "  ${GRAY}No system capabilities detected${RESET}"
        fi

        echo ""
        echo "${YELLOW}Available Tools by Capability:${RESET}"

        # Get common capabilities and show tools
        local common_capabilities=("interactive-ui" "monitoring" "search" "git" "containers")
        for capability in "${common_capabilities[@]}"; do
            local tools
            tools=$(find_tools_by_capability "$capability" true)
            if [[ -n "$tools" ]]; then
                echo ""
                echo "${CYAN}${capability^}:${RESET}"
                echo "$tools" | sed 's/^/  /'
            fi
        done
    fi

    echo ""
}

# Export functions
export -f init_capability_detection detect_system_capabilities has_system_capability
export -f get_system_capability_value analyze_tool_capabilities is_capability_available
export -f get_capability_details find_tools_by_capability get_capability_matrix
export -f show_capability_analysis

log_deps_debug "Dependency capability detection system loaded"