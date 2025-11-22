#!/bin/bash
# Fub - Nerd Fonts Installer
# Install popular Nerd Fonts for terminal and development

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Nerd Fonts GitHub release URL
NERD_FONTS_RELEASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

# Popular Nerd Fonts with descriptions
declare -A NERD_FONTS=(
    ["JetBrainsMono"]="JetBrains Mono - Clean, modern programming font"
    ["FiraCode"]="Fira Code - Popular font with ligatures"
    ["Hack"]="Hack - Typeface designed for source code"
    ["Meslo"]="Meslo LG - Customized Menlo font"
    ["RobotoMono"]="Roboto Mono - Google's monospace font"
    ["UbuntuMono"]="Ubuntu Mono - Ubuntu's default monospace"
    ["CascadiaCode"]="Cascadia Code - Microsoft's terminal font"
    ["DejaVuSansMono"]="DejaVu Sans Mono - Classic monospace"
    ["SourceCodePro"]="Source Code Pro - Adobe's programming font"
    ["InconsolataGo"]="Inconsolata - Monospace font for code listings"
)

# Font installation directory
FONT_DIR="$HOME/.local/share/fonts/NerdFonts"

# Show banner
show_banner() {
    clear_screen
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Nerd Fonts Installer                     ║${NC}"
    echo -e "${GREEN}║         Install Patched Fonts for Terminals           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if font is already installed
is_font_installed() {
    local font_name="$1"
    [[ -d "$FONT_DIR/$font_name" ]] && [[ -n "$(ls -A "$FONT_DIR/$font_name" 2>/dev/null)" ]]
}

# Get installed fonts list
get_installed_fonts() {
    if [[ ! -d "$FONT_DIR" ]]; then
        return
    fi

    find "$FONT_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort
}

# Download and install a Nerd Font
install_nerd_font() {
    local font_name="$1"
    local font_desc="${NERD_FONTS[$font_name]}"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Installing:${NC} $font_desc"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check if already installed
    if is_font_installed "$font_name"; then
        echo -e "${YELLOW}⚠${NC}  Font already installed"
        read -p "   Reinstall? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            echo -e "${GRAY}   Skipped${NC}"
            return 0
        fi
        rm -rf "$FONT_DIR/$font_name"
    fi

    # Create font directory
    mkdir -p "$FONT_DIR/$font_name"

    # Download URL
    local download_url="$NERD_FONTS_RELEASE/${font_name}.zip"
    local temp_file="/tmp/${font_name}.zip"

    # Download font
    echo -e "  ${BLUE}→${NC} Downloading $font_name..."
    if command -v wget &>/dev/null; then
        if wget -q --show-progress --timeout=30 -O "$temp_file" "$download_url" 2>&1 | \
            grep --line-buffered -o "[0-9]*%" | \
            while read -r percentage; do
                printf "\r  ${BLUE}→${NC} Progress: ${GREEN}%s${NC}" "$percentage"
            done; then
            echo ""
        else
            echo ""
            echo -e "  ${RED}✗${NC} Download failed"
            rm -f "$temp_file"
            return 1
        fi
    elif command -v curl &>/dev/null; then
        if curl -# -L -o "$temp_file" "$download_url"; then
            echo ""
        else
            echo ""
            echo -e "  ${RED}✗${NC} Download failed"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} wget or curl required"
        return 1
    fi

    # Extract font
    echo -e "  ${BLUE}→${NC} Extracting fonts..."
    if ! unzip -q -o "$temp_file" -d "$FONT_DIR/$font_name" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Extraction failed"
        rm -f "$temp_file"
        rm -rf "$FONT_DIR/$font_name"
        return 1
    fi

    # Remove Windows-specific files and non-font files
    find "$FONT_DIR/$font_name" -type f ! \( -name "*.ttf" -o -name "*.otf" \) -delete 2>/dev/null || true

    # Count installed fonts
    local font_count=$(find "$FONT_DIR/$font_name" -type f \( -name "*.ttf" -o -name "*.otf" \) | wc -l)

    # Cleanup
    rm -f "$temp_file"

    # Update font cache
    echo -e "  ${BLUE}→${NC} Updating font cache..."
    if fc-cache -f "$FONT_DIR/$font_name" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Successfully installed $font_name (${font_count} font files)"
    else
        echo -e "${YELLOW}⚠${NC}  Font installed but cache update failed (non-critical)"
    fi

    return 0
}

