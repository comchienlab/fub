#!/usr/bin/env bash

# FUB Theme Manager Module
# Handles theme customization, color schemes, and visual settings

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_ROOT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
    source "${FUB_ROOT_DIR}/lib/user-config.sh"
fi

# Theme constants
readonly FUB_THEMES_DIR="${FUB_CONFIG_DIR}/themes"
readonly FUB_USER_THEMES_DIR="${FUB_USER_CONFIG_DIR}/themes"
readonly FUB_THEME_CACHE_DIR="${FUB_CACHE_DIR}/themes"

# Theme state variables
FUB_CURRENT_THEME=""
FUB_THEME_COLORS=()
FUB_THEME_LOADED=false

# Initialize theme manager
init_theme_manager() {
    log_debug "Initializing theme manager..."

    # Ensure theme directories exist
    ensure_dir "$FUB_THEMES_DIR"
    ensure_dir "$FUB_USER_THEMES_DIR"
    ensure_dir "$FUB_THEME_CACHE_DIR"

    # Load current theme
    load_current_theme

    log_debug "Theme manager initialized"
}

# Load current theme
load_current_theme() {
    local theme_name=$(get_user_config "theme.name" "tokyo-night")
    FUB_CURRENT_THEME="$theme_name"

    log_debug "Loading theme: $FUB_CURRENT_THEME"

    # Load theme colors
    load_theme_colors "$FUB_CURRENT_THEME"

    FUB_THEME_LOADED=true
    log_debug "Theme loaded: $FUB_CURRENT_THEME"
}

