#!/bin/bash
# Fub - Swap File Manager
# Interactive swap file creation and management for Ubuntu
#
# Usage:
#   swap.sh          # Launch interactive swap manager
#   swap.sh --help   # Show help information

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Check and install fzf if needed (reuse from uninstall.sh)
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

    echo -e "${RED}Please install fzf to use interactive swap manager${NC}"
    return 1
}

# Get current swap status
get_swap_status() {
    if swapon --show 2>/dev/null | grep -q "/swapfile"; then
        local current_size=$(swapon --show --bytes --noheadings 2>/dev/null | grep "/swapfile" | awk '{print $3}')
        if [[ -n "$current_size" ]]; then
            local size_gb=$((current_size / 1024 / 1024 / 1024))
            echo "${size_gb}GB"
        else
            echo "Unknown"
        fi
    else
        echo "None"
    fi
}

# Show current memory and swap info
show_memory_info() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Current Memory Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Memory info
    local total_mem=$(free -h | awk '/^Mem:/{print $2}')
    local used_mem=$(free -h | awk '/^Mem:/{print $3}')
    local free_mem=$(free -h | awk '/^Mem:/{print $4}')

    echo -e "  ${GRAY}RAM:${NC}         Total: ${GREEN}$total_mem${NC} | Used: ${YELLOW}$used_mem${NC} | Free: ${CYAN}$free_mem${NC}"

    # Swap info
    local swap_status=$(get_swap_status)
    if [[ "$swap_status" == "None" ]]; then
        echo -e "  ${GRAY}Swap:${NC}        ${YELLOW}No swap file configured${NC}"
    else
        local total_swap=$(free -h | awk '/^Swap:/{print $2}')
        local used_swap=$(free -h | awk '/^Swap:/{print $3}')
        echo -e "  ${GRAY}Swap:${NC}        Total: ${GREEN}$total_swap${NC} | Used: ${YELLOW}$used_swap${NC} | Current: ${CYAN}$swap_status${NC}"
    fi

    echo ""
}

# Create swap file with specified size
create_swap_file() {
    local size_gb="$1"
    local swap_path="/swapfile"

    echo -e "${BLUE}Creating ${size_gb}GB swap file...${NC}"
    echo ""

    # Disable existing swap if any
    if swapon --show 2>/dev/null | grep -q "$swap_path"; then
        echo -e "  ${BLUE}→${NC} Disabling existing swap..."
        sudo swapoff "$swap_path" 2>/dev/null || true
    fi

    # Remove old swap file if exists
    if [[ -f "$swap_path" ]]; then
        echo -e "  ${BLUE}→${NC} Removing old swap file..."
        sudo rm -f "$swap_path"
    fi

    # Create new swap file
    echo -e "  ${BLUE}→${NC} Creating ${size_gb}GB swap file (this may take a moment)..."
    if sudo fallocate -l "${size_gb}G" "$swap_path" 2>/dev/null || \
       sudo dd if=/dev/zero of="$swap_path" bs=1G count="$size_gb" status=progress 2>/dev/null; then

        # Set permissions
        echo -e "  ${BLUE}→${NC} Setting permissions..."
        sudo chmod 600 "$swap_path"

        # Format as swap
        echo -e "  ${BLUE}→${NC} Formatting as swap..."
        sudo mkswap "$swap_path" &>/dev/null

        # Enable swap
        echo -e "  ${BLUE}→${NC} Enabling swap..."
        sudo swapon "$swap_path"

        # Add to /etc/fstab if not present
        if ! grep -q "$swap_path" /etc/fstab 2>/dev/null; then
            echo -e "  ${BLUE}→${NC} Adding to /etc/fstab for persistence..."
            echo "$swap_path none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
        fi

        echo ""
        echo -e "${GREEN}✓ Swap file created successfully!${NC}"
        echo ""
        show_memory_info

        return 0
    else
        echo -e "${RED}✗ Failed to create swap file${NC}"
        return 1
    fi
}

