#!/bin/bash
# lib/desktop_parser.sh - Parse .desktop files for app metadata
# Implements freedesktop.org Desktop Entry Specification

# Prevent multiple sourcing
if [[ -n "${FUB_DESKTOP_PARSER_LOADED:-}" ]]; then
    return 0
fi
readonly FUB_DESKTOP_PARSER_LOADED=1

# ============================================================================
# Desktop File Discovery
# ============================================================================

find_desktop_files() {
    local search_paths=(
        "/usr/share/applications"
        "/usr/local/share/applications"
        "$HOME/.local/share/applications"
    )

    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            find "$path" -maxdepth 1 -name "*.desktop" -type f 2>/dev/null
        fi
    done
}

find_desktop_by_name() {
    local app_name="$1"
    local app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')

    find_desktop_files | while read -r desktop_file; do
        local name=$(get_desktop_app_name "$desktop_file")
        local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

        # Match by name or filename
        local filename=$(basename "$desktop_file" .desktop)
        local filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

        if [[ "$name_lower" == *"$app_name_lower"* ]] || [[ "$filename_lower" == *"$app_name_lower"* ]]; then
            echo "$desktop_file"
            return 0
        fi
    done
}

find_desktop_by_exec() {
    local exec_name="$1"
    find_desktop_files | while read -r desktop_file; do
        local exec_line=$(get_desktop_app_exec "$desktop_file")
        if [[ "$exec_line" == *"$exec_name"* ]]; then
            echo "$desktop_file"
            return 0
        fi
    done
}

# ============================================================================
# Desktop File Parsing
# ============================================================================

parse_desktop_file() {
    local desktop_file="$1"
    local key="$2"

    if [[ ! -f "$desktop_file" ]]; then
        return 1
    fi

    # Parse the [Desktop Entry] section
    # Handle localized keys like Name[en_US]=...
    grep "^${key}\(\[.*\]\)\?=" "$desktop_file" 2>/dev/null | head -1 | cut -d= -f2-
}

get_desktop_app_name() {
    local desktop_file="$1"
    local name=$(parse_desktop_file "$desktop_file" "Name")

    # If no name found, use filename
    if [[ -z "$name" ]]; then
        name=$(basename "$desktop_file" .desktop)
    fi

    echo "$name"
}

get_desktop_app_exec() {
    local desktop_file="$1"
    local exec_line=$(parse_desktop_file "$desktop_file" "Exec")

    # Remove field codes (%U, %F, %u, %f, %U, etc.)
    exec_line=$(echo "$exec_line" | sed 's/ %[A-Za-z]//g' | sed 's/ --[^ ]*//g')

    echo "$exec_line"
}

get_desktop_app_icon() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "Icon"
}

get_desktop_app_comment() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "Comment"
}

get_desktop_app_generic_name() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "GenericName"
}

get_desktop_app_categories() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "Categories"
}

get_desktop_app_type() {
    local desktop_file="$1"
    local type=$(parse_desktop_file "$desktop_file" "Type")
    echo "${type:-Application}"
}

is_desktop_app_hidden() {
    local desktop_file="$1"
    local hidden=$(parse_desktop_file "$desktop_file" "NoDisplay")
    [[ "$hidden" == "true" ]]
}

# ============================================================================
# Package Association
# ============================================================================

get_desktop_package() {
    local desktop_file="$1"

    # Try dpkg first (APT packages)
    if command -v dpkg &>/dev/null; then
        local pkg=$(dpkg -S "$desktop_file" 2>/dev/null | cut -d: -f1)
        if [[ -n "$pkg" ]]; then
            echo "$pkg	apt"
            return 0
        fi
    fi

    # Check if it's a Snap
    if [[ "$desktop_file" == */snap/* ]]; then
        local snap_name=$(echo "$desktop_file" | grep -oP 'snap/\K[^/]+' | head -1)
        if [[ -n "$snap_name" ]]; then
            echo "$snap_name	snap"
            return 0
        fi
    fi

    # Check if it's a Flatpak
    if [[ "$desktop_file" == */flatpak/* ]]; then
        # Flatpak desktop files are in: ~/.local/share/flatpak/exports/share/applications/
        # or /var/lib/flatpak/exports/share/applications/
        local flatpak_id=$(basename "$desktop_file" .desktop)
        if command -v flatpak &>/dev/null && flatpak list | grep -q "$flatpak_id"; then
            echo "$flatpak_id	flatpak"
            return 0
        fi
    fi

    # User-installed (might be manual or AppImage)
    if [[ "$desktop_file" == "$HOME"/* ]]; then
        local name=$(basename "$desktop_file" .desktop)
        echo "$name	user"
        return 0
    fi

    echo "unknown	unknown"
}

# ============================================================================
# Desktop File Listing
# ============================================================================

list_all_desktop_apps() {
    find_desktop_files | while read -r desktop_file; do
        # Skip hidden apps
        if is_desktop_app_hidden "$desktop_file"; then
            continue
        fi

        local name=$(get_desktop_app_name "$desktop_file")
        local exec=$(get_desktop_app_exec "$desktop_file")
        local icon=$(get_desktop_app_icon "$desktop_file")
        local comment=$(get_desktop_app_comment "$desktop_file")
        local package_info=$(get_desktop_package "$desktop_file")
        local package=$(echo "$package_info" | cut -f1)
        local pkg_type=$(echo "$package_info" | cut -f2)

        echo "$name	$package	$pkg_type	$exec	$icon	$comment	$desktop_file"
    done
}

list_desktop_apps_by_category() {
    local category="$1"
    find_desktop_files | while read -r desktop_file; do
        local categories=$(get_desktop_app_categories "$desktop_file")
        if [[ "$categories" == *"$category"* ]]; then
            get_desktop_app_name "$desktop_file"
        fi
    done
}

# ============================================================================
# Desktop File Creation/Modification
# ============================================================================

create_desktop_file() {
    local name="$1"
    local exec="$2"
    local icon="${3:-application-x-executable}"
    local comment="${4:-}"
    local categories="${5:-Utility}"

    local desktop_file="$HOME/.local/share/applications/${name}.desktop"

    mkdir -p "$HOME/.local/share/applications"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$exec
Icon=$icon
Categories=$categories
Terminal=false
EOF

    chmod +x "$desktop_file"
    echo "$desktop_file"
}

remove_desktop_file() {
    local name="$1"
    local desktop_file="$HOME/.local/share/applications/${name}.desktop"

    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
        # Update desktop database
        if command -v update-desktop-database &>/dev/null; then
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        fi
        return 0
    fi
    return 1
}

# ============================================================================
# Helper Functions
# ============================================================================

desktop_file_exists() {
    local name="$1"
    local desktop_file=$(find_desktop_by_name "$name")
    [[ -n "$desktop_file" && -f "$desktop_file" ]]
}

get_executable_from_desktop() {
    local name="$1"
    local desktop_file=$(find_desktop_by_name "$name")
    if [[ -n "$desktop_file" ]]; then
        get_desktop_app_exec "$desktop_file" | awk '{print $1}'
    fi
}

# Export functions
export -f find_desktop_files find_desktop_by_name find_desktop_by_exec
export -f parse_desktop_file get_desktop_app_name get_desktop_app_exec get_desktop_app_icon
export -f get_desktop_app_comment get_desktop_app_generic_name get_desktop_app_categories
export -f get_desktop_app_type is_desktop_app_hidden get_desktop_package
export -f list_all_desktop_apps list_desktop_apps_by_category
export -f create_desktop_file remove_desktop_file desktop_file_exists get_executable_from_desktop
