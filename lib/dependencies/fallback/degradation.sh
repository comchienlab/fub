#!/usr/bin/env bash

# FUB Dependencies Graceful Degradation
# Provides fallback implementations and degraded functionality for missing tools

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Degradation modes
readonly DEGRADATION_MODE_FULL="full"              # All features available
readonly DEGRADATION_MODE_REDUCED="reduced"        # Some features unavailable
readonly DEGRADATION_MODE_MINIMAL="minimal"        # Basic features only
readonly DEGRADATION_MODE_CORE="core"             # Only core functionality

# Current degradation state
CURRENT_DEGRADATION_MODE="$DEGRADATION_MODE_FULL"
MISSING_CAPABILITIES=()
FALLBACK_ACTIVE=()

# Initialize degradation system
init_degradation_system() {
    log_deps_debug "Initializing graceful degradation system..."

    # Analyze current system state
    analyze_system_degradation

    # Set up fallbacks for missing tools
    setup_fallback_implementations

    log_deps_debug "Graceful degradation system initialized (mode: $CURRENT_DEGRADATION_MODE)"
}

# Analyze system degradation level
analyze_system_degradation() {
    log_deps_debug "Analyzing system degradation level..."

    # Ensure dependency detection has run
    if [[ "$DEPS_SYSTEM_INITIALIZED" != "true" ]]; then
        init_dependencies
    fi

    # Count available tools by category
    local core_tools_available=0
    local enhanced_tools_available=0
    local total_core_tools=0
    local total_enhanced_tools=0

    ensure_registry_loaded

    # Analyze core tools
    local core_tools
    core_tools=$(list_tools_by_category "$DEPS_CATEGORY_CORE")
    total_core_tools=$(echo "$core_tools" | wc -l)

    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        local status=$(get_cached_tool_status "$tool")
        if [[ "$status" == "$DEPS_STATUS_INSTALLED" ]]; then
            ((core_tools_available++))
        fi
    done <<< "$core_tools"

    # Analyze enhanced tools
    local enhanced_tools
    enhanced_tools=$(list_tools_by_category "$DEPS_CATEGORY_ENHANCED")
    total_enhanced_tools=$(echo "$enhanced_tools" | wc -l)

    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        local status=$(get_cached_tool_status "$tool")
        if [[ "$status" == "$DEPS_STATUS_INSTALLED" ]]; then
            ((enhanced_tools_available++))
        fi
    done <<< "$enhanced_tools"

    # Determine degradation mode
    local core_ratio=$(( (core_tools_available * 100) / total_core_tools ))
    local enhanced_ratio=$(( (enhanced_tools_available * 100) / total_enhanced_tools ))

    if [[ $core_ratio -ge 80 ]]; then
        if [[ $enhanced_ratio -ge 60 ]]; then
            CURRENT_DEGRADATION_MODE="$DEGRADATION_MODE_FULL"
        elif [[ $enhanced_ratio -ge 30 ]]; then
            CURRENT_DEGRADATION_MODE="$DEGRADATION_MODE_REDUCED"
        else
            CURRENT_DEGRADATION_MODE="$DEGRADATION_MODE_MINIMAL"
        fi
    else
        CURRENT_DEGRADATION_MODE="$DEGRADATION_MODE_CORE"
    fi

    # Identify missing capabilities
    identify_missing_capabilities

    log_deps_debug "Degradation analysis: core=$core_ratio%, enhanced=$enhanced_ratio%, mode=$CURRENT_DEGRADATION_MODE"
}

# Identify missing capabilities
identify_missing_capabilities() {
    log_deps_debug "Identifying missing capabilities..."

    MISSING_CAPABILITIES=()

    # Check for key capabilities
    if ! command_exists gum; then
        MISSING_CAPABILITIES+=("interactive-ui")
    fi

    if ! command_exists btop; then
        MISSING_CAPABILITIES+=("advanced-monitoring")
    fi

    if ! command_exists fd && ! command_exists ripgrep; then
        MISSING_CAPABILITIES+=("advanced-search")
    fi

    if ! command_exists dust && ! command_exists duf; then
        MISSING_CAPABILITIES+=("advanced-storage-analysis")
    fi

    if ! command_exists bat && ! command_exists exa; then
        MISSING_CAPABILITIES+=("enhanced-file-viewing")
    fi

    if ! command_exists lazygit; then
        MISSING_CAPABILITIES+=("advanced-git-ui")
    fi

    log_deps_debug "Found ${#MISSING_CAPABILITIES[@]} missing capabilities"
}

