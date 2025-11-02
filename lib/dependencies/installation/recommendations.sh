#!/usr/bin/env bash

# FUB Dependencies Recommendation System
# Context-aware tool recommendations based on user behavior and system state

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Recommendation constants
readonly RECOMMENDATION_CONTEXT_DEVELOPMENT="development"
readonly RECOMMENDATION_CONTEXT_SYSTEM="system"
readonly RECOMMENDATION_CONTEXT_PRODUCTIVITY="productivity"
readonly RECOMMENDATION_CONTEXT_MONITORING="monitoring"
readonly RECOMMENDATION_CONTEXT_CONTAINER="container"

# Recommendation priorities
readonly RECOMMENDATION_PRIORITY_CRITICAL=100
readonly RECOMMENDATION_PRIORITY_HIGH=80
readonly RECOMMENDATION_PRIORITY_MEDIUM=60
readonly RECOMMENDATION_PRIORITY_LOW=40
readonly RECOMMENDATION_PRIORITY_OPTIONAL=20

# User behavior tracking
USER_BEHAVIOR_FILE="${DEPS_CACHE_DIR}/user_behavior.yaml"
RECOMMENDATION_HISTORY_FILE="${DEPS_CACHE_DIR}/recommendation_history.yaml"

# Initialize recommendation system
init_recommendation_system() {
    log_deps_debug "Initializing recommendation system..."

    # Ensure cache directory exists
    ensure_dir "$DEPS_CACHE_DIR"

    # Load user behavior data
    load_user_behavior

    log_deps_debug "Recommendation system initialized"
}

# Load user behavior data
load_user_behavior() {
    if [[ -f "$USER_BEHAVIOR_FILE" ]]; then
        log_deps_debug "Loading user behavior from: $USER_BEHAVIOR_FILE"
        # Simple YAML parsing would go here
        # For now, we'll use default behavior patterns
    else
        create_default_behavior_profile
    fi
}

# Create default behavior profile
create_default_behavior_profile() {
    log_deps_debug "Creating default user behavior profile"

    > "$USER_BEHAVIOR_FILE" cat << 'EOF'
# FUB User Behavior Profile
# Tracks user patterns for better recommendations

# Usage patterns
usage_patterns:
  file_operations: medium
  development_work: low
  system_monitoring: low
  git_operations: low
  container_work: low

# Tool preferences
preferred_tools: []
avoided_tools: []

# Installation history
recent_installations: []
successful_installations: []
failed_installations: []

# Context preferences
contexts:
  interactive_preference: true
  visual_preference: true
  performance_preference: medium
EOF

    log_deps_debug "Default behavior profile created"
}

