#!/bin/bash
# Fub - Uninstall Module (Ubuntu Edition)
# Interactive application uninstaller for Ubuntu with multi-package-manager support
#
# Usage:
#   uninstall.sh          # Launch interactive uninstaller
#   uninstall.sh --help   # Show help information

set -euo pipefail

# Fix locale issues
export LC_ALL=C
export LANG=C

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/paths_ubuntu.sh"
source "$SCRIPT_DIR/../lib/package_managers.sh"
source "$SCRIPT_DIR/../lib/desktop_parser.sh"

# System-critical packages that should NEVER be uninstalled
readonly SYSTEM_CRITICAL_PACKAGES=(
    "ubuntu-desktop"
    "gnome-shell"
    "systemd"
    "linux-generic"
    "linux-image-generic"
    "network-manager"
    "gdm3"
    "firefox"
    "nautilus"
    "gnome-terminal"
    "bash"
    "sudo"
    "apt"
    "dpkg"
    "init"
)

# Data-protected packages (warn before uninstall)
readonly DATA_PROTECTED_PACKAGES=(
    "code"
    "sublime-text"
    "vim"
    "emacs"
    "keepassxc"
    "bitwarden"
    "1password"
    "brave-browser"
    "google-chrome-stable"
    "thunderbird"
)

# Check if package is system-critical
is_system_critical() {
    local pkg_name="$1"
    for critical in "${SYSTEM_CRITICAL_PACKAGES[@]}"; do
        if [[ "$pkg_name" == "$critical" ]] || [[ "$pkg_name" == *"$critical"* ]]; then
            return 0
        fi
    done
    return 1
}

# Check if package data should be protected
is_data_protected() {
    local pkg_name="$1"
    for protected in "${DATA_PROTECTED_PACKAGES[@]}"; do
        if [[ "$pkg_name" == "$protected" ]] || [[ "$pkg_name" == *"$protected"* ]]; then
            return 0
        fi
    done
    return 1
}

# Scan all installed applications
scan_all_applications() {
    local output_file="$1"
    > "$output_file"

    echo -e "${BLUE}Scanning installed applications...${NC}"

    # Scan APT packages
    echo -e "  ${BLUE}→${NC} APT packages..."
    while IFS=$'\t' read -r pkg_name version pkg_type; do
        if is_system_critical "$pkg_name"; then
            continue
        fi

        local size_kb=$(get_apt_package_size "$pkg_name")
        local size_human=$(numfmt --to=iec --suffix=B --padding=7 $((size_kb * 1024)) 2>/dev/null || echo "Unknown")

        echo "apt|$pkg_name|$version|$size_kb|$size_human" >> "$output_file"
    done < <(scan_apt_packages)

    # Scan Snap packages
    if command -v snap &>/dev/null; then
        echo -e "  ${BLUE}→${NC} Snap packages..."
        while IFS=$'\t' read -r pkg_name version pkg_type; do
            local size_kb=$(get_snap_package_size "$pkg_name")
            local size_human=$(numfmt --to=iec --suffix=B --padding=7 $((size_kb * 1024)) 2>/dev/null || echo "Unknown")

            echo "snap|$pkg_name|$version|$size_kb|$size_human" >> "$output_file"
        done < <(scan_snap_packages)
    fi

    # Scan Flatpak packages
    if command -v flatpak &>/dev/null; then
        echo -e "  ${BLUE}→${NC} Flatpak packages..."
        while IFS=$'\t' read -r pkg_id pkg_name pkg_type; do
            local size_kb=$(get_flatpak_package_size "$pkg_id")
            local size_human=$(numfmt --to=iec --suffix=B --padding=7 $((size_kb * 1024)) 2>/dev/null || echo "Unknown")
            local version=$(flatpak info "$pkg_id" 2>/dev/null | grep "Version:" | awk '{print $2}' || echo "unknown")

            echo "flatpak|$pkg_id|$version|$size_kb|$size_human|$pkg_name" >> "$output_file"
        done < <(scan_flatpak_packages)
    fi

    # Scan AppImages
    echo -e "  ${BLUE}→${NC} AppImage files..."
    while IFS=$'\t' read -r appimage_path pkg_name pkg_type size_kb; do
        local size_human=$(numfmt --to=iec --suffix=B --padding=7 $((size_kb * 1024)) 2>/dev/null || echo "Unknown")

        echo "appimage|$pkg_name|unknown|$size_kb|$size_human|$appimage_path" >> "$output_file"
    done < <(scan_appimage_files)

    local total_count=$(wc -l < "$output_file")
    echo -e "${GREEN}✓${NC} Found $total_count applications"
}

