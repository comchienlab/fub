#!/usr/bin/env bash

# FUB Dependencies Interactive UI
# Interactive user interface for dependency management

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Import theme and UI systems if available
if [[ -f "${FUB_ROOT_DIR}/lib/theme.sh" ]]; then
    source "${FUB_ROOT_DIR}/lib/theme.sh"
    init_theme
fi

if [[ -f "${FUB_ROOT_DIR}/lib/ui.sh" ]]; then
    source "${FUB_ROOT_DIR}/lib/ui.sh"
fi

# Import dependency components
source "${FUB_ROOT_DIR}/lib/dependencies/detection/detection.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/detection/capability.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/installation/installation.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/installation/prompts.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/installation/recommendations.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/fallback/degradation.sh"

# UI state
UI_CURRENT_MENU="main"
UI_PAGE_SIZE=10
UI_CURRENT_PAGE=1

# Initialize UI system
init_deps_ui() {
    log_deps_debug "Initializing dependency management UI..."

    # Initialize all dependency systems
    init_dependencies
    init_capability_detection
    init_installation_system
    init_recommendation_system

    # Initialize prompts
    init_installation_prompts

    log_deps_debug "Dependency management UI initialized"
}

# Main menu
show_main_menu() {
    while true; do
        clear
        show_ui_header "FUB Dependencies Manager"

        # Show system status summary
        show_system_status_summary

        echo ""
        echo "${BOLD}${CYAN}Main Menu${RESET}"
        echo "==========="
        echo ""

        if command_exists gum; then
            local choice
            choice=$(gum choose \
                "📊 Check Dependencies" \
                "🔍 Browse Available Tools" \
                "💡 Get Recommendations" \
                "⚙️  Manage Configuration" \
                "📈 View Statistics" \
                "🛠️  Install Tools" \
                "🗑️  Uninstall Tools" \
                "🔄 Update Tools" \
                "ℹ️  System Information" \
                "❌ Exit" \
                --header="Choose an action:")

            case "$choice" in
                "📊 Check Dependencies") run_dependency_check ;;
                "🔍 Browse Available Tools") show_tools_browser ;;
                "💡 Get Recommendations") show_recommendations_menu ;;
                "⚙️  Manage Configuration") show_configuration_menu ;;
                "📈 View Statistics") show_statistics_menu ;;
                "🛠️  Install Tools") run_installation_wizard ;;
                "🗑️  Uninstall Tools") show_uninstall_menu ;;
                "🔄 Update Tools") show_update_menu ;;
                "ℹ️  System Information") show_system_information ;;
                "❌ Exit") break ;;
            esac
        else
            echo "1) Check Dependencies"
            echo "2) Browse Available Tools"
            echo "3) Get Recommendations"
            echo "4) Manage Configuration"
            echo "5) View Statistics"
            echo "6) Install Tools"
            echo "7) Uninstall Tools"
            echo "8) Update Tools"
            echo "9) System Information"
            echo "0) Exit"
            echo ""

            echo -n "${CYAN}Choose an option (0-9):${RESET} "
            read -r choice

            case "$choice" in
                1) run_dependency_check ;;
                2) show_tools_browser ;;
                3) show_recommendations_menu ;;
                4) show_configuration_menu ;;
                5) show_statistics_menu ;;
                6) run_installation_wizard ;;
                7) show_uninstall_menu ;;
                8) show_update_menu ;;
                9) show_system_information ;;
                0) break ;;
                *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        fi
    done
}

# Show UI header
show_ui_header() {
    local title="$1"

    if command_exists gum; then
        gum style \
            --foreground 212 \
            --border double \
            --border-foreground 212 \
            --align center \
            --margin "0 2" \
            --padding "1 2" \
            "$title"
    else
        echo ""
        echo "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
        printf "${BOLD}${CYAN}║%*s${RESET}\n" 42 "$title"
        echo "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"
    fi
}