# Uninstall a Nerd Font
uninstall_nerd_font() {
    local font_name="$1"

    if ! is_font_installed "$font_name"; then
        echo -e "${YELLOW}Font not installed:${NC} $font_name"
        return 1
    fi

    echo -e "  ${BLUE}→${NC} Removing $font_name..."
    if rm -rf "$FONT_DIR/$font_name"; then
        echo -e "  ${GREEN}✓${NC} Successfully removed $font_name"
        fc-cache -f &>/dev/null || true
        return 0
    else
        echo -e "  ${RED}✗${NC} Failed to remove $font_name"
        return 1
    fi
}

# Show font selection menu
show_font_menu() {
    local selected="${1:-1}"

    echo ""
    echo -e "${CYAN}Available Nerd Fonts:${NC}"
    echo ""

    local idx=1
    local -a font_keys=()

    # Sort fonts by name
    while IFS= read -r font_name; do
        font_keys+=("$font_name")
    done < <(printf '%s\n' "${!NERD_FONTS[@]}" | sort)

    for font_name in "${font_keys[@]}"; do
        local font_desc="${NERD_FONTS[$font_name]}"
        local is_selected="$([[ $selected -eq $idx ]] && echo true || echo false)"
        local installed_mark=""

        if is_font_installed "$font_name"; then
            installed_mark=" ${GREEN}[Installed]${NC}"
        fi

        if [[ "$is_selected" == "true" ]]; then
            echo -e "${GREEN}▶${NC} $idx. $font_desc$installed_mark"
        else
            echo -e "  $idx. $font_desc$installed_mark"
        fi

        ((idx++))
    done

    echo ""
    echo -e "${CYAN}Other Options:${NC}"
    echo ""

    local option_install_all=$idx
    local is_selected="$([[ $selected -eq $option_install_all ]] && echo true || echo false)"
    if [[ "$is_selected" == "true" ]]; then
        echo -e "${GREEN}▶${NC} $option_install_all. Install All Popular Fonts"
    else
        echo -e "  $option_install_all. Install All Popular Fonts"
    fi

    ((idx++))
    local option_uninstall=$idx
    is_selected="$([[ $selected -eq $option_uninstall ]] && echo true || echo false)"
    if [[ "$is_selected" == "true" ]]; then
        echo -e "${GREEN}▶${NC} $option_uninstall. Uninstall Fonts"
    else
        echo -e "  $option_uninstall. Uninstall Fonts"
    fi

    ((idx++))
    local option_quit=$idx
    is_selected="$([[ $selected -eq $option_quit ]] && echo true || echo false)"
    if [[ "$is_selected" == "true" ]]; then
        echo -e "${GREEN}▶${NC} $option_quit. Back to Main Menu"
    else
        echo -e "  $option_quit. Back to Main Menu"
    fi

    echo ""
    if [[ -t 0 ]]; then
        echo -e "${GRAY}↑/↓ Navigate  |  Enter Select  |  Q Quit${NC}"
    fi
}

