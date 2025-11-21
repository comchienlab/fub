#!/bin/bash
# Fub - Security Hardening Manager
# Interactive UFW firewall and Fail2Ban setup for Ubuntu
#
# Usage:
#   security.sh          # Launch interactive security manager
#   security.sh --help   # Show help information

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

    echo -e "${RED}Please install fzf to use interactive security manager${NC}"
    return 1
}

# Get UFW status
get_ufw_status() {
    if command -v ufw &>/dev/null; then
        if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            echo "active"
        else
            echo "inactive"
        fi
    else
        echo "not_installed"
    fi
}

# Get Fail2Ban status
get_fail2ban_status() {
    if command -v fail2ban-client &>/dev/null; then
        if systemctl is-active --quiet fail2ban.service 2>/dev/null; then
            echo "active"
        else
            echo "inactive"
        fi
    else
        echo "not_installed"
    fi
}

# Show current security status
show_security_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Current Security Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # UFW status
    local ufw_status=$(get_ufw_status)
    case "$ufw_status" in
        "active")
            echo -e "  ${GRAY}UFW Firewall:${NC}    ${GREEN}Active${NC}"
            local ufw_rules=$(sudo ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")
            echo -e "  ${GRAY}Firewall Rules:${NC}  ${CYAN}$ufw_rules rules configured${NC}"
            ;;
        "inactive")
            echo -e "  ${GRAY}UFW Firewall:${NC}    ${YELLOW}Installed but inactive${NC}"
            ;;
        "not_installed")
            echo -e "  ${GRAY}UFW Firewall:${NC}    ${RED}Not installed${NC}"
            ;;
    esac

    # Fail2Ban status
    local f2b_status=$(get_fail2ban_status)
    case "$f2b_status" in
        "active")
            echo -e "  ${GRAY}Fail2Ban:${NC}        ${GREEN}Active${NC}"
            local banned_ips=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || echo "0")
            echo -e "  ${GRAY}Banned IPs:${NC}      ${CYAN}$banned_ips currently banned${NC}"
            ;;
        "inactive")
            echo -e "  ${GRAY}Fail2Ban:${NC}        ${YELLOW}Installed but inactive${NC}"
            ;;
        "not_installed")
            echo -e "  ${GRAY}Fail2Ban:${NC}        ${RED}Not installed${NC}"
            ;;
    esac

    # SSH status
    if systemctl is-active --quiet ssh.service 2>/dev/null || systemctl is-active --quiet sshd.service 2>/dev/null; then
        echo -e "  ${GRAY}SSH Server:${NC}      ${GREEN}Running${NC}"
    else
        echo -e "  ${GRAY}SSH Server:${NC}      ${GRAY}Not running${NC}"
    fi

    echo ""
}

# Install and configure UFW
setup_ufw() {
    echo -e "${BLUE}Setting up UFW Firewall...${NC}"
    echo ""

    # Install if needed
    if ! command -v ufw &>/dev/null; then
        echo -e "  ${BLUE}→${NC} Installing UFW..."
        if sudo apt-get install -y ufw &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} UFW installed"
        else
            echo -e "${RED}✗ Failed to install UFW${NC}"
            return 1
        fi
    fi

    # Configure default policies
    echo -e "  ${BLUE}→${NC} Configuring default policies..."
    sudo ufw --force reset &>/dev/null
    sudo ufw default deny incoming &>/dev/null
    sudo ufw default allow outgoing &>/dev/null

    # Allow SSH (essential to prevent lockout)
    echo -e "  ${BLUE}→${NC} Allowing SSH (port 22)..."
    sudo ufw allow ssh &>/dev/null

    # Ask about common services
    echo ""
    read -p "Allow HTTP (port 80)? [y/N]: " http_confirm
    if [[ "$http_confirm" =~ ^[Yy]$ ]]; then
        sudo ufw allow http &>/dev/null
        echo -e "  ${GREEN}✓${NC} HTTP allowed"
    fi

    read -p "Allow HTTPS (port 443)? [y/N]: " https_confirm
    if [[ "$https_confirm" =~ ^[Yy]$ ]]; then
        sudo ufw allow https &>/dev/null
        echo -e "  ${GREEN}✓${NC} HTTPS allowed"
    fi

    # Enable firewall
    echo ""
    echo -e "  ${BLUE}→${NC} Enabling firewall..."
    sudo ufw --force enable &>/dev/null

    # Enable on boot
    sudo systemctl enable ufw.service &>/dev/null

    echo ""
    echo -e "${GREEN}✓ UFW Firewall configured and enabled!${NC}"
    echo ""
    show_security_status
}