# Show system status summary
show_system_status_summary() {
    local summary
    summary=$(get_dependencies_stats)

    local total_tools=$(echo "$summary" | grep "total_tools:" | cut -d':' -f2)
    local installed_tools=$(echo "$summary" | grep "installed_tools:" | cut -d':' -f2)
    local missing_tools=$(echo "$summary" | grep "missing_tools:" | cut -d':' -f2)
    local outdated_tools=$(echo "$summary" | grep "outdated_tools:" | cut -d':' -f2)

    # Calculate health percentage
    local health_percentage=0
    if [[ $total_tools -gt 0 ]]; then
        health_percentage=$(( (installed_tools * 100) / total_tools ))
    fi

    echo ""
    echo "${BOLD}System Status:${RESET}"

    # Progress bar
    printf "Health: "
    local bar_length=30
    local filled_length=$(( (health_percentage * bar_length) / 100 ))
    printf "["
    for ((i=0; i<bar_length; i++)); do
        if [[ $i -lt $filled_length ]]; then
            printf "${GREEN}█${RESET}"
        else
            printf "${GRAY}░${RESET}"
        fi
    done
    printf "] ${health_percentage}%%\n"

    # Tool counts
    printf "${GREEN}✓ Installed:${RESET} %3d  " "$installed_tools"
    printf "${RED}✗ Missing:${RESET} %3d  " "$missing_tools"
    printf "${YELLOW}⚠ Outdated:${RESET} %3d\n" "$outdated_tools"
}

# Run dependency check
run_dependency_check() {
    clear
    show_ui_header "Dependency Check"

    echo "${YELLOW}Scanning system for dependencies...${RESET}"
    echo ""

    # Run detection
    detect_all_tools true

    # Show summary
    show_detection_summary

    echo ""
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

# Show tools browser
show_tools_browser() {
    local category_filter=""
    local current_page=1

    while true; do
        clear
        show_ui_header "Available Tools Browser"

        if [[ -n "$category_filter" ]]; then
            echo "${YELLOW}Filter: $category_filter${RESET}"
        fi

        # Get tools to display
        local tools_to_show=()
        if [[ -n "$category_filter" ]]; then
            while IFS= read -r tool; do
                [[ -n "$tool" ]] && tools_to_show+=("$tool")
            done < <(get_tools_by_category "$category_filter")
        else
            while IFS= read -r tool; do
                [[ -n "$tool" ]] && tools_to_show+=("$tool")
            done < <(list_all_tools)
        fi

        # Pagination
        local total_tools=${#tools_to_show[@]}
        local total_pages=$(( (total_tools + UI_PAGE_SIZE - 1) / UI_PAGE_SIZE ))
        local start_index=$(((current_page - 1) * UI_PAGE_SIZE))
        local end_index=$((start_index + UI_PAGE_SIZE - 1))

        if [[ $end_index -ge $total_tools ]]; then
            end_index=$((total_tools - 1))
        fi

        # Show page info
        echo "${CYAN}Page $current_page of $total_pages (${total_tools} tools)${RESET}"
        echo ""

        # Show tools
        printf "${GREEN}%-20s${RESET} ${CYAN}%-12s${RESET} ${YELLOW}%-8s${RESET} %s\n" "Tool" "Category" "Status" "Description"
        echo "--------------------------------------------------------------------------------"

        for ((i=start_index; i<=end_index; i++)); do
            if [[ $i -ge ${#tools_to_show[@]} ]]; then
                break
            fi

            local tool="${tools_to_show[$i]}"
            local tool_index=$(find_tool_index "$tool")
            local category=$(get_tool_category "$tool_index")
            local status=$(get_cached_tool_status "$tool")
            local description=$(get_tool_description "$tool_index")

            # Format status
            local status_display="Unknown"
            local status_color="$GRAY"
            case "$status" in
                "$DEPS_STATUS_INSTALLED") status_display="Installed"; status_color="$GREEN" ;;
                "$DEPS_STATUS_NOT_INSTALLED") status_display="Missing"; status_color="$RED" ;;
                "$DEPS_STATUS_OUTDATED") status_display="Outdated"; status_color="$YELLOW" ;;
            esac

            printf "${GREEN}%-20s${RESET} ${CYAN}%-12s${RESET} ${status_color}%-8s${RESET} %s\n" \
                   "$tool" "$category" "$status_display" "$description"
        done

        echo ""
        echo "${BOLD}Actions:${RESET}"
        echo "  i) Install tool"
        echo "  f) Filter by category"
        echo "  c) Clear filter"
        echo "  n) Next page"
        echo "  p) Previous page"
        echo "  d) Tool details"
        echo "  b) Back to main menu"

        if command_exists gum; then
            local action
            action=$(gum choose "install" "filter" "clear-filter" "next-page" "prev-page" "details" "back" --header="Choose action:")

            case "$action" in
                "install") handle_tool_installation "${tools_to_show[@]}" ;;
                "filter") handle_category_filter ;;
                "clear-filter") category_filter="" ;;
                "next-page")
                    if [[ $current_page -lt $total_pages ]]; then
                        ((current_page++))
                    fi
                    ;;
                "prev-page")
                    if [[ $current_page -gt 1 ]]; then
                        ((current_page--))
                    fi
                    ;;
                "details") handle_tool_details "${tools_to_show[@]}" ;;
                "back") break ;;
            esac
        else
            echo -n "${CYAN}Choose action: ${RESET}"
            read -r action

            case "$action" in
                "i") handle_tool_installation "${tools_to_show[@]}" ;;
                "f") handle_category_filter ;;
                "c") category_filter="" ;;
                "n")
                    if [[ $current_page -lt $total_pages ]]; then
                        ((current_page++))
                    fi
                    ;;
                "p")
                    if [[ $current_page -gt 1 ]]; then
                        ((current_page--))
                    fi
                    ;;
                "d") handle_tool_details "${tools_to_show[@]}" ;;
                "b") break ;;
                *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        fi
    done
}