# Detect user context
detect_user_context() {
    log_deps_debug "Detecting user context..."

    local contexts=()

    # Development context
    if is_development_environment; then
        contexts+=("$RECOMMENDATION_CONTEXT_DEVELOPMENT")
    fi

    # System context
    if is_system_administration_environment; then
        contexts+=("$RECOMMENDATION_CONTEXT_SYSTEM")
    fi

    # Productivity context
    if is_productivity_environment; then
        contexts+=("$RECOMMENDATION_CONTEXT_PRODUCTIVITY")
    fi

    # Monitoring context
    if is_monitoring_environment; then
        contexts+=("$RECOMMENDATION_CONTEXT_MONITORING")
    fi

    # Container context
    if is_container_environment; then
        contexts+=("$RECOMMENDATION_CONTEXT_CONTAINER")
    fi

    # Default context if none detected
    if [[ ${#contexts[@]} -eq 0 ]]; then
        contexts+=("$RECOMMENDATION_CONTEXT_PRODUCTIVITY")
    fi

    printf '%s\n' "${contexts[@]}"
}

# Check if in development environment
is_development_environment() {
    local dev_indicators=0

    # Check for development directories
    for dir in "$HOME"/{projects,dev,src,code,workspace}; do
        if [[ -d "$dir" ]]; then
            ((dev_indicators++))
        fi
    done

    # Check for development tools
    for tool in git node python npm yarn docker kubectl; do
        if command_exists "$tool"; then
            ((dev_indicators++))
        fi
    done

    # Check for development files
    if find "$HOME" -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" 2>/dev/null | head -5 | grep -q .; then
        ((dev_indicators++))
    fi

    [[ $dev_indicators -ge 3 ]]
}

# Check if in system administration environment
is_system_administration_environment() {
    local admin_indicators=0

    # Check for admin tools
    for tool in htop iotop nethogs ss iptables ufw systemctl journalctl; do
        if command_exists "$tool"; then
            ((admin_indicators++))
        fi
    done

    # Check for admin directories
    for dir in "/etc" "/var/log" "/sys" "/proc"; do
        if [[ -r "$dir" ]]; then
            ((admin_indicators++))
        fi
    done

    # Check if user has sudo access
    if sudo -n true 2>/dev/null || groups | grep -q "sudo\|admin\|wheel"; then
        ((admin_indicators++))
    fi

    [[ $admin_indicators -ge 3 ]]
}

# Check if in productivity environment
is_productivity_environment() {
    local prod_indicators=0

    # Check for productivity tools
    for tool in vim nano emacs code; do
        if command_exists "$tool"; then
            ((prod_indicators++))
        fi
    done

    # Check for office-related tools
    for tool in libreoffice openoffice evince; do
        if command_exists "$tool"; then
            ((prod_indicators++))
        fi
    fi

    # Check for document directories
    for dir in "$HOME"/{Documents,Desktop,Downloads}; do
        if [[ -d "$dir" ]]; then
            ((prod_indicators++))
        fi
    done

    [[ $prod_indicators -ge 2 ]]
}

# Check if in monitoring environment
is_monitoring_environment() {
    local monitor_indicators=0

    # Check for monitoring tools
    for tool in top ps htop glances iostat vmstat netstat; do
        if command_exists "$tool"; then
            ((monitor_indicators++))
        fi
    done

    # Check for monitoring directories
    if [[ -d "/var/log" && -r "/var/log" ]]; then
        ((monitor_indicators++))
    fi

    # Check system load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | trim)
    if [[ $(echo "$load_avg > 0.5" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
        ((monitor_indicators++))
    fi

    [[ $monitor_indicators -ge 2 ]]
}

# Check if in container environment
is_container_environment() {
    # Check if running in container
    if [[ -f "/.dockerenv" ]] || [[ -f "/run/.containerenv" ]]; then
        return 0
    fi

    # Check for container tools
    local container_tools=0
    for tool in docker podman kubectl minikube; do
        if command_exists "$tool"; then
            ((container_tools++))
        fi
    done

    [[ $container_tools -ge 2 ]]
}

# Get context-based recommendations
get_context_recommendations() {
    local context="$1"
    local limit="${2:-10}"

    log_deps_debug "Getting recommendations for context: $context"

    local recommendations=()
    ensure_registry_loaded

    case "$context" in
        "$RECOMMENDATION_CONTEXT_DEVELOPMENT")
            recommendations+=("lazygit" "git-delta" "tig" "bat" "exa" "fd" "ripgrep")
            ;;
        "$RECOMMENDATION_CONTEXT_SYSTEM")
            recommendations+=("btop" "dust" "duf" "procs" "neofetch" "hwinfo")
            ;;
        "$RECOMMENDATION_CONTEXT_PRODUCTIVITY")
            recommendations+=("gum" "fzf" "bat" "exa" "fd" "ripgrep")
            ;;
        "$RECOMMENDATION_CONTEXT_MONITORING")
            recommendations+=("btop" "dust" "duf" "procs")
            ;;
        "$RECOMMENDATION_CONTEXT_CONTAINER")
            recommendations+=("lazydocker" "docker" "podman")
            ;;
    esac

    # Filter out already installed tools
    local filtered_recommendations=()
    for tool in "${recommendations[@]}"; do
        local status=$(get_cached_tool_status "$tool")
        if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
            filtered_recommendations+=("$tool")
        fi
    done

    # Limit results
    if [[ $limit -gt 0 && ${#filtered_recommendations[@]} -gt $limit ]]; then
        printf '%s\n' "${filtered_recommendations[@]:0:$limit}"
    else
        printf '%s\n' "${filtered_recommendations[@]}"
    fi
}

# Get priority-based recommendations
get_priority_recommendations() {
    local min_priority="${1:-80}"
    local limit="${2:-5}"

    log_deps_debug "Getting priority recommendations (min: $min_priority)"

    local recommendations=()
    ensure_registry_loaded

    # Sort tools by priority and filter
    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_name=$(get_tool_name "$i")
        local priority=$(get_tool_priority "$i")
        local status=$(get_cached_tool_status "$tool_name")

        if [[ $priority -ge $min_priority && "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
            recommendations+=("$tool_name:$priority")
        fi
    done

    # Sort by priority (descending)
    IFS=$'\n' recommendations=($(sort -t':' -k2 -nr <<<"${recommendations[*]}"))
    unset IFS

    # Extract tool names and limit
    local result=()
    local count=0
    for recommendation in "${recommendations[@]}"; do
        local tool_name="${recommendation%%:*}"
        result+=("$tool_name")
        ((count++))
        [[ $count -ge $limit ]] && break
    done

    printf '%s\n' "${result[@]}"
}

# Get capability-based recommendations
get_capability_recommendations() {
    local capability="$1"
    local limit="${2:-5}"

    log_deps_debug "Getting capability recommendations for: $capability"

    local tools
    tools=$(find_tools_by_capability "$capability" false)

    if [[ -z "$tools" ]]; then
        return 1
    fi

    # Filter and prioritize
    local recommendations=()
    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        local status=$(get_cached_tool_status "$tool")
        if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
            local tool_index=$(find_tool_index "$tool")
            local priority=$(get_tool_priority "$tool_index")
            recommendations+=("$tool:$priority")
        fi
    done <<< "$tools"

    # Sort by priority
    IFS=$'\n' recommendations=($(sort -t':' -k2 -nr <<<"${recommendations[*]}"))
    unset IFS

    # Extract and limit
    local result=()
    local count=0
    for recommendation in "${recommendations[@]}"; do
        local tool_name="${recommendation%%:*}"
        result+=("$tool_name")
        ((count++))
        [[ $count -ge $limit ]] && break
    done

    printf '%s\n' "${result[@]}"
}

# Get complementary tool recommendations
get_complementary_recommendations() {
    local base_tool="$1"
    local limit="${2:-3}"

    log_deps_debug "Getting complementary recommendations for: $base_tool"

    local tool_index=$(find_tool_index "$base_tool")
    if [[ $tool_index -lt 0 ]]; then
        return 1
    fi

    local capabilities=$(get_tool_capabilities "$tool_index")
    local category=$(get_tool_category "$tool_index")

    local recommendations=()

    # Find tools with similar capabilities
    IFS=',' read -ra cap_list <<< "$capabilities"
    for cap in "${cap_list[@]}"; do
        cap=$(trim "$cap")
        local comp_tools
        comp_tools=$(find_tools_by_capability "$cap" false)
        while IFS= read -r tool; do
            [[ -z "$tool" || "$tool" == "$base_tool" ]] && continue
            local status=$(get_cached_tool_status "$tool")
            if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
                local tool_index2=$(find_tool_index "$tool")
                local priority=$(get_tool_priority "$tool_index2")
                recommendations+=("$tool:$priority")
            fi
        done <<< "$comp_tools"
    done

    # Find tools in same category
    local cat_tools
    cat_tools=$(get_tools_by_category "$category")
    while IFS= read -r tool; do
        [[ -z "$tool" || "$tool" == "$base_tool" ]] && continue
        local status=$(get_cached_tool_status "$tool")
        if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
            local tool_index2=$(find_tool_index "$tool")
            local priority=$(get_tool_priority "$tool_index2")
            recommendations+=("$tool:$priority")
        fi
    done <<< "$cat_tools"

    # Remove duplicates and sort by priority
    IFS=$'\n' recommendations=($(sort -t':' -k2 -nr <<<"${recommendations[*]}" | uniq))
    unset IFS

    # Extract and limit
    local result=()
    local count=0
    for recommendation in "${recommendations[@]}"; do
        local tool_name="${recommendation%%:*}"
        if [[ ! " ${result[*]} " =~ " $tool_name " ]]; then
            result+=("$tool_name")
            ((count++))
            [[ $count -ge $limit ]] && break
        fi
    done

    printf '%s\n' "${result[@]}"
}

# Generate comprehensive recommendation report
generate_recommendation_report() {
    log_deps_debug "Generating comprehensive recommendation report"

    local contexts
    contexts=$(detect_user_context)

    echo "recommendation_report:"
    echo "timestamp:$(date +%s)"
    echo "contexts:$(IFS=','; echo "${contexts[*]}")"

    # Context-based recommendations
    echo "context_recommendations:"
    for context in $contexts; do
        local tools
        tools=$(get_context_recommendations "$context" 5)
        if [[ -n "$tools" ]]; then
            echo "  $context:$(IFS=','; echo "${tools[*]}")"
        fi
    done

    # Priority recommendations
    local priority_tools
    priority_tools=$(get_priority_recommendations 80 5)
    if [[ -n "$priority_tools" ]]; then
        echo "priority_recommendations:$(IFS=','; echo "${priority_tools[*]}")"
    fi

    # Capability recommendations for common needs
    echo "capability_recommendations:"
    for capability in "interactive-ui" "monitoring" "search" "git"; do
        local tools
        tools=$(get_capability_recommendations "$capability" 3)
        if [[ -n "$tools" ]]; then
            echo "  $capability:$(IFS=','; echo "${tools[*]}")"
        fi
    done
}

# Show recommendations
show_recommendations() {
    local style="${1:-comprehensive}"  # comprehensive, context, priority, capability

    echo ""
    echo "${BOLD}${CYAN}Tool Recommendations${RESET}"
    echo "======================="
    echo ""

    case "$style" in
        "comprehensive")
            show_comprehensive_recommendations
            ;;
        "context")
            show_context_recommendations
            ;;
        "priority")
            show_priority_recommendations
            ;;
        "capability")
            show_capability_recommendations
            ;;
        *)
            echo "${RED}Unknown recommendation style: $style${RESET}"
            return 1
            ;;
    esac

    echo ""
}

# Show comprehensive recommendations
show_comprehensive_recommendations() {
    echo "${YELLOW}Analyzing your system and usage patterns...${RESET}"
    echo ""

    # Detect user contexts
    local contexts
    contexts=$(detect_user_context)

    echo "${CYAN}Detected Contexts:${RESET}"
    for context in $contexts; do
        case "$context" in
            "$RECOMMENDATION_CONTEXT_DEVELOPMENT") echo "  • Development environment" ;;
            "$RECOMMENDATION_CONTEXT_SYSTEM") echo "  • System administration" ;;
            "$RECOMMENDATION_CONTEXT_PRODUCTIVITY") echo "  • General productivity" ;;
            "$RECOMMENDATION_CONTEXT_MONITORING") echo "  • System monitoring" ;;
            "$RECOMMENDATION_CONTEXT_CONTAINER") echo "  • Container/DevOps work" ;;
        esac
    done
    echo ""

    # Show context-based recommendations
    echo "${YELLOW}Context-Based Recommendations:${RESET}"
    for context in $contexts; do
        local tools
        tools=$(get_context_recommendations "$context" 3)
        if [[ -n "$tools" ]]; then
            echo ""
            echo "${CYAN}${context^} Environment:${RESET}"
            while IFS= read -r tool; do
                [[ -z "$tool" ]] && continue
                local tool_index=$(find_tool_index "$tool")
                local benefit=$(get_tool_benefit "$tool_index")
                printf "  ${GREEN}• %s${RESET} - %s\n" "$tool" "$benefit"
            done <<< "$tools"
        fi
    done

    # Show high-priority recommendations
    echo ""
    echo "${YELLOW}High-Priority Tools:${RESET}"
    local priority_tools
    priority_tools=$(get_priority_recommendations 80 5)
    if [[ -n "$priority_tools" ]]; then
        while IFS= read -r tool; do
            [[ -z "$tool" ]] && continue
            local tool_index=$(find_tool_index "$tool")
            local benefit=$(get_tool_benefit "$tool_index")
            local size=$(get_tool_size "$tool_index")
            printf "  ${GREEN}• %s${RESET} ${GRAY}(%s)${RESET} - %s\n" "$tool" "$size" "$benefit"
        done <<< "$priority_tools"
    else
        echo "  ${GRAY}All high-priority tools are installed${RESET}"
    fi
}