# Remove swap file
remove_swap_file() {
    local swap_path="/swapfile"

    echo -e "${BLUE}Removing swap file...${NC}"
    echo ""

    # Disable swap
    if swapon --show 2>/dev/null | grep -q "$swap_path"; then
        echo -e "  ${BLUE}→${NC} Disabling swap..."
        sudo swapoff "$swap_path" || true
    fi

    # Remove from /etc/fstab
    if grep -q "$swap_path" /etc/fstab 2>/dev/null; then
        echo -e "  ${BLUE}→${NC} Removing from /etc/fstab..."
        sudo sed -i "\|$swap_path|d" /etc/fstab
    fi

    # Delete file
    if [[ -f "$swap_path" ]]; then
        echo -e "  ${BLUE}→${NC} Deleting swap file..."
        sudo rm -f "$swap_path"
    fi

    echo ""
    echo -e "${GREEN}✓ Swap file removed${NC}"
    echo ""
    show_memory_info
}

# Interactive swap size selection
select_swap_size() {
    # Prepare size options
    local sizes=("2GB" "4GB" "8GB" "16GB" "32GB" "Custom" "Remove Swap" "Cancel")

    local selection=$(printf '%s\n' "${sizes[@]}" | fzf \
        --height=15 \
        --reverse \
        --border=rounded \
        --header="Select swap file size:" \
        --prompt="Size > " \
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
Fub Swap Manager

Interactive swap file creation and management for Ubuntu systems.

Features:
  - Create swap files with common sizes (2GB, 4GB, 8GB, 16GB, 32GB)
  - Custom swap size support
  - Auto-persist in /etc/fstab
  - Remove existing swap files
  - Show current memory/swap status

Usage:
  swap.sh          Launch interactive swap manager
  swap.sh --help   Show this help

Examples:
  # Interactive mode
  fub swap

  # Create specific size
  FUB_SWAP_SIZE=8 fub swap

Recommendations:
  - Desktop: 4-8GB swap (typical)
  - Server: 2-4GB swap (minimal)
  - Heavy workloads: 16-32GB swap

EOF
        exit 0
    fi

    # Ensure fzf is available
    ensure_fzf || exit 1

    # Banner
    clear_screen
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 Fub Swap Manager                      ║${NC}"
    echo -e "${GREEN}║          Interactive Swap File Configuration          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show current status
    show_memory_info

    # Auto-create if size specified
    if [[ -n "${FUB_SWAP_SIZE:-}" ]]; then
        create_swap_file "${FUB_SWAP_SIZE}"
        exit $?
    fi

    # Interactive selection
    local selected_size=$(select_swap_size)

    case "$selected_size" in
        "")
            echo -e "${GRAY}No selection made.${NC}"
            exit 0
            ;;
        "Cancel")
            echo -e "${GRAY}Cancelled.${NC}"
            exit 0
            ;;
        "Remove Swap")
            read -p "Are you sure you want to remove the swap file? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                remove_swap_file
            else
                echo -e "${GRAY}Cancelled.${NC}"
            fi
            exit 0
            ;;
        "Custom")
            echo ""
            read -p "Enter swap size in GB (e.g., 6): " custom_size
            if [[ "$custom_size" =~ ^[0-9]+$ ]] && [[ $custom_size -gt 0 ]] && [[ $custom_size -le 64 ]]; then
                echo ""
                read -p "Create ${custom_size}GB swap file? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    create_swap_file "$custom_size"
                else
                    echo -e "${GRAY}Cancelled.${NC}"
                fi
            else
                echo -e "${RED}Invalid size. Please enter a number between 1 and 64.${NC}"
                exit 1
            fi
            ;;
        *)
            # Extract size number (e.g., "8GB" -> "8")
            local size_num=$(echo "$selected_size" | grep -o '[0-9]*')
            echo ""
            read -p "Create ${size_num}GB swap file? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                create_swap_file "$size_num"
            else
                echo -e "${GRAY}Cancelled.${NC}"
            fi
            ;;
    esac
}

main "$@"
