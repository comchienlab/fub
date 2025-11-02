#!/usr/bin/env bash

# FUB Common Utility Library
# Provides shared utilities and core functions for the FUB Ubuntu utility toolkit

set -euo pipefail

# Global variables (only set if not already defined)
[[ -z "${FUB_VERSION:-}" ]] && readonly FUB_VERSION="1.0.0"
[[ -z "${FUB_SCRIPT_DIR:-}" ]] && readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${FUB_ROOT_DIR:-}" ]] && readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
[[ -z "${FUB_CONFIG_DIR:-}" ]] && readonly FUB_CONFIG_DIR="${FUB_CONFIG_DIR:-${FUB_ROOT_DIR}/config}"
[[ -z "${FUB_LOG_FILE:-}" ]] && readonly FUB_LOG_FILE="${FUB_LOG_FILE:-${HOME}/.cache/fub/logs/fub.log}"

# Logging levels
if [[ -z "${LOG_LEVELS:-}" ]]; then
    LOG_LEVELS_DEBUG=0
    LOG_LEVELS_INFO=1
    LOG_LEVELS_WARN=2
    LOG_LEVELS_ERROR=3
    LOG_LEVELS_FATAL=4
fi
[[ -z "${DEFAULT_LOG_LEVEL:-}" ]] && readonly DEFAULT_LOG_LEVEL=1

# Initialize logging
mkdir -p "$(dirname "$FUB_LOG_FILE")"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Skip if level is below current log level
    local current_level_var="LOG_LEVELS_${FUB_LOG_LEVEL:-INFO}"
    local current_level="${!current_level_var:-$DEFAULT_LOG_LEVEL}"
    local message_level_var="LOG_LEVELS_$level"
    local message_level="${!message_level_var}"

    if [[ $message_level -lt $current_level ]]; then
        return 0
    fi

    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$FUB_LOG_FILE"

    # Write to stderr for errors, stdout otherwise
    if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
        echo "[$timestamp] [$level] $message" >&2
    else
        echo "[$timestamp] [$level] $message"
    fi
}

log_debug() { log "DEBUG" "$@"; }
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_fatal() { log "FATAL" "$@"; }

# Error handling utilities
die() {
    log_fatal "$@"
    exit 1
}

handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    exit $exit_code
}

# Set up error trapping
trap 'handle_error $LINENO' ERR

# System detection utilities
is_ubuntu() {
    [[ -f /etc/os-release ]] && grep -q "ID=ubuntu" /etc/os-release
}

get_ubuntu_version() {
    if is_ubuntu; then
        grep "VERSION_ID" /etc/os-release | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

is_root() {
    [[ $EUID -eq 0 ]]
}

require_root() {
    if ! is_root; then
        die "This operation requires root privileges. Use sudo."
    fi
}

# String utilities
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# File and directory utilities
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

is_executable() {
    [[ -x "$1" ]]
}

# Command utilities
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local cmd="$1"
    if ! command_exists "$cmd"; then
        die "Required command not found: $cmd"
    fi
}

run_sudo() {
    if is_root; then
        "$@"
    else
        log_debug "Running with sudo: $*"
        sudo "$@"
    fi
}

# Process utilities
kill_process() {
    local pid="$1"
    local signal="${2:-TERM}"

    if [[ -z "$pid" ]]; then
        log_error "No PID provided"
        return 1
    fi

    if ! kill "-$signal" "$pid" 2>/dev/null; then
        log_error "Failed to send signal $signal to process $pid"
        return 1
    fi

    log_debug "Sent signal $signal to process $pid"
}

