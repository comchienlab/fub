#!/bin/bash
# Fub - Uninstall Module (Ubuntu Edition)
# Interactive application uninstaller for Ubuntu with multi-package-manager support
# Uses fzf for fast, fuzzy-searchable package selection
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

# Check and install fzf if needed
ensure_fzf() {
    if command -v fzf &>/dev/null; then
        return 0
    fi

    echo -e "${YELLOW}fzf not found.${NC} Installing fzf for better package selection..."

    # Try to install via apt first
    if command -v apt-get &>/dev/null; then
        if sudo apt-get install -y fzf &>/dev/null; then
            echo -e "${GREEN}✓${NC} fzf installed via apt"
            return 0
        fi
    fi

    # Fallback: install from GitHub release
    echo -e "${BLUE}Installing fzf from GitHub...${NC}"
    local fzf_dir="$HOME/.local/share/fzf"
    local fzf_bin="$HOME/.local/bin/fzf"

    mkdir -p "$HOME/.local/bin" "$(dirname "$fzf_dir")"

    git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir" &>/dev/null || {
        echo -e "${RED}Failed to install fzf${NC}"
        return 1
    }

    "$fzf_dir/install" --bin &>/dev/null
    cp "$fzf_dir/bin/fzf" "$fzf_bin"
    chmod +x "$fzf_bin"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    echo -e "${GREEN}✓${NC} fzf installed to $fzf_bin"
    return 0
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

# Format package entry for fzf display
format_package_entry() {
    local pkg_type="$1"
    local pkg_name="$2"
    local version="$3"
    local size_human="$4"

    local type_badge=""
    local type_color=""

    case "$pkg_type" in
        apt)
            type_badge="[APT    ]"
            type_color="\033[0;34m"  # Blue
            ;;
        snap)
            type_badge="[SNAP   ]"
            type_color="\033[0;35m"  # Magenta
            ;;
        flatpak)
            type_badge="[FLATPAK]"
            type_color="\033[0;32m"  # Green
            ;;
        appimage)
            type_badge="[APPIMG ]"
            type_color="\033[1;33m"  # Yellow
            ;;
    esac

    # Format: [TYPE] name (version) - size
    printf "${type_color}%-10s\033[0m %-30s \033[0;90m%-15s\033[0m %10s" \
        "$type_badge" \
        "$(echo "$pkg_name" | cut -c1-30)" \
        "$(echo "$version" | cut -c1-15)" \
        "$size_human"
}

