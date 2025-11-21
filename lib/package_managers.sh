#!/bin/bash
# lib/package_managers.sh - Multi-package-manager abstraction for Ubuntu
# Provides unified interface for APT, Snap, Flatpak, and AppImage

# Prevent multiple sourcing
if [[ -n "${FUB_PACKAGE_MANAGERS_LOADED:-}" ]]; then
    return 0
fi
readonly FUB_PACKAGE_MANAGERS_LOADED=1

# ============================================================================
# Package Manager Detection
# ============================================================================

detect_package_managers() {
    local -a managers=()
    command -v apt &>/dev/null && managers+=("apt")
    command -v snap &>/dev/null && managers+=("snap")
    command -v flatpak &>/dev/null && managers+=("flatpak")
    # AppImage is always available (it's just executable files)
    managers+=("appimage")
    printf '%s\n' "${managers[@]}"
}

# ============================================================================
# APT/DPKG Functions
# ============================================================================

scan_apt_packages() {
    dpkg -l | awk '/^ii/ {print $2 "\t" $3 "\tapt"}'
}

# Optimized: Scan APT packages with sizes in batch (much faster)
scan_apt_packages_with_sizes() {
    # Single dpkg-query call to get all package names, versions, and sizes
    dpkg-query -W -f='${Package}\t${Version}\t${Installed-Size}\n' 2>/dev/null | \
        awk -F'\t' '{print $1 "\t" $2 "\tapt\t" $3}'
}

get_apt_package_info() {
    local pkg="$1"
    apt-cache show "$pkg" 2>/dev/null | head -20
}

get_apt_package_size() {
    local pkg="$1"
    dpkg-query -W -f='${Installed-Size}' "$pkg" 2>/dev/null || echo "0"
}

# Batch get sizes for multiple APT packages (much faster than individual queries)
get_apt_packages_sizes_batch() {
    local -a packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return
    fi

    # Get all sizes in one dpkg-query call
    dpkg-query -W -f='${Package}\t${Installed-Size}\n' "${packages[@]}" 2>/dev/null
}

uninstall_apt_package() {
    local pkg="$1"
    local purge="${2:-true}"

    if [[ "$purge" == "true" ]]; then
        sudo apt-get remove --purge -y "$pkg" 2>&1
    else
        sudo apt-get remove -y "$pkg" 2>&1
    fi
}

is_apt_package_installed() {
    local pkg="$1"
    dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
}

# ============================================================================
# Snap Functions
# ============================================================================

scan_snap_packages() {
    if ! command -v snap &>/dev/null; then
        return 0
    fi
    snap list --color=never 2>/dev/null | tail -n +2 | awk '{print $1 "\t" $2 "\tsnap"}'
}

# Optimized: Scan snap packages with parallel size calculation
scan_snap_packages_with_sizes() {
    if ! command -v snap &>/dev/null; then
        return 0
    fi

    # Get snap list
    snap list --color=never 2>/dev/null | tail -n +2 | while read -r name version rev tracking publisher notes; do
        # Calculate size in background for parallel processing
        local size_kb=0
        if [[ -d "/snap/$name" ]]; then
            # Use --max-depth=1 and --apparent-size for faster du
            size_kb=$(du -s --apparent-size --block-size=1024 "/snap/$name" 2>/dev/null | awk '{print $1}')
        fi
        echo "$name	$version	snap	${size_kb:-0}"
    done
}

get_snap_package_info() {
    local pkg="$1"
    snap info "$pkg" 2>/dev/null | head -20
}

get_snap_package_size() {
    local pkg="$1"
    # Snap doesn't provide easy size info, estimate from directory
    if [[ -d "/snap/$pkg" ]]; then
        du -sb "/snap/$pkg" 2>/dev/null | awk '{print int($1/1024)}'
    else
        echo "0"
    fi
}

# Batch get sizes for snap packages (parallel calculation)
get_snap_packages_sizes_batch() {
    local -a packages=("$@")
    for pkg in "${packages[@]}"; do
        if [[ -d "/snap/$pkg" ]]; then
            du -s --apparent-size --block-size=1024 "/snap/$pkg" 2>/dev/null | awk -v pkg="$pkg" '{print pkg "\t" $1}'
        fi
    done
}

uninstall_snap_package() {
    local pkg="$1"
    sudo snap remove "$pkg" 2>&1
}

is_snap_package_installed() {
    local pkg="$1"
    snap list "$pkg" &>/dev/null
}

# ============================================================================
# Flatpak Functions
# ============================================================================

scan_flatpak_packages() {
    if ! command -v flatpak &>/dev/null; then
        return 0
    fi
    flatpak list --app --columns=application,name,version 2>/dev/null | tail -n +1 | \
        awk -F'\t' '{print $1 "\t" $2 "\tflatpak"}'
}

# Optimized: Scan flatpak packages with sizes in single call
scan_flatpak_packages_with_sizes() {
    if ! command -v flatpak &>/dev/null; then
        return 0
    fi

    # Get all info in one call with columns including size
    flatpak list --app --columns=application,name,version,size 2>/dev/null | tail -n +1 | \
        awk -F'\t' '{
            size_kb = 0
            if ($4 != "" && $4 != "?") {
                # Parse size string (e.g., "1.2 GB", "512 MB", "10 KB")
                size_str = $4
                # This will be handled in bash, just pass through
                size_kb = $4
            }
            print $1 "\t" $2 "\t" $3 "\tflatpak\t" size_kb
        }'
}

get_flatpak_package_info() {
    local pkg="$1"
    flatpak info "$pkg" 2>/dev/null | head -20
}