# Load theme colors from theme file
load_theme_colors() {
    local theme_name="$1"
    local theme_file=""

    # Try user theme first, then system theme
    if [[ -f "${FUB_USER_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"
    elif [[ -f "${FUB_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_THEMES_DIR}/${theme_name}.yaml"
    else
        log_error "Theme file not found: $theme_name"
        return 1
    fi

    log_debug "Loading theme from: $theme_file"

    # Parse theme colors
    parse_theme_colors "$theme_file"
}

# Parse theme colors from YAML file
parse_theme_colors() {
    local theme_file="$1"

    # Clear existing colors
    FUB_THEME_COLORS=()

    # Parse basic colors
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Parse color definitions
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Store color
            FUB_THEME_COLORS["${key}"]="$value"
        fi
    done < "$theme_file"
}

# Get theme color
get_theme_color() {
    local color_key="$1"
    local default_value="${2:-}"

    if [[ -n "${FUB_THEME_COLORS[${color_key}]:-}" ]]; then
        echo "${FUB_THEME_COLORS[${color_key}]}"
    else
        echo "$default_value"
    fi
}

# Set theme color (for runtime customization)
set_theme_color() {
    local color_key="$1"
    local color_value="$2"

    FUB_THEME_COLORS["${color_key}"]="$color_value"
    log_debug "Theme color updated: $color_key = $color_value"
}

# List available themes
list_themes() {
    echo ""
    echo "${BOLD}${CYAN}Available Themes${RESET}"
    echo "================="
    echo ""

    # System themes
    echo "${YELLOW}System Themes:${RESET}"
    for theme_file in "${FUB_THEMES_DIR}"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name=$(basename "$theme_file" .yaml)
            local theme_info=$(get_theme_info "$theme_file")
            local marker=""
            [[ "$FUB_CURRENT_THEME" == "$theme_name" ]] && marker=" ${GREEN}[ACTIVE]${RESET}"
            echo "  ${GREEN}•${RESET} ${CYAN}${theme_name}${RESET}${marker}"
            echo "    ${theme_info}"
        fi
    done

    echo ""
    echo "${YELLOW}User Themes:${RESET}"
    local user_themes=0
    for theme_file in "${FUB_USER_THEMES_DIR}"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name=$(basename "$theme_file" .yaml)
            local theme_info=$(get_theme_info "$theme_file")
            local marker=""
            [[ "$FUB_CURRENT_THEME" == "$theme_name" ]] && marker=" ${GREEN}[ACTIVE]${RESET}"
            echo "  ${GREEN}•${RESET} ${CYAN}${theme_name}${RESET}${marker}"
            echo "    ${theme_info}"
            ((user_themes++))
        fi
    done

    if [[ $user_themes -eq 0 ]]; then
        echo "  ${GRAY}No user themes found${RESET}"
    fi

    echo ""
}

# Get theme information from theme file
get_theme_info() {
    local theme_file="$1"
    local name=""
    local description=""
    local version=""
    local author=""

    if [[ -f "$theme_file" ]]; then
        name=$(grep "^name:" "$theme_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
        description=$(grep "^description:" "$theme_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
        version=$(grep "^version:" "$theme_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
        author=$(grep "^author:" "$theme_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
    fi

    local info="${description:-No description available}"
    [[ -n "$version" ]] && info="$info (v$version)"
    [[ -n "$author" ]] && info="$info by $author"

    echo "$info"
}

# Set current theme
set_theme() {
    local theme_name="$1"

    if [[ -z "$theme_name" ]]; then
        log_error "Theme name is required"
        return 1
    fi

    # Check if theme exists
    if [[ ! -f "${FUB_THEMES_DIR}/${theme_name}.yaml" ]] &&
       [[ ! -f "${FUB_USER_THEMES_DIR}/${theme_name}.yaml" ]]; then
        log_error "Theme not found: $theme_name"
        return 1
    fi

    log_info "Switching to theme: $theme_name"

    # Update user configuration
    update_user_config_key "theme.name" "$theme_name"

    # Load theme
    load_theme_colors "$theme_name"
    FUB_CURRENT_THEME="$theme_name"

    log_info "Theme switched to: $theme_name"
}

# Create custom theme
create_theme() {
    local theme_name="$1"
    local theme_description="$2"
    local base_theme="${3:-tokyo-night}"

    if [[ -z "$theme_name" ]]; then
        log_error "Theme name is required"
        return 1
    fi

    local theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"

    if [[ -f "$theme_file" ]]; then
        log_error "Theme already exists: $theme_name"
        return 1
    fi

    log_info "Creating theme: $theme_name"

    # Get base theme template
    local base_file="${FUB_THEMES_DIR}/${base_theme}.yaml"
    if [[ ! -f "$base_file" ]]; then
        log_error "Base theme not found: $base_theme"
        return 1
    fi

    # Create new theme based on template
    cp "$base_file" "$theme_file"

    # Update theme metadata
    sed -i "s/^name:.*/name: \"$theme_name\"/" "$theme_file"
    sed -i "s/^description:.*/description: \"$theme_description\"/" "$theme_file"
    sed -i "s/^version:.*/version: \"1.0.0\"/" "$theme_file"
    sed -i "s/^author:.*/author: \"$(whoami)\"/" "$theme_file"

    log_info "Theme created: $theme_file"
}

# Delete custom theme
delete_theme() {
    local theme_name="$1"
    local theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"

    if [[ ! -f "$theme_file" ]]; then
        log_error "User theme not found: $theme_name"
        return 1
    fi

    if [[ "$FUB_CURRENT_THEME" == "$theme_name" ]]; then
        log_error "Cannot delete currently active theme: $theme_name"
        return 1
    fi

    log_info "Deleting theme: $theme_name"
    rm -f "$theme_file"
    log_info "Theme deleted: $theme_name"
}

# Customize theme colors
customize_theme() {
    local theme_name="$1"
    local color_key="$2"
    local color_value="$3"

    local theme_file=""

    # Find theme file (user themes only for customization)
    if [[ -f "${FUB_USER_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"
    else
        log_error "Cannot customize system theme. Create a user theme first."
        return 1
    fi

    # Update theme file
    if grep -q "^${color_key}:" "$theme_file"; then
        sed -i "s|^${color_key}:.*|${color_key}: \"${color_value}\"|" "$theme_file"
    else
        echo "${color_key}: \"${color_value}\"" >> "$theme_file"
    fi

    log_info "Theme color updated: $theme_name.$color_key = $color_value"

    # Reload theme if it's the current theme
    if [[ "$FUB_CURRENT_THEME" == "$theme_name" ]]; then
        load_theme_colors "$theme_name"
    fi
}

# Generate theme preview
generate_theme_preview() {
    local theme_name="$1"
    local output_file="${2:-}"

    local theme_file=""

    # Find theme file
    if [[ -f "${FUB_USER_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"
    elif [[ -f "${FUB_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_THEMES_DIR}/${theme_name}.yaml"
    else
        log_error "Theme not found: $theme_name"
        return 1
    fi

    # Load theme colors temporarily
    local -A temp_colors
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            temp_colors["${key}"]="$value"
        fi
    done < "$theme_file"

    # Generate preview
    local preview_content=""
    preview_content+="# Theme Preview: $theme_name\n"
    preview_content+="# Generated on $(date)\n\n"
    preview_content+="## Color Palette\n\n"

    # Basic colors
    local basic_colors=("background" "foreground" "color0" "color1" "color2" "color3" "color4" "color5" "color6" "color7")
    for color in "${basic_colors[@]}"; do
        local color_value="${temp_colors[$color]:-#000000}"
        preview_content+="### $color\n"
        preview_content+="![Color](https://via.placeholder.com/100x100/${color_value#}/000000?text=)\n"
        preview_content+="Hex: \`$color_value\`\n\n"
    done

    # Semantic colors
    preview_content+="## Semantic Colors\n\n"
    local semantic_colors=("success" "warning" "error" "info" "highlight")
    for color in "${semantic_colors[@]}"; do
        local color_value="${temp_colors[$color]:-#000000}"
        preview_content+="### $color\n"
        preview_content+="![Color](https://via.placeholder.com/100x100/${color_value#}/000000?text=)\n"
        preview_content+="Hex: \`$color_value\`\n\n"
    done

    if [[ -n "$output_file" ]]; then
        echo -e "$preview_content" > "$output_file"
        log_info "Theme preview generated: $output_file"
    else
        echo -e "$preview_content"
    fi
}

# Export theme
export_theme() {
    local theme_name="$1"
    local output_file="$2"

    local theme_file=""

    # Find theme file
    if [[ -f "${FUB_USER_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"
    elif [[ -f "${FUB_THEMES_DIR}/${theme_name}.yaml" ]]; then
        theme_file="${FUB_THEMES_DIR}/${theme_name}.yaml"
    else
        log_error "Theme not found: $theme_name"
        return 1
    fi

    log_info "Exporting theme: $theme_name to $output_file"

    ensure_dir "$(dirname "$output_file")"

    {
        echo "# FUB Theme Export: $theme_name"
        echo "# Generated on $(date)"
        echo ""
        cat "$theme_file"
    } > "$output_file"

    log_info "Theme exported to: $output_file"
}

# Import theme
import_theme() {
    local input_file="$1"
    local theme_name="$2"

    if [[ ! -f "$input_file" ]]; then
        log_error "Theme file not found: $input_file"
        return 1
    fi

    if [[ -z "$theme_name" ]]; then
        # Extract theme name from file
        theme_name=$(grep "^name:" "$input_file" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
        if [[ -z "$theme_name" ]]; then
            theme_name=$(basename "$input_file" .yaml)
        fi
    fi

    local theme_file="${FUB_USER_THEMES_DIR}/${theme_name}.yaml"

    if [[ -f "$theme_file" ]]; then
        log_error "Theme already exists: $theme_name"
        return 1
    fi

    log_info "Importing theme: $theme_name"

    ensure_dir "$FUB_USER_THEMES_DIR"
    cp "$input_file" "$theme_file"

    log_info "Theme imported: $theme_file"
}

# Validate theme file
validate_theme() {
    local theme_file="$1"

    if [[ ! -f "$theme_file" ]]; then
        log_error "Theme file not found: $theme_file"
        return 1
    fi

    log_debug "Validating theme: $theme_file"

    local validation_errors=0

    # Check for required keys
    local required_keys=("name" "description" "version")
    for key in "${required_keys[@]}"; do
        if ! grep -q "^${key}:" "$theme_file"; then
            log_error "Missing required key: $key"
            ((validation_errors++))
        fi
    done

    # Check color format (basic validation)
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Check if it's a color value (contains #)
            if [[ "$key" =~ color|background|foreground ]] && [[ ! "$value" =~ ^#[0-9a-fA-F]{6}$ ]]; then
                log_warn "Invalid color format for $key: $value"
            fi
        fi
    done < "$theme_file"

    if [[ $validation_errors -gt 0 ]]; then
        log_error "Theme validation failed with $validation_errors errors"
        return 1
    fi

    log_debug "Theme validation passed"
    return 0
}

# Show theme status
show_theme_status() {
    echo ""
    echo "${BOLD}${CYAN}Theme Status${RESET}"
    echo "============"
    echo ""
    echo "${YELLOW}Current Theme:${RESET}"
    echo "  ${GREEN}Name:${RESET} ${CYAN}${FUB_CURRENT_THEME}${RESET}"
    echo "  ${GREEN}Description:${RESET} ${CYAN}$(get_theme_info "${FUB_THEMES_DIR}/${FUB_CURRENT_THEME}.yaml")${RESET}"
    echo ""
    echo "${YELLOW}Theme Directories:${RESET}"
    echo "  ${GREEN}System Themes:${RESET} ${CYAN}${FUB_THEMES_DIR}${RESET}"
    echo "  ${GREEN}User Themes:${RESET} ${CYAN}${FUB_USER_THEMES_DIR}${RESET}"
    echo "  ${GREEN}Cache:${RESET} ${CYAN}${FUB_THEME_CACHE_DIR}${RESET}"
    echo ""

    # Count themes
    local system_themes=$(find "${FUB_THEMES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)
    local user_themes=$(find "${FUB_USER_THEMES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)

    echo "${YELLOW}Available Themes:${RESET}"
    echo "  ${GREEN}System:${RESET} ${CYAN}${system_themes}${RESET}"
    echo "  ${GREEN}User:${RESET} ${CYAN}${user_themes}${RESET}"
    echo ""

    # Show some current colors
    echo "${YELLOW}Current Colors:${RESET}"
    echo "  ${GREEN}Background:${RESET} ${CYAN}$(get_theme_color "background")${RESET}"
    echo "  ${GREEN}Foreground:${RESET} ${CYAN}$(get_theme_color "foreground")${RESET}"
    echo "  ${GREEN}Success:${RESET} ${CYAN}$(get_theme_color "success")${RESET}"
    echo "  ${GREEN}Warning:${RESET} ${CYAN}$(get_theme_color "warning")${RESET}"
    echo "  ${GREEN}Error:${RESET} ${CYAN}$(get_theme_color "error")${RESET}"
    echo "  ${GREEN}Info:${RESET} ${CYAN}$(get_theme_color "info")${RESET}"
    echo ""
}

# Apply theme to terminal (basic implementation)
apply_theme_to_terminal() {
    local theme_name="$1"

    # Get theme colors
    load_theme_colors "$theme_name"

    # Set terminal colors if supported
    local background=$(get_theme_color "background")
    local foreground=$(get_theme_color "foreground")
    local color0=$(get_theme_color "color0")
    local color1=$(get_theme_color "color1")
    local color2=$(get_theme_color "color2")
    local color3=$(get_theme_color "color3")
    local color4=$(get_theme_color "color4")
    local color5=$(get_theme_color "color5")
    local color6=$(get_theme_color "color6")
    local color7=$(get_theme_color "color7")

    # Apply colors (basic ANSI color setup)
    printf '\033]10;%s\007' "$foreground"  # Set foreground
    printf '\033]11;%s\007' "$background"  # Set background
    printf '\033]4;0;%s\007' "$color0"      # Set color 0
    printf '\033]4;1;%s\007' "$color1"      # Set color 1
    printf '\033]4;2;%s\007' "$color2"      # Set color 2
    printf '\033]4;3;%s\007' "$color3"      # Set color 3
    printf '\033]4;4;%s\007' "$color4"      # Set color 4
    printf '\033]4;5;%s\007' "$color5"      # Set color 5
    printf '\033]4;6;%s\007' "$color6"      # Set color 6
    printf '\033]4;7;%s\007' "$color7"      # Set color 7

    log_debug "Theme applied to terminal: $theme_name"
}

# Export functions for use in other modules
export -f init_theme_manager load_current_theme load_theme_colors
export -f get_theme_color set_theme_color list_themes get_theme_info
export -f set_theme create_theme delete_theme customize_theme
export -f generate_theme_preview export_theme import_theme validate_theme
export -f show_theme_status apply_theme_to_terminal

# Initialize theme manager if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_theme_manager
    show_theme_status
fi