# Interactive app selector
show_app_selector() {
    local apps_file="$1"
    local -a selected_items=()

    clear_screen
    echo -e "${GREEN}Fub Uninstaller${NC} - Select applications to remove"
    echo ""

    # Simple menu display
    local line_num=1
    while IFS='|' read -r pkg_type pkg_name version size_kb size_human extra; do
        local marker="[ ]"
        local type_badge=""

        case "$pkg_type" in
            apt) type_badge="${BLUE}[APT]${NC}" ;;
            snap) type_badge="${PURPLE}[SNAP]${NC}" ;;
            flatpak) type_badge="${GREEN}[FLATPAK]${NC}" ;;
            appimage) type_badge="${YELLOW}[APPIMAGE]${NC}" ;;
        esac

        printf "%3d. %s %-20s %s %s\n" "$line_num" "$marker" "$type_badge" "$pkg_name" "$size_human"
        ((line_num++))
    done < "$apps_file"

    echo ""
    echo -e "${GRAY}Enter package numbers to uninstall (space-separated), or 'q' to quit:${NC}"
    read -r selection

    if [[ "$selection" == "q" ]]; then
        return 1
    fi

    # Parse selection
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            local line=$(sed -n "${num}p" "$apps_file")
            if [[ -n "$line" ]]; then
                selected_items+=("$line")
            fi
        fi
    done

    # Uninstall selected
    for item in "${selected_items[@]}"; do
        IFS='|' read -r pkg_type pkg_name version size_kb size_human extra <<< "$item"

        echo ""
        echo -e "${BLUE}Uninstalling:${NC} $pkg_name ($pkg_type)"

        # Check if data-protected
        if is_data_protected "$pkg_name"; then
            echo -e "${YELLOW}⚠${NC} This application may contain important data."
            read -p "Continue? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "${GRAY}Skipped${NC}"
                continue
            fi
        fi

        # Uninstall
        case "$pkg_type" in
            apt)
                uninstall_apt_package "$pkg_name" true
                ;;
            snap)
                uninstall_snap_package "$pkg_name"
                ;;
            flatpak)
                uninstall_flatpak_package "$pkg_name"
                ;;
            appimage)
                uninstall_appimage "$extra"  # extra contains the path
                ;;
        esac

        # Clean up config files
        echo -e "  ${BLUE}→${NC} Cleaning configuration files..."
        local config_files=$(find_app_files "$pkg_name" "$pkg_type")
        if [[ -n "$config_files" ]]; then
            echo "$config_files" | while read -r file; do
                if [[ -e "$file" ]]; then
                    rm -rf "$file" 2>/dev/null || true
                    echo -e "    ${GREEN}✓${NC} Removed: $file"
                fi
            done
        fi

        echo -e "${GREEN}✓${NC} Uninstalled $pkg_name"
    done

    return 0
}

# Main function
main() {
    # Check for help
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat <<EOF
Fub Uninstaller - Ubuntu Edition

Interactive application uninstaller with multi-package-manager support.

Supports:
  - APT/DPKG packages
  - Snap packages
  - Flatpak applications
  - AppImage files

Protected packages:
  - System-critical packages cannot be uninstalled
  - Data-protected packages require confirmation

Usage:
  uninstall.sh          Launch interactive uninstaller
  uninstall.sh --help   Show this help

EOF
        exit 0
    fi

    # Banner
    clear_screen
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Fub Uninstaller               ║${NC}"
    echo -e "${GREEN}║    Complete Application Removal       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""

    # Scan applications
    local apps_cache="$HOME/.cache/fub/apps_list.txt"
    mkdir -p "$(dirname "$apps_cache")"

    scan_all_applications "$apps_cache"

    if [[ ! -s "$apps_cache" ]]; then
        echo -e "${YELLOW}No applications found to uninstall.${NC}"
        exit 0
    fi

    # Show selector
    show_app_selector "$apps_cache"

    echo ""
    echo -e "${GREEN}✓${NC} Uninstall complete!"
}

main "$@"
