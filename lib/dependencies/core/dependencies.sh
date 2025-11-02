#!/usr/bin/env bash

# FUB Dependencies Core System
# Main integration point for the dependency management system

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"

# Source dependency system components
source "${FUB_ROOT_DIR}/lib/dependencies/types/dependency.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/config.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/registry.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/cache.sh"

# System state
DEPS_SYSTEM_INITIALIZED=false
DEPS_SYSTEM_LOADED=false

# Initialize the complete dependency management system
init_dependencies() {
    if [[ "$DEPS_SYSTEM_INITIALIZED" == "true" ]]; then
        log_deps_debug "Dependencies system already initialized"
        return 0
    fi

    log_deps_info "Initializing FUB dependency management system..."

    # Initialize components in order
    init_deps_config
    init_deps_registry
    init_deps_cache

    DEPS_SYSTEM_INITIALIZED=true
    DEPS_SYSTEM_LOADED=true

    log_deps_info "Dependency management system initialized successfully"
    log_deps_debug "Registry: $DEPS_REGISTRY_LOADED_COUNT tools, Cache: $([ "$DEPS_CACHE_VALID" == "true" ] && echo "valid" || echo "invalid")"
}

# Quick initialization (for fast startup)
init_dependencies_minimal() {
    if [[ "$DEPS_SYSTEM_INITIALIZED" == "true" ]]; then
        return 0
    fi

    log_deps_debug "Minimal dependency system initialization..."

    # Only load essentials for basic functionality
    init_deps_config
    init_deps_cache

    # Lazy load registry when needed
    DEPS_SYSTEM_INITIALIZED=true
    log_deps_debug "Minimal dependency system initialized"
}

# Ensure registry is loaded
ensure_registry_loaded() {
    if [[ "$DEPS_REGISTRY_LOADED" != "true" ]]; then
        log_deps_debug "Loading dependency registry on demand..."
        init_deps_registry
    fi
}

# Get system status
get_dependencies_status() {
    echo "initialized:$DEPS_SYSTEM_INITIALIZED"
    echo "loaded:$DEPS_SYSTEM_LOADED"
    echo "registry_loaded:$DEPS_REGISTRY_LOADED"
    echo "registry_tools:$DEPS_REGISTRY_LOADED_COUNT"
    echo "cache_loaded:$DEPS_CACHE_LOADED"
    echo "cache_valid:$DEPS_CACHE_VALID"
}

# Show system information
show_dependencies_info() {
    echo ""
    echo "${BOLD}${CYAN}FUB Dependencies System${RESET}"
    echo "========================="
    echo ""

    # System status
    echo "${YELLOW}System Status:${RESET}"
    echo "  Initialized: $( [[ "$DEPS_SYSTEM_INITIALIZED" == "true" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"
    echo "  Loaded: $( [[ "$DEPS_SYSTEM_LOADED" == "true" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"
    echo ""

    # Registry status
    echo "${YELLOW}Registry Status:${RESET}"
    echo "  Registry loaded: $( [[ "$DEPS_REGISTRY_LOADED" == "true" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"
    if [[ "$DEPS_REGISTRY_LOADED" == "true" ]]; then
        echo "  Total tools: $DEPS_REGISTRY_LOADED_COUNT"
        local categories
        categories=$(get_tool_categories)
        echo "  Categories: $(echo "$categories" | tr '\n' ', ' | sed 's/,$//')"
    fi
    echo ""

    # Cache status
    echo "${YELLOW}Cache Status:${RESET}"
    echo "  Cache loaded: $( [[ "$DEPS_CACHE_LOADED" == "true" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"
    echo "  Cache valid: $( [[ "$DEPS_CACHE_VALID" == "true" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"
    echo ""

    # Configuration
    echo "${YELLOW}Configuration:${RESET}"
    echo "  Auto check: $(get_deps_config auto_check)"
    echo "  Auto install: $(get_deps_config auto_install)"
    echo "  Show recommendations: $(get_deps_config show_recommendations)"
    echo "  Silent mode: $(get_deps_config silent_mode)"
    echo ""
}

# Reset the entire dependency system
reset_dependencies() {
    log_deps_info "Resetting dependency management system..."

    # Reset components
    DEPS_SYSTEM_INITIALIZED=false
    DEPS_SYSTEM_LOADED=false
    DEPS_REGISTRY_LOADED=false
    DEPS_CACHE_LOADED=false
    DEPS_CACHE_VALID=false

    # Clear global variables
    DEPS_TOOL_count=0
    DEPS_STATUS_count=0

    # Unset all tool variables
    for var in $(compgen -v "DEPS_TOOL_"); do
        unset "$var"
    done

    for var in $(compgen -v "DEPS_STATUS_"); do
        unset "$var"
    done

    for var in $(compgen -v "DEPS_CONFIG_"); do
        unset "$var"
    done

    # Clear cache
    if [[ "$DEPS_CACHE_LOADED" == "true" ]]; then
        clear_cache
    fi

    log_deps_info "Dependency management system reset"
}