# Show context-specific recommendations
show_context_recommendations() {
    local contexts
    contexts=$(detect_user_context)

    for context in $contexts; do
        echo ""
        echo "${CYAN}${context^} Environment:${RESET}"
        local tools
        tools=$(get_context_recommendations "$context" 10)
        if [[ -n "$tools" ]]; then
            while IFS= read -r tool; do
                [[ -z "$tool" ]] && continue
                local tool_index=$(find_tool_index "$tool")
                local benefit=$(get_tool_benefit "$tool_index")
                printf "  ${GREEN}• %s${RESET} - %s\n" "$tool" "$benefit"
            done <<< "$tools"
        else
            echo "  ${GRAY}All recommended tools for this context are installed${RESET}"
        fi
    done
}

# Show priority-based recommendations
show_priority_recommendations() {
    echo "${YELLOW}High-Priority Tools (Recommended for All Users):${RESET}"
    echo ""

    local priority_tools
    priority_tools=$(get_priority_recommendations 80 10)
    if [[ -n "$priority_tools" ]]; then
        while IFS= read -r tool; do
            [[ -z "$tool" ]] && continue
            local tool_index=$(find_tool_index "$tool")
            local benefit=$(get_tool_benefit "$tool_index")
            local priority=$(get_tool_priority "$tool_index")
            local size=$(get_tool_size "$tool_index")
            printf "  ${GREEN}• %s${RESET} ${YELLOW}(Priority: %d)${RESET} ${GRAY}(%s)${RESET}\n" "$tool" "$priority" "$size"
            printf "    %s\n" "$benefit"
        done <<< "$priority_tools"
    else
        echo "  ${GREEN}✅ All high-priority tools are installed!${RESET}"
    fi
}

