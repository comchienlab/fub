#!/bin/bash
# Fub - Startup Applications Manager
# Interactive startup application management for Ubuntu
#
# Usage:
#   startup.sh          # Launch interactive startup manager
#   startup.sh --help   # Show help information

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Check and install fzf if needed
ensure_fzf() {
    if command -v fzf &>/dev/null; then
        return 0
    fi

    echo -e "${YELLOW}fzf not found.${NC} Installing fzf for better interaction..."

    # Try to install via apt first
    if command -v apt-get &>/dev/null; then
        if sudo apt-get install -y fzf &>/dev/null; then
            echo -e "${GREEN}✓${NC} fzf installed via apt"
            return 0
        fi
    fi

    echo -e "${RED}Please install fzf to use interactive startup manager${NC}"
    return 1
}

# Get list of startup applications
list_startup_apps() {
    local autostart_dirs=(
        "$HOME/.config/autostart"
        "/etc/xdg/autostart"
    )

    local -a apps=()

    for dir in "${autostart_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r desktop_file; do
                local app_name=""
                local app_exec=""
                local hidden="false"
                local source_dir=$(dirname "$desktop_file")

                # Parse .desktop file
                while IFS='=' read -r key value; do
                    case "$key" in
                        "Name")
                            app_name="$value"
                            ;;
                        "Exec")
                            app_exec="$value"
                            ;;
                        "Hidden")
                            hidden="$value"
                            ;;
                    esac
                done < "$desktop_file"

                # Skip if no name found
                [[ -z "$app_name" ]] && continue

                # Mark location (user vs system)
                local location="system"
                [[ "$source_dir" == "$HOME/.config/autostart" ]] && location="user"

                # Mark status
                local status="enabled"
                [[ "$hidden" == "true" ]] && status="disabled"

                # Output format: name|exec|status|location|filepath
                echo "$app_name|$app_exec|$status|$location|$desktop_file"
            done < <(find "$dir" -maxdepth 1 -name "*.desktop" -type f 2>/dev/null || true)
        fi
    done | sort -u
}

# Show startup applications in a formatted way
show_startup_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Startup Applications Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local enabled_count=0
    local disabled_count=0
    local user_count=0
    local system_count=0

    while IFS='|' read -r name exec status location filepath; do
        [[ "$status" == "enabled" ]] && ((enabled_count++))
        [[ "$status" == "disabled" ]] && ((disabled_count++))
        [[ "$location" == "user" ]] && ((user_count++))
        [[ "$location" == "system" ]] && ((system_count++))
    done < <(list_startup_apps)

    local total_count=$((enabled_count + disabled_count))

    if [[ $total_count -eq 0 ]]; then
        echo -e "  ${GRAY}No startup applications found${NC}"
    else
        echo -e "  ${GRAY}Total:${NC}      ${CYAN}$total_count startup applications${NC}"
        echo -e "  ${GRAY}Enabled:${NC}    ${GREEN}$enabled_count active${NC}"
        echo -e "  ${GRAY}Disabled:${NC}   ${YELLOW}$disabled_count inactive${NC}"
        echo ""
        echo -e "  ${GRAY}User apps:${NC}   ${CYAN}$user_count applications${NC}"
        echo -e "  ${GRAY}System apps:${NC} ${CYAN}$system_count applications${NC}"
    fi

    echo ""
}

# Format app entry for fzf
format_app_entry() {
    local name="$1"
    local status="$2"
    local location="$3"

    local status_badge=""
    local status_color=""
    local location_badge=""

    case "$status" in
        enabled)
            status_badge="[ENABLED ]"
            status_color="\033[0;32m" # Green
            ;;
        disabled)
            status_badge="[DISABLED]"
            status_color="\033[1;33m" # Yellow
            ;;
    esac

    case "$location" in
        user)
            location_badge="[USER  ]"
            ;;
        system)
            location_badge="[SYSTEM]"
            ;;
    esac

    printf "${status_color}%s\033[0m \033[0;36m%s\033[0m  %s\n" \
        "$status_badge" "$location_badge" "$name"
}