# Validate the dependency system
validate_dependencies_system() {
    log_deps_debug "Validating dependency management system..."

    local errors=0

    # Check initialization
    if [[ "$DEPS_SYSTEM_INITIALIZED" != "true" ]]; then
        log_deps_error "Dependency system not initialized"
        ((errors++))
    fi

    # Check registry
    if [[ "$DEPS_REGISTRY_LOADED" != "true" ]]; then
        log_deps_error "Dependency registry not loaded"
        ((errors++))
    elif [[ $DEPS_REGISTRY_LOADED_COUNT -eq 0 ]]; then
        log_deps_error "No tools loaded in registry"
        ((errors++))
    fi

    # Check cache
    if [[ "$DEPS_CACHE_LOADED" != "true" ]]; then
        log_deps_error "Dependency cache not loaded"
        ((errors++))
    fi

    # Check configuration
    if [[ "$DEPS_CONFIG_loaded" != "true" ]]; then
        log_deps_error "Dependency configuration not loaded"
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        log_deps_error "Dependency system validation failed with $errors errors"
        return 1
    fi

    log_deps_debug "Dependency system validation passed"
    return 0
}

# Get system statistics
get_dependencies_stats() {
    ensure_registry_loaded

    local total_tools=$DEPS_REGISTRY_LOADED_COUNT
    local cached_tools=$DEPS_STATUS_count
    local installed_tools=0
    local outdated_tools=0
    local missing_tools=0

    # Count tool statuses
    for ((i=0; i<DEPS_STATUS_count; i++)); do
        local status_var="DEPS_STATUS_${i}_status"
        local status="${!status_var}"

        case "$status" in
            "$DEPS_STATUS_INSTALLED") ((installed_tools++)) ;;
            "$DEPS_STATUS_OUTDATED") ((outdated_tools++)) ;;
            "$DEPS_STATUS_NOT_INSTALLED") ((missing_tools++)) ;;
        esac
    done

    echo "total_tools:$total_tools"
    echo "cached_tools:$cached_tools"
    echo "installed_tools:$installed_tools"
    echo "outdated_tools:$outdated_tools"
    echo "missing_tools:$missing_tools"
    echo "cache_valid:$DEPS_CACHE_VALID"
}

# Show system statistics
show_dependencies_stats() {
    local stats
    stats=$(get_dependencies_stats)

    local total_tools=$(echo "$stats" | grep "total_tools:" | cut -d':' -f2)
    local cached_tools=$(echo "$stats" | grep "cached_tools:" | cut -d':' -f2)
    local installed_tools=$(echo "$stats" | grep "installed_tools:" | cut -d':' -f2)
    local outdated_tools=$(echo "$stats" | grep "outdated_tools:" | cut -d':' -f2)
    local missing_tools=$(echo "$stats" | grep "missing_tools:" | cut -d':' -f2)
    local cache_valid=$(echo "$stats" | grep "cache_valid:" | cut -d':' -f2)

    echo ""
    echo "${BOLD}${CYAN}Dependencies Statistics${RESET}"
    echo "======================="
    echo ""

    printf "${YELLOW}Total Tools:${RESET}     %s\n" "$total_tools"
    printf "${YELLOW}Cached Tools:${RESET}    %s\n" "$cached_tools"
    printf "${GREEN}Installed Tools:${RESET}  %s\n" "$installed_tools"
    printf "${YELLOW}Outdated Tools:${RESET}  %s\n" "$outdated_tools"
    printf "${RED}Missing Tools:${RESET}     %s\n" "$missing_tools"
    printf "${YELLOW}Cache Valid:${RESET}     %s\n" "$( [[ "$cache_valid" == "true" ]] && echo "Yes" || echo "No" )"

    # Progress bar for completeness
    if [[ $total_tools -gt 0 ]]; then
        local completeness=$(( (cached_tools * 100) / total_tools ))
        echo ""
        echo "${YELLOW}Cache Completeness:${RESET}"
        printf "["
        local filled=$(( completeness / 2 ))
        for ((i=0; i<50; i++)); do
            if [[ $i -lt $filled ]]; then
                printf "${GREEN}█${RESET}"
            else
                printf "${GRAY}░${RESET}"
            fi
        done
        printf "] %d%%\n" "$completeness"
    fi

    echo ""
}

# Export main functions
export -f init_dependencies init_dependencies_minimal ensure_registry_loaded
export -f get_dependencies_status show_dependencies_info reset_dependencies
export -f validate_dependencies_system get_dependencies_stats show_dependencies_stats

# Initialize system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize FUB common utilities first
    if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
        source "${FUB_ROOT_DIR}/lib/common.sh"
    fi

    # Initialize dependency system
    init_dependencies

    # Show system information
    case "${1:-info}" in
        info) show_dependencies_info ;;
        stats) show_dependencies_stats ;;
        status) get_dependencies_status ;;
        validate) validate_dependencies_system ;;
        *)
            echo "Usage: $0 {info|stats|status|validate}"
            echo "  info     - Show system information"
            echo "  stats    - Show system statistics"
            echo "  status   - Show system status"
            echo "  validate - Validate system integrity"
            exit 1
            ;;
    esac
fi

log_deps_debug "FUB dependencies core system loaded"