# Handle tool installation from browser
handle_tool_installation() {
    local tools=("$@")
    local available_tools=()

    # Filter only missing tools
    for tool in "${tools[@]}"; do
        local status=$(get_cached_tool_status "$tool")
        if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
            available_tools+=("$tool")
        fi
    done

    if [[ ${#available_tools[@]} -eq 0 ]]; then
        echo "${YELLOW}All tools on this page are already installed${RESET}"
        echo "${CYAN}Press Enter to continue...${RESET}"
        read -r
        return
    fi

    # Show selection prompt
    local selected_tools
    selected_tools=$(show_tool_selection_prompt "${available_tools[@]}")

    if [[ -n "$selected_tools" ]]; then
        if show_installation_confirmation $selected_tools; then
            local successful=0
            local failed=0

            while IFS= read -r tool; do
                [[ -z "$tool" ]] && continue
                if install_tool "$tool" false true; then
                    ((successful++))
                else
                    ((failed++))
                fi
            done <<< "$selected_tools"

            show_completion_message "$successful" "$failed"
        fi
    fi

    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

# Handle category filter
handle_category_filter() {
    local categories
    categories=$(get_tool_categories)

    if command_exists gum; then
        category_filter=$(gum choose $categories --header "Select category:")
    else
        echo "Available categories:"
        local i=1
        while IFS= read -r category; do
            echo "  $i) $category"
            ((i++))
        done <<< "$categories"

        echo -n "${CYAN}Choose category: ${RESET}"
        read -r choice
        category_filter=$(echo "$categories" | sed -n "${choice}p")
    fi
}

# Handle tool details
handle_tool_details() {
    local tools=("$@")

    echo -n "${CYAN}Enter tool number (1-${#tools[@]}): ${RESET}"
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#tools[@]} ]]; then
        local tool="${tools[$((choice - 1))]}"
        show_tool_details "$tool"
    else
        echo "${RED}Invalid selection${RESET}"
    fi

    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

# Show tool details
show_tool_details() {
    local tool="$1"

    clear
    show_ui_header "Tool Details: $tool"

    if ! tool_exists "$tool"; then
        echo "${RED}Tool not found: $tool${RESET}"
        return
    fi

    local tool_index=$(find_tool_index "$tool")
    local description=$(get_tool_description "$tool_index")
    local category=$(get_tool_category "$tool_index)
    local status=$(get_cached_tool_status "$tool")
    local version=$(get_cached_tool_version "$tool")
    local size=$(get_tool_size "$tool_index")
    local benefit=$(get_tool_benefit "$tool_index")
    local priority=$(get_tool_priority "$tool_index")
    local capabilities=$(get_tool_capabilities "$tool_index")

    echo "${CYAN}Basic Information:${RESET}"
    echo "  Name: ${GREEN}$tool${RESET}"
    echo "  Category: $category"
    echo "  Description: $description"
    echo "  Size: $size"
    echo "  Priority: $priority"
    echo ""

    echo "${CYAN}Status:${RESET}"
    echo "  Installed: $([[ "$status" == "$DEPS_STATUS_INSTALLED" ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}")"
    if [[ -n "$version" ]]; then
        echo "  Version: $version"
    fi
    echo ""

    if [[ -n "$capabilities" ]]; then
        echo "${CYAN}Capabilities:${RESET}"
        IFS=',' read -ra cap_list <<< "$capabilities"
        for cap in "${cap_list[@]}"; do
            echo "  • ${YELLOW}$(trim "$cap")${RESET}"
        done
        echo ""
    fi

    echo "${CYAN}Benefits:${RESET}"
    echo "  $benefit"
    echo ""

    if [[ "$status" != "$DEPS_STATUS_INSTALLED" ]]; then
        local package_manager
        package_manager=$(get_preferred_package_manager "$tool")
        local package_name
        package_name=$(get_package_name "$tool" "$package_manager")
        echo "${CYAN}Installation:${RESET}"
        echo "  Package manager: $package_manager"
        echo "  Package name: $package_name"
        echo ""
    fi
}

# Show recommendations menu
show_recommendations_menu() {
    while true; do
        clear
        show_ui_header "Tool Recommendations"

        echo "${BOLD}${CYAN}Recommendation Types${RESET}"
        echo "===================="
        echo ""

        if command_exists gum; then
            local choice
            choice=$(gum choose \
                "Comprehensive Analysis" \
                "Context-Based" \
                "Priority-Based" \
                "Capability-Based" \
                "Back to Main Menu" \
                --header="Choose recommendation type:")

            case "$choice" in
                "Comprehensive Analysis") show_recommendations "comprehensive" ;;
                "Context-Based") show_recommendations "context" ;;
                "Priority-Based") show_recommendations "priority" ;;
                "Capability-Based") show_recommendations "capability" ;;
                "Back to Main Menu") break ;;
            esac
        else
            echo "1) Comprehensive Analysis"
            echo "2) Context-Based"
            echo "3) Priority-Based"
            echo "4) Capability-Based"
            echo "0) Back to Main Menu"
            echo ""

            echo -n "${CYAN}Choose option (0-4): ${RESET}"
            read -r choice

            case "$choice" in
                1) show_recommendations "comprehensive" ;;
                2) show_recommendations "context" ;;
                3) show_recommendations "priority" ;;
                4) show_recommendations "capability" ;;
                0) break ;;
                *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        fi

        if [[ $? -eq 0 ]]; then
            echo "${CYAN}Press Enter to continue...${RESET}"
            read -r
        fi
    done
}