# Interactive app selector
show_app_selector() {
    local action="$1" # disable, enable, remove

    local header_text=""
    case "$action" in
        disable)
            header_text="Select startup apps to DISABLE:"
            ;;
        enable)
            header_text="Select startup apps to ENABLE:"
            ;;
        remove)
            header_text="Select startup apps to REMOVE:"
            ;;
    esac

    # Create temp files
    local temp_display=$(mktemp)
    local temp_mapping=$(mktemp)

    # Build display list and mapping
    while IFS='|' read -r name exec status location filepath; do
        # Filter based on action
        case "$action" in
            disable)
                [[ "$status" != "enabled" ]] && continue
                ;;
            enable)
                [[ "$status" != "disabled" ]] && continue
                ;;
            remove)
                [[ "$location" != "user" ]] && continue
                ;;
        esac

        format_app_entry "$name" "$status" "$location" >> "$temp_display"
        echo "$name|$filepath" >> "$temp_mapping"
    done < <(list_startup_apps)

    # Check if any apps available
    if [[ ! -s "$temp_display" ]]; then
        rm -f "$temp_display" "$temp_mapping"
        return 1
    fi

    # Run fzf
    local selections=$(cat "$temp_display" | fzf \
        --ansi \
        --multi \
        --reverse \
        --height=100% \
        --bind="tab:toggle" \
        --bind="ctrl-a:select-all" \
        --bind="ctrl-d:deselect-all" \
        --header="$header_text (Tab: select, Ctrl-A: all, Ctrl-D: none)" \
        --prompt="Select > " \
        --pointer="▶" \
        --color='fg:#d0d0d0,bg:#1c1c1c,hl:#5fd7ff' \
        --color='fg+:#ffffff,bg+:#262626,hl+:#5fd7ff' \
        --color='info:#afaf87,prompt:#719e07,pointer:#af5fff' \
        --color='marker:#87ff00,spinner:#af5fff,header:#87afaf' \
        --preview='echo -e "\033[1;34mStartup Application\033[0m\n" && echo {}' \
        --preview-window=up:3:wrap || true)

    # Process selections
    local selected_files=()
    while IFS= read -r selected_line; do
        [[ -z "$selected_line" ]] && continue

        # Extract app name from selected line (after badges and spaces)
        local app_name=$(echo "$selected_line" | sed -E 's/\x1b\[[0-9;]*m//g' | awk '{$1=$2=""; print $0}' | sed 's/^  *//')

        # Find filepath from mapping
        local filepath=$(grep "^$app_name|" "$temp_mapping" | cut -d'|' -f2)
        [[ -n "$filepath" ]] && selected_files+=("$filepath")
    done <<< "$selections"

    # Cleanup temp files
    rm -f "$temp_display" "$temp_mapping"

    # Output selected files
    printf '%s\n' "${selected_files[@]}"
}