# Interactive font selection
interactive_font_menu() {
    local current_option=1
    local -a font_keys=()

    # Get sorted font keys
    while IFS= read -r font_name; do
        font_keys+=("$font_name")
    done < <(printf '%s\n' "${!NERD_FONTS[@]}" | sort)

    local total_fonts=${#font_keys[@]}
    local option_install_all=$((total_fonts + 1))
    local option_uninstall=$((total_fonts + 2))
    local option_quit=$((total_fonts + 3))
    local max_option=$option_quit

    hide_cursor
    trap show_cursor EXIT

    while true; do
        clear_screen
        show_banner
        show_font_menu "$current_option"

        local key
        if ! key=$(read_key); then
            continue
        fi

        case "$key" in
            "UP") ((current_option > 1)) && ((current_option--)) ;;
            "DOWN") ((current_option < max_option)) && ((current_option++)) ;;
            "ENTER")
                show_cursor

                if [[ $current_option -le $total_fonts ]]; then
                    # Install individual font
                    local font_name="${font_keys[$((current_option - 1))]}"
                    install_nerd_font "$font_name"
                    echo ""
                    read -p "Press Enter to continue..."
                    hide_cursor

                elif [[ $current_option -eq $option_install_all ]]; then
                    # Install all fonts
                    echo ""
                    echo -e "${YELLOW}Install all fonts?${NC} This will download ~200MB"
                    read -p "Continue? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        for font_name in "${font_keys[@]}"; do
                            install_nerd_font "$font_name" || true
                        done
                        echo ""
                        echo -e "${GREEN}✓${NC} All fonts installation complete!"
                    fi
                    echo ""
                    read -p "Press Enter to continue..."
                    hide_cursor

                elif [[ $current_option -eq $option_uninstall ]]; then
                    # Uninstall menu
                    show_cursor
                    uninstall_menu
                    hide_cursor

                elif [[ $current_option -eq $option_quit ]]; then
                    show_cursor
                    echo ""
                    echo -e "${GREEN}✓${NC} Font manager closed"
                    exit 0
                fi
                ;;
            "QUIT")
                show_cursor
                echo ""
                echo -e "${GREEN}✓${NC} Font manager closed"
                exit 0
                ;;
        esac
    done
}

# Uninstall menu
uninstall_menu() {
    echo ""
    echo -e "${CYAN}Installed Nerd Fonts:${NC}"
    echo ""

    local -a installed=()
    while IFS= read -r font_name; do
        installed+=("$font_name")
    done < <(get_installed_fonts)

    if [[ ${#installed[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No Nerd Fonts installed${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    local idx=1
    for font_name in "${installed[@]}"; do
        echo -e "  $idx. $font_name"
        ((idx++))
    done

    echo ""
    echo -e "  $idx. Uninstall All"
    local option_all=$idx

    echo ""
    echo -e "  0. Cancel"
    echo ""

    read -p "Select font to uninstall (0-$idx): " selection

    if [[ "$selection" == "0" ]]; then
        return
    elif [[ "$selection" == "$option_all" ]]; then
        echo ""
        read -p "Remove all Nerd Fonts? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for font_name in "${installed[@]}"; do
                uninstall_nerd_font "$font_name"
            done
            echo ""
            echo -e "${GREEN}✓${NC} All fonts removed"
        fi
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -lt $option_all ]]; then
        local font_name="${installed[$((selection - 1))]}"
        echo ""
        uninstall_nerd_font "$font_name"
    else
        echo -e "${RED}Invalid selection${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Show help
show_help() {
    show_banner
    cat << EOF
${CYAN}About Nerd Fonts:${NC}
  Nerd Fonts patches developer targeted fonts with a high number of glyphs
  (icons). Specifically to add icons from popular 'iconic fonts' such as
  Font Awesome, Devicons, Octicons, and others.

${CYAN}Features:${NC}
  • Over 3,000 glyphs/icons including popular collections
  • Powerline symbols for enhanced terminal prompts
  • Font Awesome, Material Design Icons, Weather, and more
  • Perfect for terminal emulators and code editors

${CYAN}Usage:${NC}
  fub nerd-fonts              Interactive font installer
  fub nerd-fonts --help       Show this help

${CYAN}After Installation:${NC}
  1. Restart your terminal or reload font cache
  2. Select the installed Nerd Font in your terminal settings
  3. Enjoy icons and glyphs in your terminal!

${CYAN}Popular Fonts:${NC}
  • JetBrains Mono - Modern, clean font with excellent readability
  • Fira Code - Popular font with programming ligatures
  • Cascadia Code - Microsoft's modern coding font

${CYAN}More Info:${NC}
  https://www.nerdfonts.com
  https://github.com/ryanoasis/nerd-fonts

EOF
}

# Main function
main() {
    case "${1:-""}" in
        "--help" | "-h" | "help")
            show_help
            exit 0
            ;;
        *)
            # Check dependencies
            if ! command -v unzip &>/dev/null; then
                echo -e "${RED}Error:${NC} unzip is required but not installed"
                echo "Install it with: sudo apt install unzip"
                exit 1
            fi

            if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
                echo -e "${RED}Error:${NC} wget or curl is required"
                echo "Install wget with: sudo apt install wget"
                exit 1
            fi

            # Launch interactive menu
            interactive_font_menu
            ;;
    esac
}

main "$@"