# Show configuration menu
show_configuration_menu() {
    while true; do
        clear
        show_ui_header "Configuration Management"

        echo "${BOLD}${CYAN}Configuration Options${RESET}"
        echo "======================="
        echo ""

        if command_exists gum; then
            local choice
            choice=$(gum choose \
                "View Current Configuration" \
                "Change Installation Settings" \
                "Modify Package Manager Preferences" \
                "Reset to Defaults" \
                "Back to Main Menu" \
                --header="Choose configuration option:")

            case "$choice" in
                "View Current Configuration") show_deps_config "all" ;;
                "Change Installation Settings") handle_installation_settings ;;
                "Modify Package Manager Preferences") handle_package_manager_settings ;;
                "Reset to Defaults") handle_config_reset ;;
                "Back to Main Menu") break ;;
            esac
        else
            echo "1) View Current Configuration"
            echo "2) Change Installation Settings"
            echo "3) Modify Package Manager Preferences"
            echo "4) Reset to Defaults"
            echo "0) Back to Main Menu"
            echo ""

            echo -n "${CYAN}Choose option (0-4): ${RESET}"
            read -r choice

            case "$choice" in
                1) show_deps_config "all" ;;
                2) handle_installation_settings ;;
                3) handle_package_manager_settings ;;
                4) handle_config_reset ;;
                0) break ;;
                *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        fi

        if [[ $? -eq 0 ]]; then
            echo "${CYAN}Press Enter to continue...${RESET}"
            read -r
        fi
    done
}

