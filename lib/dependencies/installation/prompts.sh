#!/usr/bin/env bash

# FUB Dependencies Installation Prompts
# Interactive prompts and user guidance for tool installation

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Import theme system if available
if [[ -f "${FUB_ROOT_DIR}/lib/theme.sh" ]]; then
    source "${FUB_ROOT_DIR}/lib/theme.sh"
    init_theme
fi

# Import UI system if available
if [[ -f "${FUB_ROOT_DIR}/lib/ui.sh" ]]; then
    source "${FUB_ROOT_DIR}/lib/ui.sh"
fi

# Prompt state
DEPS_PROMPT_INTERACTIVE=true
DEPS_PROMPT_VERBOSITY="normal"  # quiet, normal, verbose

# Initialize prompt system
init_installation_prompts() {
    log_deps_debug "Initializing installation prompt system..."

    # Check if we're in an interactive environment
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        DEPS_PROMPT_INTERACTIVE=false
        log_deps_debug "Non-interactive environment detected, prompts disabled"
    fi

    # Set verbosity from config
    if [[ "$(get_deps_config silent_mode)" == "true" ]]; then
        DEPS_PROMPT_VERBOSITY="quiet"
    elif [[ "$(get_deps_config verbose_mode)" == "true" ]]; then
        DEPS_PROMPT_VERBOSITY="verbose"
    fi

    log_deps_debug "Installation prompt system initialized (interactive: $DEPS_PROMPT_INTERACTIVE, verbosity: $DEPS_PROMPT_VERBOSITY)"
}

# Show welcome message
show_welcome_message() {
    if [[ "$DEPS_PROMPT_VERBOSITY" == "quiet" ]]; then
        return 0
    fi

    echo ""
    if command_exists gum; then
        gum style \
            --foreground 212 \
            --border double \
            --border-foreground 212 \
            --align center \
            --margin "1 2" \
            --padding "1 2" \
            "FUB Dependencies Manager" \
            "Enhance your system with optional tools"
    else
        echo "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
        echo "${BOLD}${CYAN}║     FUB Dependencies Manager       ║${RESET}"
        echo "${BOLD}${CYAN}║  Enhance your system with tools     ║${RESET}"
        echo "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
    fi
    echo ""
}