# Disable startup app
disable_app() {
    local desktop_file="$1"
    local basename=$(basename "$desktop_file")

    # Create user override if this is a system app
    if [[ "$desktop_file" == /etc/xdg/autostart/* ]]; then
        mkdir -p "$HOME/.config/autostart"
        cp "$desktop_file" "$HOME/.config/autostart/$basename"
        desktop_file="$HOME/.config/autostart/$basename"
    fi

    # Add Hidden=true
    if grep -q "^Hidden=" "$desktop_file" 2>/dev/null; then
        sed -i 's/^Hidden=.*/Hidden=true/' "$desktop_file"
    else
        echo "Hidden=true" >> "$desktop_file"
    fi
}

# Enable startup app
enable_app() {
    local desktop_file="$1"

    # Remove Hidden=true
    if grep -q "^Hidden=" "$desktop_file" 2>/dev/null; then
        sed -i '/^Hidden=/d' "$desktop_file"
    fi
}

# Remove startup app
remove_app() {
    local desktop_file="$1"

    # Only remove user apps
    if [[ "$desktop_file" == "$HOME/.config/autostart/"* ]]; then
        rm -f "$desktop_file"
    fi
}

# Disable selected apps
disable_apps() {
    local selected_files=$(show_app_selector "disable")

    if [[ -z "$selected_files" ]]; then
        echo -e "${YELLOW}No apps selected${NC}"
        return 0
    fi

    echo -e "${BLUE}Disabling startup applications...${NC}"
    echo ""

    local count=0
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        local app_name=$(grep "^Name=" "$filepath" 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
        disable_app "$filepath"
        echo -e "  ${GREEN}✓${NC} Disabled: $app_name"
        ((count++))
    done <<< "$selected_files"

    echo ""
    echo -e "${GREEN}✓ Disabled $count startup application(s)${NC}"
    echo ""
}

# Enable selected apps
enable_apps() {
    local selected_files=$(show_app_selector "enable")

    if [[ -z "$selected_files" ]]; then
        echo -e "${YELLOW}No apps selected${NC}"
        return 0
    fi

    echo -e "${BLUE}Enabling startup applications...${NC}"
    echo ""

    local count=0
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        local app_name=$(grep "^Name=" "$filepath" 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
        enable_app "$filepath"
        echo -e "  ${GREEN}✓${NC} Enabled: $app_name"
        ((count++))
    done <<< "$selected_files"

    echo ""
    echo -e "${GREEN}✓ Enabled $count startup application(s)${NC}"
    echo ""
}

# Remove selected apps
remove_apps() {
    local selected_files=$(show_app_selector "remove")

    if [[ -z "$selected_files" ]]; then
        echo -e "${YELLOW}No user apps to remove${NC}"
        return 0
    fi

    echo -e "${BLUE}Removing startup applications...${NC}"
    echo ""

    local count=0
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        local app_name=$(grep "^Name=" "$filepath" 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
        remove_app "$filepath"
        echo -e "  ${GREEN}✓${NC} Removed: $app_name"
        ((count++))
    done <<< "$selected_files"

    echo ""
    echo -e "${GREEN}✓ Removed $count startup application(s)${NC}"
    echo ""
}

# List all apps
list_all_apps() {
    clear_screen
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Startup Applications List                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    while IFS='|' read -r name exec status location filepath; do
        local status_icon="${GREEN}●${NC}"
        [[ "$status" == "disabled" ]] && status_icon="${YELLOW}○${NC}"

        local location_badge="[USER]"
        [[ "$location" == "system" ]] && location_badge="[SYS]"

        echo -e "  $status_icon  ${CYAN}$location_badge${NC}  $name"
        echo -e "      ${GRAY}$exec${NC}"
    done < <(list_startup_apps)

    echo ""
    read -p "Press Enter to continue..."
}

# Interactive startup menu
startup_menu() {
    local options=(
        "Disable Apps"
        "Enable Apps"
        "Remove User Apps"
        "List All Apps"
        "Exit"
    )

    local selection=$(printf '%s\n' "${options[@]}" | fzf \
        --height=12 \
        --reverse \
        --border=rounded \
        --header="Select action:" \
        --prompt="Action > " \
        --pointer="▶" \
        --color='fg:#d0d0d0,bg:#1c1c1c,hl:#5fd7ff' \
        --color='fg+:#ffffff,bg+:#262626,hl+:#5fd7ff' \
        --color='info:#afaf87,prompt:#719e07,pointer:#af5fff' \
        --color='marker:#87ff00,spinner:#af5fff,header:#87afaf')

    echo "$selection"
}

# Main function
main() {
    # Check for help
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat <<EOF
Fub Startup Applications Manager

Interactive startup application management for Ubuntu systems.

Features:
  - View all startup applications (user and system)
  - Enable/disable startup apps
  - Remove user startup apps
  - Multi-select with fzf interface

Usage:
  startup.sh          Launch interactive startup manager
  startup.sh --help   Show this help

Examples:
  # Interactive mode
  fub startup

About Startup Applications:
  - User apps: Located in ~/.config/autostart (can be removed)
  - System apps: Located in /etc/xdg/autostart (can only be disabled)
  - Disabled apps have Hidden=true in their .desktop file

Tips:
  - Disabling unnecessary startup apps improves boot time
  - Use "List All Apps" to see what's running at startup
  - System apps can't be removed, only disabled
  - Changes take effect on next login

EOF
        exit 0
    fi

    # Ensure fzf is available
    ensure_fzf || exit 1

    # Interactive mode
    while true; do
        # Banner
        clear_screen
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║        Fub Startup Applications Manager              ║${NC}"
        echo -e "${GREEN}║          Manage Your Auto-Start Programs              ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Show current status
        show_startup_status

        # Get user selection
        local selected_action=$(startup_menu)

        case "$selected_action" in
            "")
                echo -e "${GRAY}No selection made.${NC}"
                exit 0
                ;;
            "Exit")
                echo -e "${GRAY}Exiting startup manager.${NC}"
                exit 0
                ;;
            "Disable Apps")
                disable_apps
                read -p "Press Enter to continue..."
                ;;
            "Enable Apps")
                enable_apps
                read -p "Press Enter to continue..."
                ;;
            "Remove User Apps")
                remove_apps
                read -p "Press Enter to continue..."
                ;;
            "List All Apps")
                list_all_apps
                ;;
        esac
    done
}

main "$@"