# Interactive app selector using fzf
show_app_selector() {
    local apps_file="$1"

    # Ensure fzf is installed
    ensure_fzf || {
        echo -e "${RED}Cannot proceed without fzf${NC}"
        return 1
    }

    # Prepare fzf display file
    local fzf_display_file="$HOME/.cache/fub/apps_fzf_display.txt"
    > "$fzf_display_file"

    while IFS='|' read -r pkg_type pkg_name version size_kb size_human extra; do
        local formatted_line=$(format_package_entry "$pkg_type" "$pkg_name" "$version" "$size_human")
        # Store the formatted line + raw data separated by tab
        echo -e "${formatted_line}\t${pkg_type}|${pkg_name}|${version}|${size_kb}|${size_human}|${extra}" >> "$fzf_display_file"
    done < "$apps_file"

    # Count total packages
    local total=$(wc -l < "$fzf_display_file")

    # Run fzf with multi-select
    local fzf_header="╔═══════════════════════════════════════════════════════════════════════════════╗
║ Fub Uninstaller - Select packages to remove (Tab: select, Enter: confirm)   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
Found $total packages | ↑↓: Navigate | Tab: Toggle | Enter: Confirm | Esc: Cancel"

    local selections=$(cat "$fzf_display_file" | fzf \
        --ansi \
        --multi \
        --reverse \
        --height=100% \
        --header="$fzf_header" \
        --header-lines=0 \
        --border=rounded \
        --prompt="Search packages > " \
        --pointer="▶" \
        --marker="✓" \
        --bind="tab:toggle" \
        --bind="shift-tab:toggle+up" \
        --bind="ctrl-a:select-all" \
        --bind="ctrl-d:deselect-all" \
        --preview='echo -e "\033[1;34mPackage Details:\033[0m\n" && echo {} | cut -f2 | awk -F"|" "{print \"Type:    \" \$1 \"\nName:    \" \$2 \"\nVersion: \" \$3 \"\nSize:    \" \$5}"' \
        --preview-window=right:40%:wrap \
        --color='fg:#d0d0d0,bg:#1c1c1c,hl:#5fd7ff' \
        --color='fg+:#ffffff,bg+:#262626,hl+:#5fd7ff' \
        --color='info:#afaf87,prompt:#719e07,pointer:#af5fff' \
        --color='marker:#87ff00,spinner:#af5fff,header:#87afaf' | cut -f2)

    if [[ -z "$selections" ]]; then
        echo -e "${YELLOW}No packages selected.${NC}"
        return 1
    fi

    # Confirm selection
    local selection_count=$(echo "$selections" | wc -l)
    echo ""
    echo -e "${YELLOW}You selected $selection_count package(s) for removal:${NC}"
    echo "$selections" | while IFS='|' read -r pkg_type pkg_name rest; do
        echo -e "  ${BLUE}•${NC} [$pkg_type] $pkg_name"
    done
    echo ""
    read -p "Proceed with uninstallation? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GRAY}Cancelled.${NC}"
        return 1
    fi

    # Uninstall selected packages
    echo ""
    echo "$selections" | while IFS='|' read -r pkg_type pkg_name version size_kb size_human extra; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Uninstalling:${NC} $pkg_name ${GRAY}($pkg_type)${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Check if data-protected
        if is_data_protected "$pkg_name"; then
            echo -e "${YELLOW}⚠${NC}  This application may contain important data."
            read -p "   Continue? (y/N): " data_confirm
            if [[ ! "$data_confirm" =~ ^[Yy]$ ]]; then
                echo -e "${GRAY}   Skipped${NC}"
                continue
            fi
        fi

        # Uninstall based on package type
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

        # Clean up configuration files
        echo -e "  ${BLUE}→${NC} Cleaning configuration files..."
        local config_files=$(find_app_files "$pkg_name" "$pkg_type")
        if [[ -n "$config_files" ]]; then
            local files_removed=0
            echo "$config_files" | while read -r file; do
                if [[ -e "$file" ]]; then
                    rm -rf "$file" 2>/dev/null || true
                    echo -e "    ${GREEN}✓${NC} Removed: $file"
                    ((files_removed++))
                fi
            done
            if [[ $files_removed -eq 0 ]]; then
                echo -e "    ${GRAY}No configuration files found${NC}"
            fi
        else
            echo -e "    ${GRAY}No configuration files found${NC}"
        fi

        echo -e "${GREEN}✓${NC} Successfully uninstalled $pkg_name"
    done

    return 0
}

# Main function
main() {
    # Check for help
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat <<EOF
Fub Uninstaller - Ubuntu Edition (with fzf)

Interactive application uninstaller with multi-package-manager support.
Uses fzf for fast, fuzzy-searchable package selection.

Supports:
  - APT/DPKG packages
  - Snap packages
  - Flatpak applications
  - AppImage files

Features:
  - Fuzzy search across all packages
  - Multi-select with Tab key
  - Live preview of package details
  - Color-coded by package manager
  - Auto-installs fzf if missing

Keyboard shortcuts:
  ↑↓ / jk      Navigate list
  Tab          Toggle selection
  Shift+Tab    Toggle + move up
  Ctrl+A       Select all
  Ctrl+D       Deselect all
  Enter        Confirm selection
  Esc          Cancel

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
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Fub Uninstaller (fzf)                    ║${NC}"
    echo -e "${GREEN}║         Complete Application Removal                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
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
