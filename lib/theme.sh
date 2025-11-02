#!/usr/bin/env bash

# FUB Theme System
# Provides theming support with Tokyo Night as default theme

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
fi

# Theme constants
[[ -z "${FUB_THEME_DIR:-}" ]] && readonly FUB_THEME_DIR="${FUB_CONFIG_DIR}/themes"
[[ -z "${FUB_DEFAULT_THEME:-}" ]] && readonly FUB_DEFAULT_THEME="tokyo-night"

# Current theme tracking
FUB_CURRENT_THEME=""
FUB_THEME_LOADED=false

# Theme color variables (simplified for bash 3.x)
if [[ -z "${THEME_BACKGROUND:-}" ]]; then
    THEME_BACKGROUND="#1a1b26"
    THEME_FOREGROUND="#c0caf5"
    THEME_CURSOR="#c0caf5"

    # Semantic colors
    THEME_SUCCESS="#9ece6a"
    THEME_WARNING="#e0af68"
    THEME_ERROR="#f7768e"
    THEME_INFO="#7aa2f7"
    THEME_DEBUG="#7dcfff"
    THEME_HIGHLIGHT="#bb9af7"
    THEME_MUTED="#565f89"

    # UI colors
    THEME_SELECTION_BACKGROUND="#33467c"
    THEME_BORDER_COLOR="#565f89"
fi

# Initialize theme system
init_theme() {
    local theme_name="${1:-$FUB_DEFAULT_THEME}"

    log_debug "Initializing theme: $theme_name"

    # Load theme
    if load_theme "$theme_name"; then
        FUB_CURRENT_THEME="$theme_name"
        FUB_THEME_LOADED=true
        log_info "Theme loaded: $theme_name"

        # Apply theme to terminal
        apply_theme_colors
    else
        log_error "Failed to load theme: $theme_name"
        log_info "Falling back to default theme: $FUB_DEFAULT_THEME"

        if load_theme "$FUB_DEFAULT_THEME"; then
            FUB_CURRENT_THEME="$FUB_DEFAULT_THEME"
            FUB_THEME_LOADED=true
            apply_theme_colors
        else
            log_error "Failed to load default theme. Using fallback colors."
            load_fallback_colors
        fi
    fi
}

# Load theme from file
load_theme() {
    local theme_name="$1"
    local theme_file="${FUB_THEME_DIR}/${theme_name}.yaml"

    log_debug "Loading theme from: $theme_file"

    # Ensure theme directory exists
    ensure_dir "$FUB_THEME_DIR"

    # Check if theme file exists
    if [[ ! -f "$theme_file" ]]; then
        log_debug "Theme file not found: $theme_file"

        # If it's the default theme, create it
        if [[ "$theme_name" == "$FUB_DEFAULT_THEME" ]]; then
            create_default_theme_file
        else
            return 1
        fi
    fi

    # Load built-in themes
    case "$theme_name" in
        "tokyo-night")
            load_tokyo_night_theme
            ;;
        "tokyo-night-storm")
            load_tokyo_night_storm_theme
            ;;
        "minimal")
            load_minimal_theme
            ;;
        *)
            # Try to load from file
            load_theme_from_file "$theme_file"
            ;;
    esac
}

# Load Tokyo Night theme
load_tokyo_night_theme() {
    log_debug "Loading Tokyo Night theme"

    # Set theme colors
    THEME_BACKGROUND="#1a1b26"
    THEME_FOREGROUND="#c0caf5"
    THEME_SUCCESS="#9ece6a"
    THEME_WARNING="#e0af68"
    THEME_ERROR="#f7768e"
    THEME_INFO="#7aa2f7"
    THEME_DEBUG="#7dcfff"
    THEME_HIGHLIGHT="#bb9af7"
    THEME_MUTED="#565f89"

    return 0
}

# Load Tokyo Night Storm theme variant
load_tokyo_night_storm_theme() {
    log_debug "Loading Tokyo Night Storm theme"

    # Set storm variant colors
    THEME_BACKGROUND="#24283b"
    THEME_FOREGROUND="#c0caf5"
    THEME_SUCCESS="#9ece6a"
    THEME_WARNING="#e0af68"
    THEME_ERROR="#f7768e"
    THEME_INFO="#7aa2f7"
    THEME_DEBUG="#7dcfff"
    THEME_HIGHLIGHT="#bb9af7"
    THEME_MUTED="#565f89"
}

# Load minimal theme (no colors)
load_minimal_theme() {
    log_debug "Loading minimal theme"

    # Reset to default terminal colors
    THEME_BACKGROUND=""
    THEME_FOREGROUND=""
    THEME_SUCCESS=""
    THEME_WARNING=""
    THEME_ERROR=""
    THEME_INFO=""
    THEME_DEBUG=""
    THEME_HIGHLIGHT=""
    THEME_MUTED=""
}

# Load theme from YAML file
load_theme_from_file() {
    local theme_file="$1"

    log_debug "Loading theme from file: $theme_file"

    # Simple theme loading - just set basic colors
    load_tokyo_night_theme
    log_debug "Theme loaded from file (simplified)"

    return 0
}