# Install and configure Fail2Ban
setup_fail2ban() {
    echo -e "${BLUE}Setting up Fail2Ban...${NC}"
    echo ""

    # Install if needed
    if ! command -v fail2ban-client &>/dev/null; then
        echo -e "  ${BLUE}→${NC} Installing Fail2Ban..."
        if sudo apt-get install -y fail2ban &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Fail2Ban installed"
        else
            echo -e "${RED}✗ Failed to install Fail2Ban${NC}"
            return 1
        fi
    fi

    # Create local configuration
    echo -e "  ${BLUE}→${NC} Configuring Fail2Ban..."

    # Create jail.local with SSH protection
    sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
# Ban hosts for 1 hour (3600 seconds)
bantime = 3600

# Host is banned if it has generated "maxretry" during the last "findtime" seconds
findtime = 600
maxretry = 5

# Email notification (optional - configure later)
destemail = root@localhost
sendername = Fail2Ban
mta = sendmail
action = %(action_)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

    # Restart Fail2Ban
    echo -e "  ${BLUE}→${NC} Starting Fail2Ban service..."
    sudo systemctl restart fail2ban.service &>/dev/null
    sudo systemctl enable fail2ban.service &>/dev/null

    echo ""
    echo -e "${GREEN}✓ Fail2Ban configured and enabled!${NC}"
    echo -e "  ${GRAY}Protection:${NC} SSH brute-force attacks"
    echo -e "  ${GRAY}Max retries:${NC} 3 failed attempts"
    echo -e "  ${GRAY}Ban time:${NC} 2 hours"
    echo ""
    show_security_status
}

# Disable UFW
disable_ufw() {
    echo -e "${BLUE}Disabling UFW Firewall...${NC}"
    echo ""

    if sudo ufw --force disable &>/dev/null; then
        echo -e "${GREEN}✓ UFW disabled${NC}"
    else
        echo -e "${RED}✗ Failed to disable UFW${NC}"
        return 1
    fi

    echo ""
    show_security_status
}

# Disable Fail2Ban
disable_fail2ban() {
    echo -e "${BLUE}Disabling Fail2Ban...${NC}"
    echo ""

    if sudo systemctl stop fail2ban.service &>/dev/null; then
        sudo systemctl disable fail2ban.service &>/dev/null
        echo -e "${GREEN}✓ Fail2Ban disabled${NC}"
    else
        echo -e "${RED}✗ Failed to disable Fail2Ban${NC}"
        return 1
    fi

    echo ""
    show_security_status
}

# Show UFW rules
show_ufw_rules() {
    clear_screen
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             UFW Firewall Rules                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    sudo ufw status numbered

    echo ""
    read -p "Press Enter to continue..."
}

# Show Fail2Ban status
show_fail2ban_stats() {
    clear_screen
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             Fail2Ban Status                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    if command -v fail2ban-client &>/dev/null; then
        sudo fail2ban-client status
        echo ""
        if sudo fail2ban-client status sshd &>/dev/null; then
            echo -e "${BLUE}SSH Jail Status:${NC}"
            sudo fail2ban-client status sshd
        fi
    else
        echo -e "${YELLOW}Fail2Ban not installed${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Interactive security menu
security_menu() {
    local options=(
        "Setup UFW Firewall"
        "Setup Fail2Ban"
        "Show UFW Rules"
        "Show Fail2Ban Status"
        "Disable UFW"
        "Disable Fail2Ban"
        "Exit"
    )

    local selection=$(printf '%s\n' "${options[@]}" | fzf \
        --height=15 \
        --reverse \
        --border=rounded \
        --header="Select security action:" \
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
Fub Security Hardening Manager

Interactive security setup for Ubuntu systems.

Features:
  - UFW firewall setup with sensible defaults
  - Fail2Ban protection against brute-force attacks
  - SSH server protection
  - View and manage security rules
  - Enable/disable security features

Usage:
  security.sh          Launch interactive security manager
  security.sh --help   Show this help

Examples:
  # Interactive mode
  fub security

  # Auto-setup (via environment)
  FUB_SETUP_UFW=true fub security

Security Recommendations:
  - Always keep UFW firewall enabled
  - Use Fail2Ban for SSH protection
  - Regularly review firewall rules
  - Monitor banned IPs in Fail2Ban

EOF
        exit 0
    fi

    # Ensure fzf is available
    ensure_fzf || exit 1

    # Auto-setup if requested
    if [[ "${FUB_SETUP_UFW:-}" == "true" ]]; then
        setup_ufw
        exit $?
    fi

    if [[ "${FUB_SETUP_FAIL2BAN:-}" == "true" ]]; then
        setup_fail2ban
        exit $?
    fi

    # Interactive mode
    while true; do
        # Banner
        clear_screen
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           Fub Security Hardening Manager              ║${NC}"
        echo -e "${GREEN}║        Firewall & Intrusion Protection Setup          ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Show current status
        show_security_status

        # Get user selection
        local selected_action=$(security_menu)

        case "$selected_action" in
            "")
                echo -e "${GRAY}No selection made.${NC}"
                exit 0
                ;;
            "Exit")
                echo -e "${GRAY}Exiting security manager.${NC}"
                exit 0
                ;;
            "Setup UFW Firewall")
                read -p "Setup UFW firewall with recommended settings? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    setup_ufw
                    read -p "Press Enter to continue..."
                fi
                ;;
            "Setup Fail2Ban")
                read -p "Setup Fail2Ban with SSH protection? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    setup_fail2ban
                    read -p "Press Enter to continue..."
                fi
                ;;
            "Show UFW Rules")
                show_ufw_rules
                ;;
            "Show Fail2Ban Status")
                show_fail2ban_stats
                ;;
            "Disable UFW")
                read -p "Are you sure you want to disable UFW firewall? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    disable_ufw
                    read -p "Press Enter to continue..."
                fi
                ;;
            "Disable Fail2Ban")
                read -p "Are you sure you want to disable Fail2Ban? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    disable_fail2ban
                    read -p "Press Enter to continue..."
                fi
                ;;
        esac
    done
}

main "$@"