# Show capability-based recommendations
show_capability_recommendations() {
    local capabilities=("interactive-ui" "monitoring" "search" "file-ops" "git" "containers")

    for capability in "${capabilities[@]}"; do
        echo ""
        echo "${CYAN}${capability^} Capability:${RESET}"
        local tools
        tools=$(get_capability_recommendations "$capability" 3)
        if [[ -n "$tools" ]]; then
            while IFS= read -r tool; do
                [[ -z "$tool" ]] && continue
                local tool_index=$(find_tool_index "$tool")
                local benefit=$(get_tool_benefit "$tool_index")
                printf "  ${GREEN}• %s${RESET} - %s\n" "$tool" "$benefit"
            done <<< "$tools"
        else
            echo "  ${GRAY}All tools for this capability are installed${RESET}"
        fi
    done
}

# Record user interaction with recommendation
record_recommendation_interaction() {
    local tool="$1"
    local action="$2"  # accepted, rejected, ignored

    log_deps_debug "Recording recommendation interaction: $tool -> $action"

    # Append to history file
    echo "$(date +%s):$tool:$action" >> "$RECOMMENDATION_HISTORY_FILE"

    # Update behavior profile (simplified)
    case "$action" in
        "accepted")
            # User is more likely to accept similar recommendations
            ;;
        "rejected")
            # User is less likely to accept similar recommendations
            ;;
    esac
}

# Export functions
export -f init_recommendation_system load_user_behavior create_default_behavior_profile
export -f detect_user_context is_development_environment is_system_administration_environment
export -f is_productivity_environment is_monitoring_environment is_container_environment
export -f get_context_recommendations get_priority_recommendations get_capability_recommendations
export -f get_complementary_recommendations generate_recommendation_report show_recommendations
export -f show_comprehensive_recommendations show_context_recommendations
export -f show_priority_recommendations show_capability_recommendations
export -f record_recommendation_interaction

log_deps_debug "Tool recommendation system loaded"