# Create default theme file
create_default_theme_file() {
    local theme_file="${FUB_THEME_DIR}/${FUB_DEFAULT_THEME}.yaml"

    log_info "Creating default theme file: $theme_file"

    > "$theme_file" cat << 'EOF'
# FUB Tokyo Night Theme
# Based on the popular Tokyo Night color scheme

# Base colors
background: "#1a1b26"
foreground: "#c0caf5"

# Semantic colors
success: "#9ece6a"
warning: "#e0af68"
error: "#f7768e"
info: "#7aa2f7"
debug: "#7dcfff"
highlight: "#bb9af7"
muted: "#565f89"
EOF

    log_info "Default theme file created"
}

# Load fallback colors (minimal set)
load_fallback_colors() {
    log_debug "Loading fallback colors"

    # Basic ANSI color codes as fallback
    THEME_BACKGROUND=""
    THEME_FOREGROUND=""
    THEME_SUCCESS="32"  # Green
    THEME_WARNING="33"  # Yellow
    THEME_ERROR="31"    # Red
    THEME_INFO="34"     # Blue
    THEME_DEBUG="36"    # Cyan
    THEME_HIGHLIGHT="35" # Magenta
    THEME_MUTED="37"    # White
}

# Apply theme colors to terminal variables
apply_theme_colors() {
    # Convert hex colors to ANSI escape sequences
    local bg="${THEME_BACKGROUND}"
    local fg="${THEME_FOREGROUND}"

    # Define color variables for use throughout the application
    if [[ -n "$bg" ]]; then
        export RESET="\033[0m"
        export BOLD="\033[1m"
        export DIM="\033[2m"
        export ITALIC="\033[3m"
        export UNDERLINE="\033[4m"

        # Semantic colors
        export RED="\033[38;2;247;118;142m"     # #f7768e
        export GREEN="\033[38;2;158;206;106m"    # #9ece6a
        export YELLOW="\033[38;2;224;175;104m"   # #e0af68
        export BLUE="\033[38;2;122;162;247m"     # #7aa2f7
        export MAGENTA="\033[38;2;187;154;247m"  # #bb9af7
        export CYAN="\033[38;2;125;207;255m"     # #7dcfff
        export WHITE="\033[38;2;169;177;214m"    # #a9b1d6

        # Additional colors
        export GRAY="\033[38;2;86;95;137m"       # #565f89
        export HIGHLIGHT="\033[38;2;187;154;247m" # #bb9af7
        export SUCCESS="\033[38;2;158;206;106m"   # #9ece6a
        export WARNING="\033[38;2;224;175;104m"   # #e0af68
        export ERROR="\033[38;2;247;118;142m"     # #f7768e
        export INFO="\033[38;2;122;162;247m"      # #7aa2f7
        export DEBUG="\033[38;2;125;207;255m"     # #7dcfff
        export MUTED="\033[38;2;86;95;137m"       # #565f89

        # Background colors
        export BG_BLACK="\033[48;2;21;22;30m"     # #15161e
        export BG_BLUE="\033[48;2;122;162;247m"   # #7aa2f7
        export BG_HIGHLIGHT="\033[48;2;51;70;124m" # #33467c
    else
        # Fallback to basic ANSI colors
        export RESET="\033[0m"
        export BOLD="\033[1m"
        export DIM="\033[2m"
        export ITALIC="\033[3m"
        export UNDERLINE="\033[4m"

        export RED="\033[31m"
        export GREEN="\033[32m"
        export YELLOW="\033[33m"
        export BLUE="\033[34m"
        export MAGENTA="\033[35m"
        export CYAN="\033[36m"
        export WHITE="\033[37m"

        export GRAY="\033[90m"
        export HIGHLIGHT="\033[95m"
        export SUCCESS="\033[32m"
        export WARNING="\033[33m"
        export ERROR="\033[31m"
        export INFO="\033[34m"
        export DEBUG="\033[36m"
        export MUTED="\033[90m"

        export BG_BLACK="\033[40m"
        export BG_BLUE="\033[44m"
        export BG_HIGHLIGHT="\033[46m"
    fi
}

# Get theme color
get_theme_color() {
    local color_name="$1"
    local default="${2:-}"

    local color_variable="THEME_${color_name^^}"
    local color="${!color_variable:-$default}"
    echo "$color"
}

# Set theme color
set_theme_color() {
    local color_name="$1"
    local color_value="$2"

    local color_variable="THEME_${color_name^^}"
    printf -v "$color_variable" '%s' "$color_value"
    log_debug "Theme color set: $color_name = $color_value"
}