# Show tool selection prompt
show_tool_selection_prompt() {
    local available_tools=("$@")

    if [[ ${#available_tools[@]} -eq 0 ]]; then
        echo "${YELLOW}No additional tools available for installation.${RESET}"
        return 1
    fi

    echo ""
    echo "${BOLD}${CYAN}Available Tools for Installation${RESET}"
    echo "=================================="
    echo ""

    if [[ "$DEPS_PROMPT_INTERACTIVE" == "true" && command_exists gum ]]; then
        # Use gum for interactive selection
        local selected_tools
        selected_tools=$(printf '%s\n' "${available_tools[@]}" | gum choose --no-limit --header "Select tools to install (space to toggle, enter to confirm):")

        if [[ -n "$selected_tools" ]]; then
            echo "$selected_tools"
            return 0
        else
            echo ""
            return 1
        fi
    else
        # Fallback to numbered list
        echo "Select tools to install (comma-separated numbers, or 'all'):"
        echo ""

        for i in "${!available_tools[@]}"; do
            local tool="${available_tools[$i]}"
            local tool_index=$(find_tool_index "$tool")
            local description=$(get_tool_description "$tool_index")
            local size=$(get_tool_size "$tool_index")

            printf "${GREEN}%3d${RESET}) ${CYAN}%-20s${RESET} ${GRAY}%-8s${RESET} %s\n" \
                   $((i + 1)) "$tool" "$size" "$description"
        done
        echo ""

        echo -n "Your choice: "
        read -r selection

        if [[ -z "$selection" ]]; then
            echo ""
            return 1
        fi

        if [[ "$selection" == "all" ]]; then
            printf '%s\n' "${available_tools[@]}"
        else
            # Parse comma-separated numbers
            IFS=',' read -ra selections <<< "$selection"
            local selected_tools=()

            for sel in "${selections[@]}"; do
                sel=$(trim "$sel")
                if [[ "$sel" =~ ^[0-9]+$ ]]; then
                    local idx=$((sel - 1))
                    if [[ $idx -ge 0 && $idx -lt ${#available_tools[@]} ]]; then
                        selected_tools+=("${available_tools[$idx]}")
                    else
                        echo "${RED}Invalid selection: $sel${RESET}" >&2
                    fi
                fi
            done

            if [[ ${#selected_tools[@]} -gt 0 ]]; then
                printf '%s\n' "${selected_tools[@]}"
            else
                echo ""
                return 1
            fi
        fi
    fi
}

# Show installation confirmation
show_installation_confirmation() {
    local tools=("$@")
    local total_size=0

    if [[ ${#tools[@]} -eq 0 ]]; then
        return 1
    fi

    echo ""
    echo "${BOLD}${YELLOW}Installation Summary${RESET}"
    echo "====================="
    echo ""

    # Calculate total size and show details
    for tool in "${tools[@]}"; do
        local tool_index=$(find_tool_index "$tool")
        local description=$(get_tool_description "$tool_index")
        local size=$(get_tool_size "$tool_index")
        local package_manager
        package_manager=$(get_preferred_package_manager "$tool")
        local package_name
        package_name=$(get_package_name "$tool" "$package_manager")

        printf "${CYAN}%-20s${RESET} ${GRAY}%-10s${RESET} %s\n" "$tool" "$size" "$description"
        printf "${GRAY}%-20s${RESET} ${YELLOW}via %s${RESET} %s\n" "" "$package_manager" "$package_name"
        echo ""

        # Add to total size (simplified calculation)
        case "$size" in
            *MB) total_size=$((total_size + $(echo "$size" | sed 's/MB//'))) ;;
            *KB) total_size=$((total_size + $(echo "$size" | sed 's/KB//') / 1024)) ;;
            *GB) total_size=$((total_size + $(echo "$size" | sed 's/GB//') * 1024)) ;;
        esac
    done

    echo "${YELLOW}Total estimated size: ${total_size}MB${RESET}"
    echo ""

    # Show confirmation
    if [[ "$DEPS_PROMPT_INTERACTIVE" == "true" && command_exists gum ]]; then
        gum confirm "Proceed with installation of ${#tools[@]} tools?" --default=false
        return $?
    else
        echo -n "${YELLOW}Proceed with installation? [y/N]:${RESET} "
        read -r response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# Show installation progress
show_installation_progress() {
    local current_tool="$1"
    local current_index="$2"
    local total_tools="$3"
    local package_manager="$4"

    if [[ "$DEPS_PROMPT_VERBOSITY" == "quiet" ]]; then
        return 0
    fi

    echo ""
    if command_exists gum; then
        gum spin --spinner dot --title "Installing $current_tool ($current_index/$total_tools)..." -- sleep 1 &
        local spinner_pid=$!

        # Create progress bar
        local progress=$(( (current_index * 100) / total_tools ))
        gum progress --percentage "$progress" --title "Overall Progress"

        kill $spinner_pid 2>/dev/null || true
    else
        local progress=$(( (current_index * 20) / total_tools ))
        local bar=""
        for ((i=0; i<20; i++)); do
            if [[ $i -lt $progress ]]; then
                bar="${bar}█"
            else
                bar="${bar}░"
            fi
        done

        printf "\r${YELLOW}Installing${RESET} $current_tool ${GRAY}($current_index/$total_tools)${RESET} ${GREEN}[$bar]${RESET}"
    fi
}

# Show installation success
show_installation_success() {
    local tool_name="$1"
    local duration="$2"

    if [[ "$DEPS_PROMPT_VERBOSITY" == "quiet" ]]; then
        return 0
    fi

    echo ""
    if command_exists gum; then
        gum style \
            --foreground 46 \
            --border rounded \
            --border-foreground 46 \
            "✅ Successfully installed $tool_name (${duration}s)"
    else
        echo "${GREEN}✅ Successfully installed $tool_name${RESET} ${GRAY}(${duration}s)${RESET}"
    fi
}

# Show installation failure
show_installation_failure() {
    local tool_name="$1"
    local error_message="$2"

    if [[ "$DEPS_PROMPT_VERBOSITY" == "quiet" ]]; then
        return 0
    fi

    echo ""
    if command_exists gum; then
        gum style \
            --foreground 196 \
            --border rounded \
            --border-foreground 196 \
            "❌ Failed to install $tool_name"
        if [[ -n "$error_message" ]]; then
            gum style --foreground 208 "Error: $error_message"
        fi
    else
        echo "${RED}❌ Failed to install $tool_name${RESET}"
        if [[ -n "$error_message" ]]; then
            echo "${YELLOW}Error: $error_message${RESET}"
        fi
    fi
}

# Show post-installation tips
show_post_installation_tips() {
    local tool_name="$1"

    if [[ "$DEPS_PROMPT_VERBOSITY" != "verbose" ]]; then
        return 0
    fi

    echo ""
    echo "${YELLOW}💡 Tips for $tool_name:${RESET}"

    case "$tool_name" in
        "gum")
            echo "  • Try: ${CYAN}gum input${RESET} - for interactive input"
            echo "  • Try: ${CYAN}gum choose${RESET} - for interactive selection"
            echo "  • Try: ${CYAN}gum confirm${RESET} - for yes/no prompts"
            ;;
        "btop")
            echo "  • Run: ${CYAN}btop${RESET} - to view system resource usage"
            echo "  • Press ${YELLOW}q${RESET} to quit"
            echo "  • Press ${YELLOW}m${RESET} to switch between display modes"
            ;;
        "fd"|"fd-find")
            echo "  • Try: ${CYAN}fd 'pattern'${RESET} - to find files"
            echo "  • Try: ${CYAN}fd -e 'txt'${RESET} - to find by extension"
            echo "  • Try: ${CYAN}fd --hidden${RESET} - to include hidden files"
            ;;
        "ripgrep")
            echo "  • Try: ${CYAN}rg 'pattern'${RESET} - to search in files"
            echo "  • Try: ${CYAN}rg -i 'pattern'${RESET} - for case-insensitive search"
            echo "  • Try: ${CYAN}rg --type py 'pattern'${RESET} - to search Python files"
            ;;
        "dust")
            echo "  • Run: ${CYAN}dust${RESET} - to analyze disk usage"
            echo "  • Try: ${CYAN}dust -d 2${RESET} - to limit depth"
            echo "  • Try: ${CYAN}dust -r${RESET} - to reverse sort"
            ;;
        "duf")
            echo "  • Run: ${CYAN}duf${RESET} - to show disk usage"
            echo "  • Try: ${CYAN}duf --hide-fs tmpfs${RESET} - to hide tmpfs"
            ;;
        "procs")
            echo "  • Run: ${CYAN}procs${RESET} - to view processes"
            echo "  • Try: ${CYAN}procs --tree${RESET} - for process tree view"
            ;;
        "bat")
            echo "  • Use: ${CYAN}bat file.txt${RESET} instead of cat"
            echo "  • Try: ${CYAN}bat --style=numbers file.txt${RESET} - for line numbers"
            ;;
        "exa")
            echo "  • Use: ${CYAN}exa${RESET} instead of ls"
            echo "  • Try: ${CYAN}exa -la${RESET} - for detailed list"
            echo "  • Try: ${CYAN}exa --tree${RESET} - for tree view"
            ;;
        "lazygit")
            echo "  • Run: ${CYAN}lazygit${RESET} in a git repository"
            echo "  • Press ${YELLOW}?${RESET} for help and keyboard shortcuts"
            ;;
        "neofetch")
            echo "  • Run: ${CYAN}neofetch${RESET} - to show system information"
            echo "  • Try: ${CYAN}neofetch --ascii_distro ubuntu${RESET} - for specific logo"
            ;;
        "fzf")
            echo "  • Try: ${CYAN}find . | fzf${RESET} - interactive file search"
            echo "  • Try: ${CYAN}history | fzf${RESET} - interactive history search"
            ;;
        *)
            echo "  • Run ${CYAN}$tool_name --help${RESET} for usage information"
            ;;
    esac

    echo ""
}