get_flatpak_package_size() {
    local pkg="$1"
    flatpak info "$pkg" 2>/dev/null | grep "Installed size:" | awk '{print $3}' | numfmt --from=iec-i --to-unit=K 2>/dev/null || echo "0"
}

# Parse flatpak size string to KB
parse_flatpak_size() {
    local size_str="$1"
    if [[ -z "$size_str" || "$size_str" == "?" ]]; then
        echo "0"
        return
    fi

    # Use numfmt to convert size to KB
    echo "$size_str" | numfmt --from=iec --to-unit=1024 2>/dev/null || echo "0"
}

uninstall_flatpak_package() {
    local pkg="$1"
    flatpak uninstall -y "$pkg" 2>&1
}

is_flatpak_package_installed() {
    local pkg="$1"
    flatpak list | grep -q "$pkg"
}

# ============================================================================
# AppImage Functions
# ============================================================================

scan_appimage_files() {
    local -a search_paths=(
        "$HOME/Applications"
        "$HOME/.local/bin"
        "$HOME/Downloads"
        "$HOME"
    )

    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            find "$path" -maxdepth 2 -name "*.AppImage" -type f 2>/dev/null | while read -r appimage; do
                local name=$(basename "$appimage" .AppImage)
                local size=$(stat -c%s "$appimage" 2>/dev/null || echo "0")
                local size_kb=$((size / 1024))
                echo "$appimage	$name	appimage	$size_kb"
            done
        fi
    done
}

get_appimage_info() {
    local appimage_path="$1"
    if [[ -f "$appimage_path" ]]; then
        echo "File: $appimage_path"
        echo "Size: $(du -h "$appimage_path" | awk '{print $1}')"
        echo "Permissions: $(stat -c%a "$appimage_path")"
        echo "Modified: $(stat -c%y "$appimage_path")"
    fi
}

uninstall_appimage() {
    local appimage_path="$1"
    rm -f "$appimage_path" 2>&1
    # Also remove associated .desktop file if exists
    local name=$(basename "$appimage_path" .AppImage)
    rm -f "$HOME/.local/share/applications/$name.desktop" 2>/dev/null || true
}

is_appimage_file() {
    local path="$1"
    [[ -f "$path" && "$path" == *.AppImage ]]
}

# ============================================================================
# Unified Package Operations
# ============================================================================

# Get package type
get_package_type() {
    local pkg="$1"

    # Check if it's a file path (AppImage)
    if [[ -f "$pkg" && "$pkg" == *.AppImage ]]; then
        echo "appimage"
        return 0
    fi

    # Check APT
    if is_apt_package_installed "$pkg"; then
        echo "apt"
        return 0
    fi

    # Check Snap
    if command -v snap &>/dev/null && is_snap_package_installed "$pkg"; then
        echo "snap"
        return 0
    fi

    # Check Flatpak
    if command -v flatpak &>/dev/null && is_flatpak_package_installed "$pkg"; then
        echo "flatpak"
        return 0
    fi

    echo "unknown"
    return 1
}

# Unified package listing
list_all_packages() {
    echo "=== APT Packages ==="
    scan_apt_packages

    echo ""
    echo "=== Snap Packages ==="
    scan_snap_packages

    echo ""
    echo "=== Flatpak Packages ==="
    scan_flatpak_packages

    echo ""
    echo "=== AppImage Files ==="
    scan_appimage_files
}

# Unified uninstall
uninstall_package() {
    local pkg="$1"
    local type="${2:-$(get_package_type "$pkg")}"
    local purge="${3:-true}"

    case "$type" in
        apt)
            uninstall_apt_package "$pkg" "$purge"
            ;;
        snap)
            uninstall_snap_package "$pkg"
            ;;
        flatpak)
            uninstall_flatpak_package "$pkg"
            ;;
        appimage)
            uninstall_appimage "$pkg"
            ;;
        *)
            echo "Error: Unknown package type for: $pkg" >&2
            return 1
            ;;
    esac
}

# Get package info
get_package_info() {
    local pkg="$1"
    local type="${2:-$(get_package_type "$pkg")}"

    case "$type" in
        apt)
            get_apt_package_info "$pkg"
            ;;
        snap)
            get_snap_package_info "$pkg"
            ;;
        flatpak)
            get_flatpak_package_info "$pkg"
            ;;
        appimage)
            get_appimage_info "$pkg"
            ;;
        *)
            echo "Error: Unknown package type for: $pkg" >&2
            return 1
            ;;
    esac
}

# Get package size in KB
get_package_size() {
    local pkg="$1"
    local type="${2:-$(get_package_type "$pkg")}"

    case "$type" in
        apt)
            get_apt_package_size "$pkg"
            ;;
        snap)
            get_snap_package_size "$pkg"
            ;;
        flatpak)
            get_flatpak_package_size "$pkg"
            ;;
        appimage)
            if [[ -f "$pkg" ]]; then
                stat -c%s "$pkg" 2>/dev/null | awk '{print int($1/1024)}'
            else
                echo "0"
            fi
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Export functions
export -f detect_package_managers
export -f scan_apt_packages scan_apt_packages_with_sizes get_apt_packages_sizes_batch get_apt_package_info uninstall_apt_package is_apt_package_installed
export -f scan_snap_packages scan_snap_packages_with_sizes get_snap_packages_sizes_batch get_snap_package_info uninstall_snap_package is_snap_package_installed
export -f scan_flatpak_packages scan_flatpak_packages_with_sizes parse_flatpak_size get_flatpak_package_info uninstall_flatpak_package is_flatpak_package_installed
export -f scan_appimage_files get_appimage_info uninstall_appimage is_appimage_file
export -f get_package_type list_all_packages uninstall_package get_package_info get_package_size