# Print colored text
print_color() {
    local color="$1"
    shift
    local text="$*"

    case "$color" in
        red) echo -e "${RED}${text}${RESET}" ;;
        green) echo -e "${GREEN}${text}${RESET}" ;;
        yellow) echo -e "${YELLOW}${text}${RESET}" ;;
        blue) echo -e "${BLUE}${text}${RESET}" ;;
        magenta) echo -e "${MAGENTA}${text}${RESET}" ;;
        cyan) echo -e "${CYAN}${text}${RESET}" ;;
        white) echo -e "${WHITE}${text}${RESET}" ;;
        gray) echo -e "${GRAY}${text}${RESET}" ;;
        highlight) echo -e "${HIGHLIGHT}${text}${RESET}" ;;
        success) echo -e "${SUCCESS}${text}${RESET}" ;;
        warning) echo -e "${WARNING}${text}${RESET}" ;;
        error) echo -e "${ERROR}${text}${RESET}" ;;
        info) echo -e "${INFO}${text}${RESET}" ;;
        debug) echo -e "${DEBUG}${text}${RESET}" ;;
        muted) echo -e "${MUTED}${text}${RESET}" ;;
        *) echo -e "${text}" ;;
    esac
}

# Print with background color
print_bg_color() {
    local bg_color="$1"
    local fg_color="$2"
    shift 2
    local text="$*"

    case "$bg_color" in
        black) bg="$BG_BLACK" ;;
        blue) bg="$BG_BLUE" ;;
        highlight) bg="$BG_HIGHLIGHT" ;;
        *) bg="" ;;
    esac

    case "$fg_color" in
        white|*) fg="$WHITE" ;;
    esac

    echo -e "${bg}${fg}${text}${RESET}"
}

# Print gradient text (simple simulation)
print_gradient() {
    local text="$1"
    local start_color="${2:-$THEME_INFO}"
    local end_color="${3:-$THEME_SUCCESS}"

    # For now, just use highlight color for the entire text
    # In a real implementation, you'd interpolate between colors
    echo -e "${HIGHLIGHT}${text}${RESET}"
}

# Show theme information
show_theme_info() {
    local theme_name="${1:-$FUB_CURRENT_THEME}"

    echo ""
    echo "${BOLD}${CYAN}Theme Information${RESET}"
    echo "================="
    echo ""
    echo "${YELLOW}Current Theme:${RESET} $theme_name"
    echo "${YELLOW}Theme File:${RESET} ${FUB_THEME_DIR}/${theme_name}.yaml"
    echo "${YELLOW}Loaded:${RESET} $([[ $FUB_THEME_LOADED == true ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}")"
    echo ""

    # Show color palette
    echo "${BOLD}Color Palette:${RESET}"
    echo ""

    printf "  ${WHITE}White${RESET}     ${GRAY}Gray${RESET}       ${RED}Red${RESET}         ${GREEN}Green${RESET}\n"
    printf "  ${YELLOW}Yellow${RESET}   ${BLUE}Blue${RESET}       ${MAGENTA}Magenta${RESET}   ${CYAN}Cyan${RESET}\n"
    printf "  ${SUCCESS}Success${RESET}  ${WARNING}Warning${RESET}  ${ERROR}Error${RESET}     ${INFO}Info${RESET}\n"
    printf "  ${DEBUG}Debug${RESET}     ${HIGHLIGHT}Highlight${RESET}  ${MUTED}Muted${RESET}\n"

    echo ""
}

# List available themes
list_themes() {
    echo ""
    echo "${BOLD}${CYAN}Available Themes${RESET}"
    echo "=================="
    echo ""

    # Built-in themes
    echo "${YELLOW}Built-in Themes:${RESET}"
    echo "  ${GREEN}tokyo-night${RESET}       - Default Tokyo Night theme"
    echo "  ${GREEN}tokyo-night-storm${RESET} - Tokyo Night storm variant"
    echo "  ${GREEN}minimal${RESET}           - Minimal (no colors) theme"
    echo ""

    # Custom themes
    if [[ -d "$FUB_THEME_DIR" ]]; then
        local custom_themes=()
        for theme_file in "${FUB_THEME_DIR}"/*.yaml; do
            if [[ -f "$theme_file" ]]; then
                local theme_name=$(basename "$theme_file" .yaml)
                custom_themes+=("$theme_name")
            fi
        done

        if [[ ${#custom_themes[@]} -gt 0 ]]; then
            echo "${YELLOW}Custom Themes:${RESET}"
            for theme in "${custom_themes[@]}"; do
                local is_current=""
                [[ "$theme" == "$FUB_CURRENT_THEME" ]] && is_current="${GREEN}[current]${RESET}"
                echo "  ${GREEN}${theme}${RESET} $is_current"
            done
            echo ""
        fi
    fi

    echo "${YELLOW}Current Theme:${RESET} ${GREEN}${FUB_CURRENT_THEME}${RESET}"
    echo ""
}

# Check if colors are supported
supports_colors() {
    # Check if terminal supports colors
    [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" == "" ]]
}

# Reset colors to default
reset_colors() {
    echo -e "${RESET}"
}

# Export functions for use in other modules
export -f init_theme load_theme apply_theme_colors get_theme_color set_theme_color
export -f print_color print_bg_color print_gradient show_theme_info list_themes
export -f supports_colors reset_colors

# Initialize theme system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_theme "${1:-$FUB_DEFAULT_THEME}"
    show_theme_info
fi