# Show completion message
show_completion_message() {
    local successful_installs="$1"
    local failed_installs="$2"
    local total_tools=$((successful_installs + failed_installs))

    if [[ "$DEPS_PROMPT_VERBOSITY" == "quiet" ]]; then
        return 0
    fi

    echo ""
    if command_exists gum; then
        if [[ $failed_installs -eq 0 ]]; then
            gum style \
                --foreground 46 \
                --border double \
                --border-foreground 46 \
                --align center \
                --margin "1 2" \
                --padding "1 2" \
                "🎉 Installation Complete!" \
                "All $successful_installs tools installed successfully"
        else
            gum style \
                --foreground 208 \
                --border double \
                --border-foreground 208 \
                --align center \
                --margin "1 2" \
                --padding "1 2" \
                "Installation Finished" \
                "$successful_installs successful, $failed_installs failed"
        fi
    else
        echo ""
        echo "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
        if [[ $failed_installs -eq 0 ]]; then
            echo "${BOLD}${CYAN}║        🎉 Installation Complete!       ║${RESET}"
            echo "${BOLD}${CYAN}║  All $successful_installs tools installed  ║${RESET}"
        else
            echo "${BOLD}${YELLOW}║         Installation Finished         ║${RESET}"
            echo "${BOLD}${YELLOW}║  $successful_installs successful, $failed_installs failed  ║${RESET}"
        fi
        echo "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
    fi
    echo ""
}

