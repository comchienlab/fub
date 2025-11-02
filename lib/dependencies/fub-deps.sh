#!/usr/bin/env bash

# FUB Dependencies - Main Integration Script
# Central entry point for the FUB dependency management system

set -euo pipefail

# Script information
readonly FUB_DEPS_VERSION="1.0.0"
readonly FUB_DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FUB_DEPS_ROOT_DIR="$(cd "${FUB_DEPS_SCRIPT_DIR}/../.." && pwd)"

# Source core systems
source "${FUB_DEPS_ROOT_DIR}/lib/common.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Import all dependency components
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/detection/detection.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/detection/capability.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/detection/version-check.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/installation/installation.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/installation/prompts.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/installation/recommendations.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/fallback/degradation.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/fallback/alternatives.sh"
source "${FUB_DEPS_ROOT_DIR}/lib/dependencies/ui/deps-ui.sh"

# Global state
FUB_DEPS_INITIALIZED=false

# Show help information
show_help() {
    cat << 'EOF'
FUB Dependencies Manager v1.0.0
A comprehensive dependency management system for FUB

USAGE:
    fub-deps [COMMAND] [OPTIONS]

COMMANDS:
    init            Initialize the dependency system
    check           Check system for installed dependencies
    install [tool]  Install specified tool or run installation wizard
    uninstall [tool] Uninstall specified tool
    update [tool]   Update specified tool or all tools
    list            List available tools
    status          Show system status and statistics
    recommend       Get tool recommendations
    wizard          Run interactive installation wizard
    ui              Launch interactive UI
    config          Manage configuration
    version         Show version information
    help            Show this help message

INSTALLATION OPTIONS:
    --force         Force installation even if already installed
    --no-confirm    Skip confirmation prompts
    --category cat  Only install tools from specific category
    --all           Install all recommended tools

CHECK OPTIONS:
    --force         Force re-check all tools
    --category cat  Only check tools from specific category
    --verbose       Show detailed output

LIST OPTIONS:
    --category cat  List tools from specific category
    --installed     Only show installed tools
    --missing       Only show missing tools
    --details       Show detailed tool information

CONFIG SUBCOMMANDS:
    show            Show current configuration
    set key value   Set configuration value
    reset           Reset to default configuration
    validate        Validate configuration

EXAMPLES:
    fub-deps init                           # Initialize system
    fub-deps check                          # Check dependencies
    fub-deps install gum                    # Install gum
    fub-deps install --category core         # Install all core tools
    fub-deps list --missing                 # List missing tools
    fub-deps recommend                      # Get recommendations
    fub-deps wizard                         # Run installation wizard
    fub-deps ui                             # Launch interactive UI

CATEGORIES:
    core            Essential tools (gum, btop, fd, ripgrep)
    enhanced        Enhanced workflow tools (dust, duf, procs, bat, exa)
    development     Development tools (git-delta, lazygit, tig)
    system          System tools (neofetch, hwinfo)
    optional        Optional tools (docker, podman, lazydocker, fzf)

For more information, see: https://github.com/fub/fub-dependencies
EOF
}

# Initialize dependency system
init_fub_deps() {
    if [[ "$FUB_DEPS_INITIALIZED" == "true" ]]; then
        return 0
    fi

    log_info "Initializing FUB Dependencies Manager v$FUB_DEPS_VERSION"

    # Initialize all components
    init_dependencies
    init_capability_detection
    init_version_check_system
    init_installation_system
    init_recommendation_system
    init_degradation_system

    FUB_DEPS_INITIALIZED=true
    log_info "FUB Dependencies Manager initialized successfully"
}

# Main entry point
main() {
    local command="${1:-help}"

    case "$command" in
        "init")
            init_fub_deps
            ;;
        "check")
            shift
            handle_check_command "$@"
            ;;
        "install")
            shift
            handle_install_command "$@"
            ;;
        "uninstall")
            shift
            handle_uninstall_command "$@"
            ;;
        "update")
            shift
            handle_update_command "$@"
            ;;
        "list")
            shift
            handle_list_command "$@"
            ;;
        "status")
            shift
            handle_status_command "$@"
            ;;
        "recommend")
            shift
            handle_recommend_command "$@"
            ;;
        "wizard")
            shift
            handle_wizard_command "$@"
            ;;
        "ui")
            shift
            handle_ui_command "$@"
            ;;
        "config")
            shift
            handle_config_command "$@"
            ;;
        "version")
            echo "FUB Dependencies Manager v$FUB_DEPS_VERSION"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Error: Unknown command '$command'"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Handle check command
handle_check_command() {
    local force_check=false
    local category_filter=""
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--force"|"-f")
                force_check=true
                shift
                ;;
            "--category"|"-c")
                category_filter="$2"
                shift 2
                ;;
            "--verbose"|"-v")
                verbose=true
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                exit 1
                ;;
        esac
    done

    init_fub_deps

    if [[ "$verbose" == "true" ]]; then
        export DEPS_CONFIG_verbose_mode="true"
    fi

    echo "${CYAN}Checking system dependencies...${RESET}"
    detect_all_tools "$force_check" "$category_filter"
    show_detection_summary
}

