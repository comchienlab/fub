#!/usr/bin/env bash

# FUB Dependencies Detection System
# Detects and analyzes optional dependencies on the system

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Detection state
DEPS_DETECTION_RUNNING=false
DEPS_DETECTION_PARALLEL_JOBS=()

# Initialize dependency detection system
init_deps_detection() {
    log_deps_debug "Initializing dependency detection system..."

    # Ensure dependencies system is loaded
    if [[ "$DEPS_SYSTEM_INITIALIZED" != "true" ]]; then
        init_dependencies
    fi

    DEPS_DETECTION_RUNNING=false
    log_deps_debug "Dependency detection system initialized"
}

# Detect a single tool
detect_tool() {
    local tool_name="$1"
    local force_check="${2:-false}"

    log_deps_debug "Detecting tool: $tool_name (force: $force_check)"

    # Check if tool exists in registry
    if ! tool_exists "$tool_name"; then
        log_deps_error "Tool not found in registry: $tool_name"
        return 1
    fi

    # Check if recently cached (unless forced)
    if [[ "$force_check" != "true" ]] && was_recently_checked "$tool_name"; then
        log_deps_debug "Tool recently checked, using cache: $tool_name"
        return 0
    fi

    # Get tool metadata
    local tool_index=$(find_tool_index "$tool_name")
    local executables=$(get_tool_executables "$tool_index")
    local min_version=$(get_tool_min_version "$tool_index")
    local max_version=$(get_tool_max_version "$tool_index")

    # Check for tool presence
    local found_executable=""
    local found_path=""
    local detected_version=""

    for executable in ${executables//,/ }; do
        local exec_path
        exec_path=$(command -v "$executable" 2>/dev/null || true)

        if [[ -n "$exec_path" && -x "$exec_path" ]]; then
            found_executable="$executable"
            found_path="$exec_path"
            break
        fi
    done

    # Determine status
    local status="$DEPS_STATUS_NOT_INSTALLED"
    local install_method=""

    if [[ -n "$found_executable" ]]; then
        # Tool is found, check version
        detected_version=$(detect_tool_version "$tool_name" "$found_executable")

        if [[ -n "$detected_version" ]]; then
            # Check version compatibility
            if check_version_compatibility "$tool_name" "$detected_version" "$min_version" "$max_version"; then
                # Check if outdated
                if is_tool_outdated "$tool_name" "$detected_version"; then
                    status="$DEPS_STATUS_OUTDATED"
                else
                    status="$DEPS_STATUS_INSTALLED"
                fi
                install_method=$(detect_install_method "$found_path")
            else
                status="$DEPS_STATUS_INCOMPATIBLE"
            fi
        else
            # Found but couldn't detect version
            status="$DEPS_STATUS_INSTALLED"
            install_method=$(detect_install_method "$found_path")
        fi
    fi

    # Update cache
    update_tool_cache "$tool_name" "$status" "$detected_version" "$found_path" "$install_method"

    log_deps_debug "Tool detection complete: $tool_name = $status (${detected_version:-N/A})"
    return 0
}

# Detect tool version
detect_tool_version() {
    local tool_name="$1"
    local executable="$2"

    log_deps_debug "Detecting version for $tool_name ($executable)"

    local version=""

    # Use tool-specific version detection
    case "$tool_name" in
        "gum")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "btop")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "fd"|"fd-find")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "ripgrep")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "dust")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "duf")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "procs")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "bat")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "exa")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "git-delta")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "lazygit")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "tig")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "neofetch")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "screenfetch")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "hwinfo")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "docker")
            version=$("$executable" --version 2>/dev/null | grep -oE 'version [0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "podman")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "lazydocker")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        "fzf")
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        *)
            # Generic version detection
            version=$("$executable" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [[ -z "$version" ]]; then
                version=$("$executable" -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            fi
            if [[ -z "$version" ]]; then
                version=$("$executable" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            fi
            ;;
    esac

    # Clean version string
    if [[ -n "$version" ]]; then
        # Extract semantic version if multiple versions found
        version=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_deps_debug "Detected version for $tool_name: $version"
    else
        log_deps_debug "Could not detect version for $tool_name"
    fi

    echo "$version"
}

# Check version compatibility
check_version_compatibility() {
    local tool_name="$1"
    local detected_version="$2"
    local min_version="$3"
    local max_version="$4"

    log_deps_debug "Checking version compatibility for $tool_name: $detected_version (min: $min_version, max: $max_version)"

    # Check minimum version
    if [[ -n "$min_version" ]]; then
        if ! version_compare "$detected_version" ">=" "$min_version"; then
            log_deps_debug "$tool_name version $detected_version is below minimum $min_version"
            return 1
        fi
    fi

    # Check maximum version
    if [[ -n "$max_version" ]]; then
        if ! version_compare "$detected_version" "<=" "$max_version"; then
            log_deps_debug "$tool_name version $detected_version is above maximum $max_version"
            return 1
        fi
    fi

    log_deps_debug "$tool_name version $detected_version is compatible"
    return 0
}

# Check if tool is outdated
is_tool_outdated() {
    local tool_name="$1"
    local current_version="$2"

    # This is a simplified check - in a real implementation,
    # you would query package managers for available versions
    # For now, we'll consider tools not outdated
    return 1
}

# Detect installation method
detect_install_method() {
    local executable_path="$1"

    # Check if executable is managed by package manager
    if command_exists dpkg && dpkg -S "$executable_path" >/dev/null 2>&1; then
        echo "apt"
    elif command_exists rpm && rpm -qf "$executable_path" >/dev/null 2>&1; then
        echo "rpm"
    elif command_exists snap && snap list | grep -q "$(basename "$executable_path")"; then
        echo "snap"
    elif command_exists flatpak && flatpak list | grep -q "$(basename "$executable_path")"; then
        echo "flatpak"
    elif command_exists brew && brew list | grep -q "$(basename "$executable_path")"; then
        echo "brew"
    elif [[ "$executable_path" =~ ^/usr/local/ ]]; then
        echo "local"
    elif [[ "$executable_path" =~ ^/snap/ ]]; then
        echo "snap"
    elif [[ "$executable_path" =~ ^/var/lib/flatpak/ ]]; then
        echo "flatpak"
    else
        echo "unknown"
    fi
}

# Detect all tools (batch detection)
detect_all_tools() {
    local force_check="${1:-false}"
    local category_filter="${2:-}"
    local parallel="$(get_deps_config parallel_checks)"

    log_deps_info "Starting dependency detection (force: $force_check, category: ${category_filter:-all})"

    # Ensure registry is loaded
    ensure_registry_loaded

    # Get tools to check
    local tools_to_check=()
    if [[ -n "$category_filter" ]]; then
        while IFS= read -r tool; do
            tools_to_check+=("$tool")
        done < <(get_tools_by_category "$category_filter")
    else
        while IFS= read -r tool; do
            tools_to_check+=("$tool")
        done < <(list_all_tools)
    fi

    local total_tools=${#tools_to_check[@]}
    local checked_tools=0

    if [[ "$parallel" == "true" && $(get_deps_config max_parallel) -gt 1 ]]; then
        detect_tools_parallel "${tools_to_check[@]}" "$force_check"
    else
        detect_tools_sequential "${tools_to_check[@]}" "$force_check"
    fi

    # Save cache
    save_status_cache

    log_deps_info "Dependency detection completed ($total_tools tools checked)"
}

# Detect tools sequentially
detect_tools_sequential() {
    local tools=("$@")
    local force_check="${tools[-1]}"
    unset 'tools[-1]'  # Remove last element (force_check)

    local total_tools=${#tools[@]}

    log_deps_debug "Detecting $total_tools tools sequentially"

    for tool in "${tools[@]}"; do
        detect_tool "$tool" "$force_check"
        ((checked_tools++))

        # Show progress in verbose mode
        if [[ "$(get_deps_config verbose_mode)" == "true" ]]; then
            printf "\r${YELLOW}Checking tools:${RESET} %d/%d (%s)" "$checked_tools" "$total_tools" "$tool"
        fi
    done

    if [[ "$(get_deps_config verbose_mode)" == "true" ]]; then
        printf "\n"
    fi
}

# Detect tools in parallel
detect_tools_parallel() {
    local tools=("$@")
    local force_check="${tools[-1]}"
    unset 'tools[-1]'  # Remove last element (force_check)

    local max_parallel=$(get_deps_config max_parallel)
    local total_tools=${#tools[@]}
    local active_jobs=0
    local job_pids=()

    log_deps_debug "Detecting $total_tools tools with up to $max_parallel parallel jobs"

    for tool in "${tools[@]}"; do
        # Wait for available slot
        while [[ $active_jobs -ge $max_parallel ]]; do
            for i in "${!job_pids[@]}"; do
                if ! kill -0 "${job_pids[i]}" 2>/dev/null; then
                    wait "${job_pids[i]}"
                    unset "job_pids[i]"
                    ((active_jobs--))
                    break
                fi
            done
            sleep 0.1
        done

        # Start background job
        (
            detect_tool "$tool" "$force_check"
            echo "DONE:$tool" >> "${DEPS_CACHE_DIR}/parallel_jobs.log"
        ) &
        local job_pid=$!
        job_pids+=("$job_pid")
        ((active_jobs++))

        # Show progress in verbose mode
        if [[ "$(get_deps_config verbose_mode)" == "true" ]]; then
            printf "\r${YELLOW}Checking tools:${RESET} %d/%d (active: %d) (%s)" "$((total_tools - ${#tools[@]} + checked_tools))" "$total_tools" "$active_jobs" "$tool"
        fi
    done

    # Wait for all jobs to complete
    for pid in "${job_pids[@]}"; do
        wait "$pid"
    done

    # Clean up
    rm -f "${DEPS_CACHE_DIR}/parallel_jobs.log"

    if [[ "$(get_deps_config verbose_mode)" == "true" ]]; then
        printf "\n"
    fi
}

# Detect tools by capability
detect_tools_by_capability() {
    local capability="$1"
    local force_check="${2:-false}"

    log_deps_info "Detecting tools with capability: $capability"

    local tools_with_capability=()
    ensure_registry_loaded

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_name=$(get_tool_name "$i")
        if check_capability "$tool_name" "$capability"; then
            tools_with_capability+=("$tool_name")
        fi
    done

    if [[ ${#tools_with_capability[@]} -eq 0 ]]; then
        log_deps_warn "No tools found with capability: $capability"
        return 1
    fi

    log_deps_info "Found ${#tools_with_capability[@]} tools with capability: $capability"

    # Detect each tool
    for tool in "${tools_with_capability[@]}"; do
        detect_tool "$tool" "$force_check"
    done
}

# Get detection summary
get_detection_summary() {
    ensure_registry_loaded

    local total_tools=$DEPS_REGISTRY_LOADED_COUNT
    local installed_tools=0
    local outdated_tools=0
    local missing_tools=0
    local incompatible_tools=0

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_name=$(get_tool_name "$i")
        local status=$(get_cached_tool_status "$tool_name")

        case "$status" in
            "$DEPS_STATUS_INSTALLED") ((installed_tools++)) ;;
            "$DEPS_STATUS_OUTDATED") ((outdated_tools++)) ;;
            "$DEPS_STATUS_NOT_INSTALLED") ((missing_tools++)) ;;
            "$DEPS_STATUS_INCOMPATIBLE") ((incompatible_tools++)) ;;
        esac
    done

    echo "total:$total_tools"
    echo "installed:$installed_tools"
    echo "outdated:$outdated_tools"
    echo "missing:$missing_tools"
    echo "incompatible:$incompatible_tools"
}

# Show detection summary
show_detection_summary() {
    local summary
    summary=$(get_detection_summary)

    local total=$(echo "$summary" | grep "total:" | cut -d':' -f2)
    local installed=$(echo "$summary" | grep "installed:" | cut -d':' -f2)
    local outdated=$(echo "$summary" | grep "outdated:" | cut -d':' -f2)
    local missing=$(echo "$summary" | grep "missing:" | cut -d':' -f2)
    local incompatible=$(echo "$summary" | grep "incompatible:" | cut -d':' -f2)

    echo ""
    echo "${BOLD}${CYAN}Dependency Detection Summary${RESET}"
    echo "==============================="
    echo ""

    printf "${GREEN}✓ Installed:${RESET}   %3d\n" "$installed"
    printf "${YELLOW}⚠ Outdated:${RESET}    %3d\n" "$outdated"
    printf "${RED}✗ Missing:${RESET}      %3d\n" "$missing"
    printf "${MAGENTA}⚡ Incompatible:${RESET} %3d\n" "$incompatible"
    printf "${CYAN}Total:${RESET}          %3d\n" "$total"

    # Overall health indicator
    local health_score=$(( (installed * 100) / total ))
    echo ""
    echo "${YELLOW}System Health:${RESET} ${health_score}%"

    printf "["
    local filled=$(( health_score / 2 ))
    for ((i=0; i<50; i++)); do
        if [[ $i -lt $filled ]]; then
            printf "${GREEN}█${RESET}"
        else
            printf "${GRAY}░${RESET}"
        fi
    done
    printf "] %d%%\n" "$health_score"

    echo ""
}

# Export functions
export -f init_deps_detection detect_tool detect_tool_version check_version_compatibility
export -f is_tool_outdated detect_install_method detect_all_tools detect_tools_sequential
export -f detect_tools_parallel detect_tools_by_capability get_detection_summary
export -f show_detection_summary

log_deps_debug "Dependency detection system loaded"