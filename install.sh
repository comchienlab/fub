#!/usr/bin/env bash

# FUB Installation Script
# One-command installation for FUB (Filesystem Ubuntu Buddy)

set -Eeuo pipefail

# Constants
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly REPO_URL="https://raw.githubusercontent.com/[user]/fub/main"
readonly INSTALL_DIR="/usr/local/bin"
readonly FUB_EXECUTABLE="fub"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Global variables
UNINSTALL_MODE=false
DRY_RUN_MODE=false
VERBOSE=false

# =============================================================================
# Utility Functions
# =============================================================================

print_usage() {
    cat << EOF
FUB Installation Script v$VERSION

USAGE:
    $SCRIPT_NAME                    Install FUB to $INSTALL_DIR
    $SCRIPT_NAME --uninstall        Remove FUB from system
    $SCRIPT_NAME --dry-run          Show what would be done without executing
    $SCRIPT_NAME --verbose          Show detailed installation steps
    $SCRIPT_NAME --help             Show this help message

EXAMPLES:
    curl -fsSL $REPO_URL/install.sh | bash
    curl -fsSL $REPO_URL/install.sh | bash -s -- --verbose
    $SCRIPT_NAME --uninstall

REQUIREMENTS:
    - Ubuntu 20.04 LTS or newer
    - sudo privileges for installation

For more information, visit: https://github.com/[user]/fub
EOF
}

log() {
    local level=$1
    shift
    local message="$*"

    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG")
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

detect_ubuntu_version() {
    if [[ -f /etc/lsb-release ]]; then
        source /etc/lsb-release
        echo "$DISTRIB_RELEASE"
    elif command -v lsb_release >/dev/null 2>&1; then
        lsb_release -rs
    else
        echo "unknown"
    fi
}

validate_system() {
    log DEBUG "Validating system requirements"

    # Check if running on Ubuntu
    if [[ ! -f /etc/lsb-release ]] && ! command -v lsb_release >/dev/null 2>&1; then
        log ERROR "This installer is designed for Ubuntu systems only"
        exit 1
    fi

    local version=$(detect_ubuntu_version)
    log DEBUG "Detected Ubuntu version: $version"

    case $version in
        24.04|22.04|20.04)
            log INFO "Ubuntu $version detected (supported)"
            ;;
        *)
            log WARN "Ubuntu $version not explicitly tested"
            log WARN "Supported versions: 24.04, 22.04, 20.04"
            read -p "Continue anyway? [y/N]: " -r confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                log INFO "Installation cancelled"
                exit 0
            fi
            ;;
    esac

    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        log INFO "This installation requires sudo privileges"
        if ! sudo -v; then
            log ERROR "Failed to acquire sudo privileges"
            exit 1
        fi
    fi

    log DEBUG "System validation passed"
}

# =============================================================================
# Installation Functions
# =============================================================================

download_fub() {
    local target_file="$1"
    local download_url="$REPO_URL/$FUB_EXECUTABLE"

    log INFO "Downloading FUB from: $download_url"

    if command -v curl >/dev/null 2>&1; then
        if [[ "$VERBOSE" == true ]]; then
            curl -fsSL "$download_url" -o "$target_file"
        else
            curl -fsSL "$download_url" -o "$target_file" 2>/dev/null
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [[ "$VERBOSE" == true ]]; then
            wget -q "$download_url" -O "$target_file"
        else
            wget -q "$download_url" -O "$target_file" 2>/dev/null
        fi
    else
        log ERROR "Neither curl nor wget available for download"
        exit 1
    fi

    # Verify download succeeded
    if [[ ! -f "$target_file" ]] || [[ ! -s "$target_file" ]]; then
        log ERROR "Failed to download FUB executable"
        exit 1
    fi

    log DEBUG "Download completed: $target_file"
}

install_fub() {
    local temp_file="/tmp/$FUB_EXECUTABLE.$$"

    log INFO "Installing FUB v$VERSION to $INSTALL_DIR"

    # Download the executable
    download_fub "$temp_file"

    # Make it executable
    chmod +x "$temp_file"

    if [[ "$DRY_RUN_MODE" == true ]]; then
        log INFO "[DRY-RUN] Would move $temp_file to $INSTALL_DIR/$FUB_EXECUTABLE"
        log INFO "[DRY-RUN] Would set executable permissions"
        rm -f "$temp_file"
        return 0
    fi

    # Install to system directory
    if sudo mv "$temp_file" "$INSTALL_DIR/$FUB_EXECUTABLE"; then
        log INFO "Successfully installed FUB to $INSTALL_DIR/$FUB_EXECUTABLE"
    else
        log ERROR "Failed to install FUB to $INSTALL_DIR"
        rm -f "$temp_file"
        exit 1
    fi

    # Verify installation
    local installed_path="$INSTALL_DIR/$FUB_EXECUTABLE"
    if [[ -x "$installed_path" ]]; then
        log INFO "FUB v$VERSION installed successfully"

        # Test the installation
        if "$installed_path" --version >/dev/null 2>&1; then
            log INFO "Installation verified - FUB is working correctly"
        else
            log WARN "Installation completed but verification failed"
        fi
    else
        log ERROR "Installation verification failed"
        exit 1
    fi
}

uninstall_fub() {
    local installed_path="$INSTALL_DIR/$FUB_EXECUTABLE"

    if [[ ! -f "$installed_path" ]]; then
        log WARN "FUB is not installed at $installed_path"
        return 0
    fi

    log INFO "Removing FUB from $installed_path"

    if [[ "$DRY_RUN_MODE" == true ]]; then
        log INFO "[DRY-RUN] Would remove $installed_path"
        return 0
    fi

    if sudo rm -f "$installed_path"; then
        log INFO "FUB has been successfully uninstalled"
    else
        log ERROR "Failed to uninstall FUB"
        exit 1
    fi
}

# =============================================================================
# Post-Installation
# =============================================================================

show_success_message() {
    if [[ "$UNINSTALL_MODE" == true ]]; then
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}                    ${WHITE}UNINSTALL COMPLETE${NC}                       ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}FUB has been removed from your system.${NC}"
        echo ""
    else
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}                  ${WHITE}INSTALLATION COMPLETE${NC}                       ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}FUB v$VERSION is now installed! 🎉${NC}"
        echo ""
        echo -e "${CYAN}Quick Start:${NC}"
        echo -e "  ${GREEN}fub${NC}                    # Show interactive dashboard"
        echo -e "  ${GREEN}fub clean --dry-run${NC}    # Preview cleanup"
        echo -e "  ${GREEN}fub clean${NC}              # Execute cleanup"
        echo -e "  ${GREEN}fub --help${NC}             # Show help"
        echo ""
        echo -e "${CYAN}Tagline:${NC} Dig deep like a mole to clean your Ubuntu"
        echo ""
        echo -e "${YELLOW}First time? Run 'fub clean --dry-run' to see what can be cleaned.${NC}"
        echo ""
    fi
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                echo ""
                print_usage
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    echo -e "${BLUE}FUB Installation Script v$VERSION${NC}"
    echo -e "${BLUE}Dig deep like a mole to clean your Ubuntu${NC}"
    echo ""

    # Parse command line arguments
    parse_arguments "$@"

    if [[ "$UNINSTALL_MODE" == true ]]; then
        log INFO "Starting FUB uninstallation"
        uninstall_fub
    else
        log INFO "Starting FUB installation"
        validate_system
        install_fub
    fi

    show_success_message
}

# Run main function with all arguments
main "$@"