# Handle install command
handle_install_command() {
    local force_install=false
    local no_confirm=false
    local category_filter=""
    local install_all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--force"|"-f")
                force_install=true
                shift
                ;;
            "--no-confirm"|"-y")
                no_confirm=true
                shift
                ;;
            "--category"|"-c")
                category_filter="$2"
                shift 2
                ;;
            "--all"|"-a")
                install_all=true
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    init_fub_deps

    if [[ "$install_all" == "true" ]]; then
        echo "${CYAN}Installing all recommended tools...${RESET}"
        run_installation_wizard
    elif [[ -n "$category_filter" ]]; then
        echo "${CYAN}Installing tools from category: $category_filter${RESET}"
        local tools
        tools=$(get_tools_by_category "$category_filter")
        install_tools $tools "$no_confirm"
    elif [[ $# -gt 0 ]]; then
        echo "${CYAN}Installing tools: $*${RESET}"
        install_tools "$@" "$no_confirm"
    else
        echo "${CYAN}Running installation wizard...${RESET}"
        run_installation_wizard
    fi
}

# Handle uninstall command
handle_uninstall_command() {
    local tool="$1"

    init_fub_deps

    if [[ -z "$tool" ]]; then
        echo "Error: No tool specified for uninstallation"
        exit 1
    fi

    echo "${RED}Uninstallation not yet implemented${RESET}"
    echo "This feature would remove: $tool"
}

# Handle update command
handle_update_command() {
    local tool="$1"

    init_fub_deps

    if [[ -n "$tool" ]]; then
        echo "${CYAN}Checking updates for: $tool${RESET}"
        # Update specific tool
    else
        echo "${CYAN}Checking for updates to all tools...${RESET}"
        # Update all tools
    fi

    echo "${YELLOW}Update functionality not yet implemented${RESET}"
}

# Handle list command
handle_list_command() {
    local category_filter=""
    local show_installed=false
    local show_missing=false
    local show_details=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--category"|"-c")
                category_filter="$2"
                shift 2
                ;;
            "--installed"|"-i")
                show_installed=true
                shift
                ;;
            "--missing"|"-m")
                show_missing=true
                shift
                ;;
            "--details"|"-d")
                show_details=true
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                exit 1
                ;;
        esac
    done

    init_fub_deps

    if [[ -n "$category_filter" ]]; then
        echo "${CYAN}Tools in category: $category_filter${RESET}"
        local tools
        tools=$(get_tools_by_category "$category_filter")
        while IFS= read -r tool; do
            [[ -n "$tool" ]] && display_tool_info "$tool" "$show_details"
        done <<< "$tools"
    else
        echo "${CYAN}All available tools:${RESET}"
        local tools
        tools=$(list_all_tools)
        while IFS= read -r tool; do
            [[ -n "$tool" ]] && display_tool_info "$tool" "$show_details"
        done <<< "$tools"
    fi
}

# Display tool information
display_tool_info() {
    local tool="$1"
    local show_details="$2"

    local tool_index=$(find_tool_index "$tool")
    if [[ $tool_index -lt 0 ]]; then
        return 1
    fi

    local status=$(get_cached_tool_status "$tool")
    local category=$(get_tool_category "$tool_index")
    local description=$(get_tool_description "$tool_index)

    # Status icon
    local status_icon="❓"
    case "$status" in
        "$DEPS_STATUS_INSTALLED") status_icon="✅" ;;
        "$DEPS_STATUS_NOT_INSTALLED") status_icon="❌" ;;
        "$DEPS_STATUS_OUTDATED") status_icon="⚠️" ;;
    esac

    if [[ "$show_details" == "true" ]]; then
        echo "$status_icon ${GREEN}$tool${RESET} (${CYAN}$category${RESET})"
        echo "  $description"
        echo ""
    else
        echo "$status_icon ${GREEN}$tool${RESET} - $description"
    fi
}

# Handle status command
handle_status_command() {
    init_fub_deps

    echo "${CYAN}FUB Dependencies System Status${RESET}"
    echo "==============================="
    echo ""

    # Show system status
    show_dependencies_status

    echo ""
    # Show statistics
    show_dependencies_stats

    echo ""
    # Show degradation status
    show_degradation_status
}

# Handle recommend command
handle_recommend_command() {
    local style="comprehensive"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--context"|"-c")
                style="context"
                shift
                ;;
            "--priority"|"-p")
                style="priority"
                shift
                ;;
            "--capability"|"-a")
                style="capability"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                exit 1
                ;;
        esac
    done

    init_fub_deps
    show_recommendations "$style"
}

# Handle wizard command
handle_wizard_command() {
    init_fub_deps
    run_installation_wizard
}

# Handle UI command
handle_ui_command() {
    init_fub_deps
    show_main_menu
}

# Handle config command
handle_config_command() {
    local subcommand="${1:-show}"

    case "$subcommand" in
        "show")
            init_fub_deps
            show_deps_config "${2:-all}"
            ;;
        "set")
            init_fub_deps
            if [[ $# -lt 3 ]]; then
                echo "Error: Usage: fub-deps config set <key> <value>"
                exit 1
            fi
            set_deps_config "$2" "$3" "user"
            ;;
        "reset")
            init_fub_deps
            reset_deps_config "${2:-user}"
            ;;
        "validate")
            init_fub_deps
            validate_deps_config
            ;;
        *)
            echo "Error: Unknown config subcommand '$subcommand'"
            exit 1
            ;;
    esac
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

log_deps_debug "FUB dependencies main script loaded"