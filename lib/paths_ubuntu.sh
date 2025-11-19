#!/bin/bash
# lib/paths_ubuntu.sh - Ubuntu/Linux XDG Path Constants
# This file defines standard XDG Base Directory paths for Ubuntu
# https://specifications.freedesktop.org/basedir-spec/latest/

# ============================================================================
# XDG User Directories (with fallbacks)
# ============================================================================

# User cache directory - for non-essential cached data
# Equivalent to macOS ~/Library/Caches
export USER_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"

# User configuration directory - for application settings
# Equivalent to macOS ~/Library/Preferences
export USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# User data directory - for application data files
# Equivalent to macOS ~/Library/Application Support
export USER_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

# User state directory - for logs, history, recent files
# Equivalent to macOS ~/Library/Saved Application State and ~/Library/Logs
export USER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"

# Runtime directory - for sockets, pipes, temporary runtime files
# Must be owned by user with 0700 permissions
export USER_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# ============================================================================
# User Application Directories
# ============================================================================

# User applications (binaries)
export USER_BIN_DIR="$HOME/.local/bin"

# User desktop files (GUI app launchers)
export USER_APPLICATIONS_DIR="$USER_DATA_DIR/applications"

# User trash directory
# Equivalent to macOS ~/.Trash
export TRASH_DIR="$USER_DATA_DIR/Trash"
export TRASH_FILES_DIR="$TRASH_DIR/files"
export TRASH_INFO_DIR="$TRASH_DIR/info"

# ============================================================================
# System Directories
# ============================================================================

# System cache directory
# Equivalent to macOS /Library/Caches
export SYSTEM_CACHE_DIR="/var/cache"

# System log directory
# Equivalent to macOS /Library/Logs
export SYSTEM_LOG_DIR="/var/log"

# System configuration
# Equivalent to macOS /Library/Preferences
export SYSTEM_CONFIG_DIR="/etc"

# System applications
export SYSTEM_BIN_DIR="/usr/bin"
export SYSTEM_LOCAL_BIN_DIR="/usr/local/bin"
export SYSTEM_APPLICATIONS_DIR="/usr/share/applications"

# System data/libraries
export SYSTEM_DATA_DIR="/usr/share"
export SYSTEM_LIB_DIR="/usr/lib"
export SYSTEM_VAR_LIB_DIR="/var/lib"

# ============================================================================
# Package Manager Specific Paths
# ============================================================================

# APT/DPKG paths
export APT_CACHE_DIR="$SYSTEM_CACHE_DIR/apt"
export APT_ARCHIVES_DIR="$APT_CACHE_DIR/archives"
export DPKG_INFO_DIR="$SYSTEM_VAR_LIB_DIR/dpkg"

# Snap paths
export SNAP_DIR="/snap"
export SNAP_USER_DATA_DIR="$HOME/snap"
export SNAP_SYSTEM_DATA_DIR="/var/lib/snapd"
export SNAP_CACHE_DIR="$HOME/.cache/snapd"

# Flatpak paths
export FLATPAK_SYSTEM_DIR="/var/lib/flatpak"
export FLATPAK_USER_DIR="$USER_DATA_DIR/flatpak"
export FLATPAK_USER_APP_DATA_DIR="$HOME/.var/app"

# ============================================================================
# Common Application Cache Locations
# ============================================================================

# Browser caches
export CHROME_CACHE_DIR="$USER_CACHE_DIR/google-chrome"
export CHROMIUM_CACHE_DIR="$USER_CACHE_DIR/chromium"
export FIREFOX_CACHE_DIR="$USER_CACHE_DIR/mozilla/firefox"
export EDGE_CACHE_DIR="$USER_CACHE_DIR/microsoft-edge"
export BRAVE_CACHE_DIR="$USER_CACHE_DIR/BraveSoftware"

# Desktop environment caches
export GNOME_CACHE_DIR="$USER_CACHE_DIR/gnome"
export THUMBNAIL_CACHE_DIR="$USER_CACHE_DIR/thumbnails"
export THUMBNAIL_LEGACY_DIR="$HOME/.thumbnails"

# Developer tool caches
export NPM_CACHE_DIR="$HOME/.npm/_cacache"
export PIP_CACHE_DIR="$USER_CACHE_DIR/pip"
export CARGO_CACHE_DIR="$HOME/.cargo/registry/cache"
export GO_CACHE_DIR="$USER_CACHE_DIR/go-build"
export GRADLE_CACHE_DIR="$HOME/.gradle/caches"
export MAVEN_CACHE_DIR="$HOME/.m2/repository"
export RUSTUP_DOWNLOADS_DIR="$HOME/.rustup/downloads"

# Docker paths (if installed)
export DOCKER_DATA_DIR="/var/lib/docker"
export DOCKER_OVERLAY_DIR="$DOCKER_DATA_DIR/overlay2"
export DOCKER_VOLUMES_DIR="$DOCKER_DATA_DIR/volumes"

# ============================================================================
# System Specific Paths
# ============================================================================

# Boot directory (kernels, initrd)
export BOOT_DIR="/boot"

# Systemd journal logs
export JOURNAL_LOG_DIR="$SYSTEM_LOG_DIR/journal"

# Core dumps
export CORE_DUMP_DIR="/var/crash"
export SYSTEMD_CORE_DUMP_DIR="$SYSTEM_VAR_LIB_DIR/systemd/coredump"

# Temporary directories
export SYSTEM_TMP_DIR="/tmp"
export VAR_TMP_DIR="/var/tmp"
export USER_TMP_DIR="$USER_CACHE_DIR/tmp"

# Wine prefixes (if Wine is installed)
export WINE_PREFIX_DIR="$HOME/.wine"

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure XDG directories exist
ensure_xdg_dirs() {
    mkdir -p "$USER_CACHE_DIR" 2>/dev/null || true
    mkdir -p "$USER_CONFIG_DIR" 2>/dev/null || true
    mkdir -p "$USER_DATA_DIR" 2>/dev/null || true
    mkdir -p "$USER_STATE_DIR" 2>/dev/null || true
}

# Check if path is in user directories (safe to clean)
is_user_path() {
    local path="$1"
    [[ "$path" == "$HOME"* ]] || [[ "$path" == "/home/"* ]]
}

# Check if path is system directory (requires sudo)
is_system_path() {
    local path="$1"
    [[ "$path" == "/var/"* ]] || [[ "$path" == "/usr/"* ]] || \
    [[ "$path" == "/etc/"* ]] || [[ "$path" == "/opt/"* ]] || \
    [[ "$path" == "/boot/"* ]]
}

# Get directory size in bytes
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Get directory size human-readable
get_dir_size_human() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sh "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

# Check if directory exists and is not empty
is_dir_not_empty() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]
}

# ============================================================================
# Initialization
# ============================================================================

# Ensure basic XDG directories exist
ensure_xdg_dirs

# Export all variables for use in other scripts
export -f is_user_path
export -f is_system_path
export -f get_dir_size
export -f get_dir_size_human
export -f is_dir_not_empty