# Setup fallback implementations
setup_fallback_implementations() {
    log_deps_debug "Setting up fallback implementations..."

    FALLBACK_ACTIVE=()

    # Setup fallbacks based on missing capabilities
    for capability in "${MISSING_CAPABILITIES[@]}"; do
        case "$capability" in
            "interactive-ui")
                setup_fallback_interactive_ui
                FALLBACK_ACTIVE+=("interactive-ui:basic")
                ;;
            "advanced-monitoring")
                setup_fallback_monitoring
                FALLBACK_ACTIVE+=("monitoring:basic")
                ;;
            "advanced-search")
                setup_fallback_search
                FALLBACK_ACTIVE+=("search:basic")
                ;;
            "advanced-storage-analysis")
                setup_fallback_storage
                FALLBACK_ACTIVE+=("storage:basic")
                ;;
            "enhanced-file-viewing")
                setup_fallback_file_viewing
                FALLBACK_ACTIVE+=("file-viewing:basic")
                ;;
            "advanced-git-ui")
                setup_fallback_git_ui
                FALLBACK_ACTIVE+=("git-ui:basic")
                ;;
        esac
    done

    log_deps_debug "Setup ${#FALLBACK_ACTIVE[@]} fallback implementations"
}

# Fallback: Interactive UI (basic text prompts)
setup_fallback_interactive_ui() {
    log_deps_debug "Setting up fallback interactive UI"

    # Create fallback functions for gum functionality
    if ! command_exists gum; then
        # Override gum commands with basic alternatives
        gum() {
            local command="$1"
            shift

            case "$command" in
                "confirm")
                    echo -n "${YELLOW}$*${RESET} [y/N]: "
                    read -r response
                    [[ "$response" =~ ^[Yy]$ ]]
                    ;;
                "input")
                    echo -n "${YELLOW}$*${RESET}: "
                    read -r input
                    echo "$input"
                    ;;
                "choose")
                    echo "$1"  # Return first option
                    ;;
                "style")
                    echo "$*"  # Just print the text
                    ;;
                "spin"|"progress")
                    # No-op for fallback
                    ;;
                *)
                    echo "${YELLOW}gum not available: $command $*${RESET}" >&2
                    return 1
                    ;;
            esac
        }

        export -f gum
        log_deps_debug "Fallback gum functions created"
    fi
}

# Fallback: Basic system monitoring
setup_fallback_monitoring() {
    log_deps_debug "Setting up fallback monitoring"

    # Create fallback for btop
    if ! command_exists btop; then
        btop() {
            echo "${YELLOW}btop not available, showing basic system info:${RESET}"
            echo ""

            # CPU info
            if [[ -f /proc/cpuinfo ]]; then
                echo "${CYAN}CPU Info:${RESET}"
                grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2- | sed 's/^ *//'
                grep "processor" /proc/cpuinfo | wc -l | xargs echo "  Cores:"
                echo ""
            fi

            # Memory info
            if [[ -f /proc/meminfo ]]; then
                echo "${CYAN}Memory Info:${RESET}"
                local total_mem
                total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
                local available_mem
                available_mem=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
                local used_mem=$((total_mem - available_mem))

                echo "  Total: $(( total_mem / 1024 ))MB"
                echo "  Used:  $(( used_mem / 1024 ))MB"
                echo "  Free:  $(( available_mem / 1024 ))MB"
                echo ""
            fi

            # Disk info
            echo "${CYAN}Disk Usage:${RESET}"
            df -h | grep -E '^/dev/' | head -5

            echo ""
            echo "${GRAY}Press Enter to continue...${RESET}"
            read -r
        }

        export -f btop
        log_deps_debug "Fallback btop function created"
    fi
}