is_process_running() {
    local pid="$1"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Network utilities
is_connected() {
    local host="${1:-8.8.8.8}"
    local timeout="${2:-5}"

    if command_exists ping; then
        ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1
    elif command_exists curl; then
        curl -s --connect-timeout "$timeout" "http://$host" >/dev/null 2>&1
    else
        log_warn "No network test tools available (ping/curl)"
        return 0
    fi
}

download_file() {
    local url="$1"
    local output="$2"

    require_command curl
    log_info "Downloading $url to $output"

    if curl -fsSL "$url" -o "$output"; then
        log_info "Download completed successfully"
        return 0
    else
        log_error "Failed to download $url"
        return 1
    fi
}

# Package management utilities
update_package_list() {
    log_info "Updating package list..."
    run_sudo apt-get update
    log_info "Package list updated"
}

install_package() {
    local package="$1"
    log_info "Installing package: $package"
    run_sudo apt-get install -y "$package"
    log_info "Package $package installed successfully"
}

remove_package() {
    local package="$1"
    log_info "Removing package: $package"
    run_sudo apt-get remove -y "$package"
    run_sudo apt-get autoremove -y
    log_info "Package $package removed successfully"
}

is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Service management utilities
service_exists() {
    local service="$1"
    systemctl list-unit-files | grep -q "^$service\.service"
}

is_service_active() {
    local service="$1"
    systemctl is-active --quiet "$service"
}

is_service_enabled() {
    local service="$1"
    systemctl is-enabled --quiet "$service" 2>/dev/null
}

start_service() {
    local service="$1"
    log_info "Starting service: $service"
    run_sudo systemctl start "$service"
    log_info "Service $service started"
}

stop_service() {
    local service="$1"
    log_info "Stopping service: $service"
    run_sudo systemctl stop "$service"
    log_info "Service $service stopped"
}

enable_service() {
    local service="$1"
    log_info "Enabling service: $service"
    run_sudo systemctl enable "$service"
    log_info "Service $service enabled"
}

disable_service() {
    local service="$1"
    log_info "Disabling service: $service"
    run_sudo systemctl disable "$service"
    log_info "Service $service disabled"
}

# File system utilities
get_disk_usage() {
    local path="${1:-/}"
    df -h "$path" | tail -1 | awk '{print $5}' | sed 's/%//'
}

get_free_space() {
    local path="${1:-/}"
    df -h "$path" | tail -1 | awk '{print $4}'
}

cleanup_temp_files() {
    local temp_dir="${1:-/tmp}"
    log_info "Cleaning up temporary files in $temp_dir"

    # Remove files older than 7 days
    find "$temp_dir" -type f -mtime +7 -delete 2>/dev/null || true
    log_info "Temporary files cleanup completed"
}

# Configuration utilities
get_config_value() {
    local key="$1"
    local default="${2:-}"
    local config_file="${3:-${FUB_CONFIG_DIR}/default.yaml}"

    # This is a simple key extraction - in a real implementation,
    # you'd want a proper YAML parser
    if file_exists "$config_file"; then
        grep "^${key}:" "$config_file" | cut -d':' -f2- | sed 's/^ *//' | tr -d '"'
    else
        echo "$default"
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    local config_file="${3:-${FUB_CONFIG_DIR}/default.yaml}"

    log_debug "Setting config $key=$value in $config_file"
    # Simple implementation - in production, use proper YAML editing
    if grep -q "^${key}:" "$config_file"; then
        sed -i "s/^${key}:.*/${key}: ${value}/" "$config_file"
    else
        echo "${key}: ${value}" >> "$config_file"
    fi
}

# Validation utilities
validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_url() {
    local url="$1"
    [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]
}

# Performance utilities
measure_time() {
    local start_time end_time
    start_time=$(date +%s.%N)

    "$@"
    local exit_code=$?

    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

    log_debug "Command completed in ${duration}s"
    return $exit_code
}

# Version comparison utilities
version_compare() {
    local version1="$1"
    local operator="$2"
    local version2="$3"

    # Use sort -V for version comparison
    if [[ "$operator" == "==" ]]; then
        [[ "$version1" == "$version2" ]]
    elif [[ "$operator" == "!=" ]]; then
        [[ "$version1" != "$version2" ]]
    elif [[ "$operator" == "<" ]]; then
        [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -1)" == "$version1" ]]
    elif [[ "$operator" == "<=" ]]; then
        [[ "$version1" == "$version2" ]] || [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -1)" == "$version1" ]]
    elif [[ "$operator" == ">" ]]; then
        [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | tail -1)" == "$version1" ]]
    elif [[ "$operator" == ">=" ]]; then
        [[ "$version1" == "$version2" ]] || [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | tail -1)" == "$version1" ]]
    else
        log_error "Invalid comparison operator: $operator"
        return 1
    fi
}

# Cleanup function for script exit
cleanup() {
    local exit_code=$?
    log_debug "Cleaning up on exit (code: $exit_code)"
    # Add any cleanup tasks here
}

# Set up cleanup trap
trap cleanup EXIT

# Export utility functions for use in other modules
export -f log log_debug log_info log_warn log_error log_fatal die handle_error
export -f trim lowercase uppercase ensure_dir file_exists dir_exists is_executable
export -f command_exists require_command run_sudo kill_process is_process_running
export -f is_connected download_file update_package_list install_package remove_package
export -f is_package_installed service_exists is_service_active is_service_enabled
export -f start_service stop_service enable_service disable_service
export -f get_disk_usage get_free_space cleanup_temp_files
export -f get_config_value set_config_value validate_email validate_url validate_port
export -f measure_time version_compare is_ubuntu get_ubuntu_version is_root require_root

log_debug "FUB common utilities loaded successfully"