# Show statistics menu
show_statistics_menu() {
    while true; do
        clear
        show_ui_header "System Statistics"

        echo "${BOLD}${CYAN}Statistics Categories${RESET}"
        echo "======================="
        echo ""

        if command_exists gum; then
            local choice
            choice=$(gum choose \
                "Dependency Statistics" \
                "Installation History" \
                "Version Compatibility" \
                "System Capabilities" \
                "Cache Information" \
                "Back to Main Menu" \
                --header="Choose statistics category:")

            case "$choice" in
                "Dependency Statistics") show_dependencies_stats ;;
                "Installation History") show_installation_history ;;
                "Version Compatibility") show_version_compatibility_report ;;
                "System Capabilities") show_capability_analysis ;;
                "Cache Information") show_cache_info ;;
                "Back to Main Menu") break ;;
            esac
        else
            echo "1) Dependency Statistics"
            echo "2) Installation History"
            echo "3) Version Compatibility"
            echo "4) System Capabilities"
            echo "5) Cache Information"
            echo "0) Back to Main Menu"
            echo ""

            echo -n "${CYAN}Choose option (0-5): ${RESET}"
            read -r choice

            case "$choice" in
                1) show_dependencies_stats ;;
                2) show_installation_history ;;
                3) show_version_compatibility_report ;;
                4) show_capability_analysis ;;
                5) show_cache_info ;;
                0) break ;;
                *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        fi

        if [[ $? -eq 0 ]]; then
            echo "${CYAN}Press Enter to continue...${RESET}"
            read -r
        fi
    done
}

# Placeholder functions for menu items that need more implementation
handle_installation_settings() {
    echo "${YELLOW}Installation settings management${RESET}"
    echo "This feature allows you to configure:"
    echo "• Auto-install preferences"
    echo "• Backup settings"
    echo "• Installation timeouts"
    echo ""
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

handle_package_manager_settings() {
    echo "${YELLOW}Package manager preferences${RESET}"
    echo "This feature allows you to:"
    echo "• Set preferred package manager order"
    echo "• Configure package manager options"
    echo "• Add custom package sources"
    echo ""
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

handle_config_reset() {
    echo "${YELLOW}Reset configuration to defaults?${RESET}"
    echo -n "Are you sure? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        reset_deps_config "user"
        echo "${GREEN}Configuration reset to defaults${RESET}"
    fi
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

show_uninstall_menu() {
    echo "${YELLOW}Tool uninstallation${RESET}"
    echo "This feature allows you to:"
    echo "• Select tools to uninstall"
    echo "• Review dependencies"
    echo "• Perform safe removal"
    echo ""
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

show_update_menu() {
    echo "${YELLOW}Tool updates${RESET}"
    echo "This feature allows you to:"
    echo "• Check for tool updates"
    echo "• Update installed tools"
    echo "• Review update changelogs"
    echo ""
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

show_system_information() {
    clear
    show_ui_header "System Information"

    echo "${CYAN}System Information:${RESET}"
    echo "========================"
    echo ""

    # Show dependency system info
    show_dependencies_info

    echo ""
    echo "${CYAN}Platform Information:${RESET}"
    local platform_info
    platform_info=$(get_platform_info)
    IFS='|' read -r platform distro version arch <<< "$platform_info"
    echo "  Platform: $platform"
    echo "  Distribution: $distro"
    echo "  Version: $version"
    echo "  Architecture: $arch"
    echo ""

    echo "${CYAN}Package Managers:${RESET}"
    local available_managers
    available_managers=$(detect_package_managers)
    if [[ -n "$available_managers" ]]; then
        while IFS= read -r manager; do
            [[ -n "$manager" ]] && echo "  • $manager"
        done <<< "$available_managers"
    else
        echo "  ${GRAY}No package managers detected${RESET}"
    fi

    echo ""
    echo "${CYAN}System Capabilities:${RESET}"
    if command_exists gum; then
        gum format --type markdown "• Interactive Terminal: $([[ -t 0 && -t 1 ]] && echo "✅" || echo "❌")"
        gum format --type markdown "• Root Access: $([[ $EUID -eq 0 ]] && echo "✅" || echo "❌")"
        gum format --type markdown "• Network Access: $(is_connected && echo "✅" || echo "❌")"
        gum format --type markdown "• Color Support: $(supports_colors && echo "✅" || echo "❌")"
    else
        echo "  • Interactive Terminal: $([[ -t 0 && -t 1 ]] && echo "Yes" || echo "No")"
        echo "  • Root Access: $([[ $EUID -eq 0 ]] && echo "Yes" || echo "No")"
        echo "  • Network Access: $(is_connected && echo "Yes" || echo "No")"
        echo "  • Color Support: $(supports_colors && echo "Yes" || echo "No")"
    fi

    echo ""
    echo "${CYAN}Press Enter to continue...${RESET}"
    read -r
}

# Export main function
export -f init_deps_ui show_main_menu

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_deps_ui
    show_main_menu
fi

log_deps_debug "Dependency management UI loaded"