# Fallback: Basic file search
setup_fallback_search() {
    log_deps_debug "Setting up fallback search"

    # Create fallback for fd
    if ! command_exists fd; then
        fd() {
            local pattern="${1:-.}"
            local path="${2:-.}"

            echo "${YELLOW}fd not available, using find:${RESET}"
            find "$path" -name "*$pattern*" 2>/dev/null
        }

        export -f fd
        log_deps_debug "Fallback fd function created"
    fi

    # Create fallback for ripgrep
    if ! command_exists rg; then
        rg() {
            local pattern="$1"
            local path="${2:-.}"

            echo "${YELLOW}ripgrep not available, using grep:${RESET}"
            grep -r "$pattern" "$path" 2>/dev/null
        }

        export -f rg
        log_deps_debug "Fallback ripgrep function created"
    fi
}

# Fallback: Basic storage analysis
setup_fallback_storage() {
    log_deps_debug "Setting up fallback storage analysis"

    # Create fallback for dust
    if ! command_exists dust; then
        dust() {
            local path="${1:-.}"

            echo "${YELLOW}dust not available, using du:${RESET}"
            du -sh "$path"/* 2>/dev/null | sort -hr | head -20
        }

        export -f dust
        log_deps_debug "Fallback dust function created"
    fi

    # Create fallback for duf
    if ! command_exists duf; then
        duf() {
            echo "${YELLOW}duf not available, using df:${RESET}"
            df -h
        }

        export -f duf
        log_deps_debug "Fallback duf function created"
    fi
}

# Fallback: Basic file viewing
setup_fallback_file_viewing() {
    log_deps_debug "Setting up fallback file viewing"

    # Create fallback for bat
    if ! command_exists bat; then
        bat() {
            local file="$1"

            echo "${YELLOW}bat not available, using cat:${RESET}"
            cat "$file"
        }

        export -f bat
        log_deps_debug "Fallback bat function created"
    fi

    # Create fallback for exa
    if ! command_exists exa; then
        exa() {
            echo "${YELLOW}exa not available, using ls:${RESET}"
            ls -la "$@"
        }

        export -f exa
        log_deps_debug "Fallback exa function created"
    fi
}

# Fallback: Basic git UI
setup_fallback_git_ui() {
    log_deps_debug "Setting up fallback git UI"

    # Create fallback for lazygit
    if ! command_exists lazygit; then
        lazygit() {
            echo "${YELLOW}lazygit not available, showing git status:${RESET}"
            echo ""

            if git rev-parse --git-dir >/dev/null 2>&1; then
                echo "${CYAN}Git Repository Status:${RESET}"
                git status
                echo ""
                echo "${CYAN}Recent Commits:${RESET}"
                git log --oneline -10
                echo ""
                echo "${GRAY}Tip: Install lazygit for enhanced git interface${RESET}"
            else
                echo "${RED}Not a git repository${RESET}"
            fi
        }

        export -f lazygit
        log_deps_debug "Fallback lazygit function created"
    fi
}

# Get degradation summary
get_degradation_summary() {
    echo "mode:$CURRENT_DEGRADATION_MODE"
    echo "missing_capabilities:${#MISSING_CAPABILITIES[@]}"
    echo "active_fallbacks:${#FALLBACK_ACTIVE[@]}"
}

# Show degradation status
show_degradation_status() {
    echo ""
    echo "${BOLD}${YELLOW}System Degradation Status${RESET}"
    echo "==========================="
    echo ""

    # Show current mode
    echo "${CYAN}Current Mode:${RESET} $CURRENT_DEGRADATION_MODE"
    case "$CURRENT_DEGRADATION_MODE" in
        "$DEGRADATION_MODE_FULL")
            echo "  ${GREEN}✓ All features available${RESET}"
            ;;
        "$DEGRADATION_MODE_REDUCED")
            echo "  ${YELLOW}⚠ Some features unavailable${RESET}"
            ;;
        "$DEGRADATION_MODE_MINIMAL")
            echo "  ${YELLOW}⚠ Limited functionality${RESET}"
            ;;
        "$DEGRADATION_MODE_CORE")
            echo "  ${RED}✗ Core functionality only${RESET}"
            ;;
    esac
    echo ""

    # Show missing capabilities
    if [[ ${#MISSING_CAPABILITIES[@]} -gt 0 ]]; then
        echo "${YELLOW}Missing Capabilities:${RESET}"
        for capability in "${MISSING_CAPABILITIES[@]}"; do
            echo "  ${RED}✗${RESET} $capability"
        done
        echo ""
    fi

    # Show active fallbacks
    if [[ ${#FALLBACK_ACTIVE[@]} -gt 0 ]]; then
        echo "${YELLOW}Active Fallbacks:${RESET}"
        for fallback in "${FALLBACK_ACTIVE[@]}"; do
            echo "  ${GREEN}✓${RESET} $fallback"
        done
        echo ""
    fi

    # Show improvement suggestions
    show_improvement_suggestions
}

# Show improvement suggestions
show_improvement_suggestions() {
    echo "${CYAN}💡 Improvement Suggestions:${RESET}"
    echo ""

    for capability in "${MISSING_CAPABILITIES[@]}"; do
        case "$capability" in
            "interactive-ui")
                echo "  • Install ${GREEN}gum${RESET} for enhanced interactive prompts"
                ;;
            "advanced-monitoring")
                echo "  • Install ${GREEN}btop${RESET} for beautiful system monitoring"
                ;;
            "advanced-search")
                echo "  • Install ${GREEN}fd${RESET} for fast file searching"
                echo "  • Install ${GREEN}ripgrep${RESET} for fast text searching"
                ;;
            "advanced-storage-analysis")
                echo "  • Install ${GREEN}dust${RESET} for intuitive disk usage analysis"
                echo "  • Install ${GREEN}duf${RESET} for beautiful disk space display"
                ;;
            "enhanced-file-viewing")
                echo "  • Install ${GREEN}bat${RESET} for syntax-highlighted file viewing"
                echo "  • Install ${GREEN}exa${RESET} for modern directory listing"
                ;;
            "advanced-git-ui")
                echo "  • Install ${GREEN}lazygit${RESET} for intuitive git management"
                ;;
        esac
    done

    echo ""
    echo "${GRAY}Run the installation wizard to add these tools.${RESET}"
}

# Check if specific feature is available
is_feature_available() {
    local feature="$1"

    case "$feature" in
        "interactive-ui")
            [[ "$CURRENT_DEGRADATION_MODE" != "$DEGRADATION_MODE_CORE" ]] && command_exists gum
            ;;
        "advanced-monitoring")
            [[ "$CURRENT_DEGRADATION_MODE" == "$DEGRADATION_MODE_FULL" ]] && command_exists btop
            ;;
        "advanced-search")
            [[ "$CURRENT_DEGRADATION_MODE" == "$DEGRADATION_MODE_FULL" ]] && (command_exists fd || command_exists ripgrep)
            ;;
        "enhanced-file-viewing")
            [[ "$CURRENT_DEGRADATION_MODE" != "$DEGRADATION_MODE_CORE" ]] && (command_exists bat || command_exists exa)
            ;;
        "basic-monitoring")
            true  # Always available with fallbacks
            ;;
        "basic-search")
            true  # Always available with fallbacks
            ;;
        *)
            # Default: available if not in core mode
            [[ "$CURRENT_DEGRADATION_MODE" != "$DEGRADATION_MODE_CORE" ]]
            ;;
    esac
}

# Get feature level (full, reduced, minimal, none)
get_feature_level() {
    local feature="$1"

    if is_feature_available "$feature"; then
        if command_exists "${feature%%-*}" 2>/dev/null; then
            echo "full"
        else
            echo "reduced"
        fi
    else
        echo "none"
    fi
}

# Warn about missing feature
warn_missing_feature() {
    local feature="$1"
    local alternative="$2"

    if ! is_feature_available "$feature"; then
        echo "${YELLOW}⚠ $feature not available${RESET}"
        if [[ -n "$alternative" ]]; then
            echo "${GRAY}  Using: $alternative${RESET}"
        fi
        return 1
    fi

    return 0
}

# Export functions
export -f init_degradation_system analyze_system_degradation identify_missing_capabilities
export -f setup_fallback_implementations setup_fallback_interactive_ui setup_fallback_monitoring
export -f setup_fallback_search setup_fallback_storage setup_fallback_file_viewing
export -f setup_fallback_git_ui get_degradation_summary show_degradation_status
export -f show_improvement_suggestions is_feature_available get_feature_level
export -f warn_missing_feature

log_deps_debug "Graceful degradation system loaded"