# Show tool recommendations prompt
show_recommendations_prompt() {
    local recommended_tools=("$@")

    if [[ ${#recommended_tools[@]} -eq 0 ]]; then
        return 1
    fi

    echo ""
    echo "${BOLD}${MAGENTA}🌟 Recommended Tools${RESET}"
    echo "======================"
    echo ""

    if command_exists gum; then
        # Show recommendations with gum
        echo "Based on your system, we recommend installing these tools:"
        echo ""

        for tool in "${recommended_tools[@]}"; do
            local tool_index=$(find_tool_index "$tool")
            local benefit=$(get_tool_benefit "$tool_index")
            gum format --type markdown "• **$tool**: $benefit"
        done

        echo ""
        if gum confirm "Would you like to install these recommended tools?" --default=true; then
            printf '%s\n' "${recommended_tools[@]}"
            return 0
        fi
    else
        # Fallback to simple prompt
        echo "${YELLOW}Based on your system, we recommend installing:${RESET}"
        for tool in "${recommended_tools[@]}"; do
            echo "  • ${CYAN}$tool${RESET}"
        done
        echo ""

        echo -n "${YELLOW}Install these recommended tools? [Y/n]:${RESET} "
        read -r response
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            printf '%s\n' "${recommended_tools[@]}"
            return 0
        fi
    fi

    return 1
}

# Interactive installation wizard
run_installation_wizard() {
    show_welcome_message

    # First, run dependency detection
    echo "${YELLOW}Scanning for available tools...${RESET}"
    detect_all_tools false

    # Get missing tools
    local missing_tools=()
    ensure_registry_loaded

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local tool_name=$(get_tool_name "$i")
        local status=$(get_cached_tool_status "$tool_name")

        if [[ "$status" == "$DEPS_STATUS_NOT_INSTALLED" ]]; then
            missing_tools+=("$tool_name")
        fi
    done

    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        echo "${GREEN}All recommended tools are already installed!${RESET}"
        return 0
    fi

    # Show recommendations first
    local recommended_tools=()
    for tool in "${missing_tools[@]}"; do
        local tool_index=$(find_tool_index "$tool")
        local priority=$(get_tool_priority "$tool_index")
        if [[ $priority -ge 80 ]]; then
            recommended_tools+=("$tool")
        fi
    done

    local tools_to_install=()

    if [[ ${#recommended_tools[@]} -gt 0 ]]; then
        if show_recommendations_prompt "${recommended_tools[@]}"; then
            tools_to_install=("${recommended_tools[@]}")
        fi
    fi

    # If no recommendations were selected, show full list
    if [[ ${#tools_to_install[@]} -eq 0 ]]; then
        local selected_tools
        selected_tools=$(show_tool_selection_prompt "${missing_tools[@]}")

        if [[ -n "$selected_tools" ]]; then
            while IFS= read -r tool; do
                [[ -n "$tool" ]] && tools_to_install+=("$tool")
            done <<< "$selected_tools"
        fi
    fi

    # Install selected tools
    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        if show_installation_confirmation "${tools_to_install[@]}"; then
            local successful=0
            local failed=0

            for i in "${!tools_to_install[@]}"; do
                local tool="${tools_to_install[$i]}"
                local package_manager
                package_manager=$(get_preferred_package_manager "$tool")

                show_installation_progress "$tool" "$((i + 1))" "${#tools_to_install[@]}" "$package_manager"

                if install_tool "$tool" false true; then
                    ((successful++))
                    show_installation_success "$tool" "0"
                    show_post_installation_tips "$tool"
                else
                    ((failed++))
                    show_installation_failure "$tool" ""
                fi
            done

            show_completion_message "$successful" "$failed"
        else
            echo "${YELLOW}Installation cancelled.${RESET}"
        fi
    else
        echo "${YELLOW}No tools selected for installation.${RESET}"
    fi
}

# Export functions
export -f init_installation_prompts show_welcome_message show_tool_selection_prompt
export -f show_installation_confirmation show_installation_progress show_installation_success
export -f show_installation_failure show_post_installation_tips show_completion_message
export -f show_recommendations_prompt run_installation_wizard

log_deps_debug "Installation prompts system loaded"