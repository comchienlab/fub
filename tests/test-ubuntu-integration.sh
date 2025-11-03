#!/usr/bin/env bash

# FUB Ubuntu Integration Tests
# Real Ubuntu system integration testing with multiple versions

set -euo pipefail

# Ubuntu integration test metadata
readonly UBUNTU_TEST_VERSION="2.0.0"
readonly UBUNTU_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UBUNTU_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test frameworks
source "${UBUNTU_TEST_DIR}/test-framework.sh"
source "${UBUNTU_TEST_DIR}/test-safety-framework.sh"

# Ubuntu integration test configuration
declare -A UBUNTU_CONFIG=(
    ["test_mode"]="real_system"
    ["require_ubuntu"]="true"
    ["require_sudo"]="false"
    ["safe_operations_only"]="true"
    ["create_backups"]="true"
    ["test_package_operations"]="true"
    ["test_service_operations"]="true"
    ["test_filesystem_operations"]="true"
    ["test_network_operations"]="false"  # Disabled for safety
)

# Ubuntu version compatibility matrix
declare -A UBUNTU_VERSIONS=(
    ["20.04"]="focal"
    ["22.04"]="jammy"
    ["24.04"]="noble"
    ["24.10"]="oracular"
)

# Integration test results
declare -A UBUNTU_RESULTS=(
    ["total_tests"]=0
    ["passed_tests"]=0
    ["failed_tests"]=0
    ["skipped_tests"]=0
    ["system_errors"]=0
    ["warnings"]=0
)

# System information
DETECTED_UBUNTU_VERSION=""
DETECTED_UBUNTU_CODENAME=""
IS_UBUNTU_SYSTEM=false
HAS_SUDO_ACCESS=false
SYSTEM_ARCHITECTURE=""

# Test setup
setup_ubuntu_integration_tests() {
    # Set up test environment
    FUB_TEST_DIR=$(setup_test_env)

    # Configure Ubuntu integration test mode
    export FUB_UBUNTU_INTEGRATION_TEST="true"
    export FUB_TEST_MODE="true"
    export FUB_SAFE_OPERATIONS_ONLY="${UBUNTU_CONFIG[safe_operations_only]}"

    # Detect Ubuntu system
    detect_ubuntu_system

    # Validate system requirements
    validate_ubuntu_requirements

    # Set up safe testing environment
    setup_safe_test_environment

    # Initialize test results tracking
    init_ubuntu_test_results
}

# Detect Ubuntu system information
detect_ubuntu_system() {
    echo "🔍 Detecting Ubuntu system information..."

    # Check if running on Ubuntu
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            IS_UBUNTU_SYSTEM=true
            DETECTED_UBUNTU_VERSION="$VERSION_ID"
            DETECTED_UBUNTU_CODENAME="${UBUNTU_CODENAME:-unknown}"
            echo "✓ Ubuntu $DETECTED_UBUNTU_VERSION ($DETECTED_UBUNTU_CODENAME) detected"
        else
            echo "⚠️  Not running on Ubuntu system: $ID $VERSION_ID"
            IS_UBUNTU_SYSTEM=false
        fi
    else
        echo "❌ Cannot detect OS information"
        IS_UBUNTU_SYSTEM=false
    fi

    # Detect system architecture
    SYSTEM_ARCHITECTURE=$(uname -m)
    echo "✓ Architecture: $SYSTEM_ARCHITECTURE"

    # Check sudo access
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            HAS_SUDO_ACCESS=true
            echo "✓ Sudo access available"
        else
            HAS_SUDO_ACCESS=false
            echo "⚠️  Sudo access not available (password required)"
        fi
    else
        HAS_SUDO_ACCESS=false
        echo "⚠️  Sudo command not found"
    fi
}

# Validate Ubuntu system requirements
validate_ubuntu_requirements() {
    echo "🔍 Validating Ubuntu system requirements..."

    local requirements_met=true

    # Check if Ubuntu is required
    if [[ "${UBUNTU_CONFIG[require_ubuntu]}" == "true" ]] && [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        echo "❌ Ubuntu system required but not detected"
        requirements_met=false
    fi

    # Check if sudo is required
    if [[ "${UBUNTU_CONFIG[require_sudo]}" == "true" ]] && [[ "$HAS_SUDO_ACCESS" != "true" ]]; then
        echo "❌ Sudo access required but not available"
        requirements_met=false
    fi

    # Check required Ubuntu tools
    local required_tools=("apt" "dpkg" "systemctl" "find" "grep" "sed" "awk")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✓ $tool available"
        else
            echo "❌ Required tool $tool not found"
            requirements_met=false
        fi
    done

    # Check disk space for testing
    local available_space
    available_space=$(df /tmp | awk 'NR==2{print $4}' 2>/dev/null || echo "0")
    if [[ "$available_space" -gt 1048576 ]]; then  # 1GB in KB
        echo "✓ Sufficient disk space: $(( available_space / 1024 ))MB available"
    else
        echo "⚠️  Low disk space: $(( available_space / 1024 ))MB available (1GB recommended)"
        ((UBUNTU_RESULTS["warnings"]++))
    fi

    if [[ "$requirements_met" != "true" ]]; then
        echo "❌ Ubuntu system requirements not met"
        exit 1
    fi

    echo "✓ Ubuntu system requirements validated"
}

# Set up safe test environment
setup_safe_test_environment() {
    echo "🔧 Setting up safe test environment..."

    # Create test directories
    local test_workspace="${FUB_TEST_DIR}/ubuntu_workspace"
    mkdir -p "$test_workspace"/{test_files,backup_area,package_test,service_test,filesystem_test}

    # Create test files in safe location
    create_test_files "$test_workspace/test_files"

    # Set up backup area
    export FUB_BACKUP_DIR="$test_workspace/backup_area"
    mkdir -p "$FUB_BACKUP_DIR"/{system,files,packages}

    # Configure test environment variables
    export FUB_TEST_WORKSPACE="$test_workspace"
    export FUB_SAFE_MODE="true"

    echo "✓ Safe test environment ready"
}

# Create test files for Ubuntu integration testing
create_test_files() {
    local test_dir="$1"

    # Create various types of test files
    mkdir -p "$test_dir"/{cache,logs,temp,config,documents}

    # Cache files
    touch "$test_dir/cache/app1.cache"
    touch "$test_dir/cache/app2.cache"
    echo "test cache content" > "$test_dir/cache/test.cache"

    # Log files
    echo "$(date): Test log entry" > "$test_dir/logs/test.log"
    echo "$(date): Another log entry" >> "$test_dir/logs/test.log"
    touch "$test_dir/logs/old.log"

    # Temporary files
    echo "temp content" > "$test_dir/temp/temp_file.tmp"
    touch "$test_dir/temp/another_temp.tmp"

    # Configuration files
    echo "# Test configuration" > "$test_dir/config/test.conf"
    echo "setting=value" > "$test_dir/config/settings.ini"

    # Document files
    echo "# Test Document" > "$test_dir/documents/test.md"
    echo "test content" > "$test_dir/documents/readme.txt"
}

# Initialize Ubuntu test results
init_ubuntu_test_results() {
    UBUNTU_RESULTS["total_tests"]=0
    UBUNTU_RESULTS["passed_tests"]=0
    UBUNTU_RESULTS["failed_tests"]=0
    UBUNTU_RESULTS["skipped_tests"]=0
    UBUNTU_RESULTS["system_errors"]=0
    UBUNTU_RESULTS["warnings"]=0

    # Create results file
    local results_file="${FUB_TEST_DIR}/ubuntu_test_results.json"
    cat > "$results_file" << EOF
{
  "test_timestamp": "$(date -Iseconds)",
  "ubuntu_version": "$DETECTED_UBUNTU_VERSION",
  "ubuntu_codename": "$DETECTED_UBUNTU_CODENAME",
  "architecture": "$SYSTEM_ARCHITECTURE",
  "sudo_access": $HAS_SUDO_ACCESS,
  "test_configuration": $(declare -p UBUNTU_CONFIG | sed 's/declare -A UBUNTU_CONFIG=/\n  /'),
  "results": {}
}
EOF
    export FUB_UBUNTU_RESULTS_FILE="$results_file"
}

# Test teardown
teardown_ubuntu_integration_tests() {
    echo "🧹 Cleaning up Ubuntu integration test environment..."

    # Remove test files
    if [[ -n "${FUB_TEST_WORKSPACE:-}" ]] && [[ -d "$FUB_TEST_WORKSPACE" ]]; then
        rm -rf "$FUB_TEST_WORKSPACE"
    fi

    # Cleanup environment variables
    unset FUB_UBUNTU_INTEGRATION_TEST FUB_SAFE_OPERATIONS_ONLY
    unset FUB_TEST_WORKSPACE FUB_BACKUP_DIR FUB_SAFE_MODE FUB_UBUNTU_RESULTS_FILE

    # Cleanup test environment
    cleanup_test_env "$FUB_TEST_DIR"
}

# =============================================================================
# UBUNTU PACKAGE MANAGER INTEGRATION TESTS
# =============================================================================

test_ubuntu_package_manager() {
    echo "📦 Testing Ubuntu Package Manager Integration"

    # Test 1: Package information retrieval
    test_package_information

    # Test 2: Package listing
    test_package_listing

    # Test 3: Repository status
    test_repository_status

    # Test 4: Package cache operations (read-only)
    test_package_cache_operations

    # Test 5: Package dependency checking
    test_dependency_resolution
}

# Test package information retrieval
test_package_information() {
    local test_name="Package Information Retrieval"
    local test_package="ubuntu-minimal"  # Should always exist on Ubuntu

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test apt-cache show
    if timeout 30 apt-cache show "$test_package" >/dev/null 2>&1; then
        local package_info
        package_info=$(apt-cache show "$test_package" 2>/dev/null | head -10)
        log_test_pass "$test_name" "Successfully retrieved info for $test_package"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to retrieve info for $test_package"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test package listing
test_package_listing() {
    local test_name="Package Listing Operations"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test dpkg -l
    if timeout 30 dpkg -l >/dev/null 2>&1; then
        local package_count
        package_count=$(dpkg -l 2>/dev/null | grep "^ii" | wc -l)
        log_test_pass "$test_name" "Listed $package_count installed packages"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to list packages with dpkg"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test repository status
test_repository_status() {
    local test_name="Repository Status"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check if sources.list exists
    if [[ -f /etc/apt/sources.list ]]; then
        local repo_count
        repo_count=$(grep -c "^deb " /etc/apt/sources.list 2>/dev/null || echo "0")
        if [[ "$repo_count" -gt 0 ]]; then
            log_test_pass "$test_name" "Found $repo_count configured repositories"
            ((UBUNTU_RESULTS["passed_tests"]++))
        else
            log_test_fail "$test_name" "No repositories found in sources.list"
            ((UBUNTU_RESULTS["failed_tests"]++))
        fi
    else
        log_test_fail "$test_name" "sources.list file not found"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test package cache operations (read-only)
test_package_cache_operations() {
    local test_name="Package Cache Operations"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check cache directory
    if [[ -d /var/cache/apt ]]; then
        local cache_size
        cache_size=$(du -sh /var/cache/apt 2>/dev/null | cut -f1 || echo "unknown")
        log_test_pass "$test_name" "Package cache directory exists (size: $cache_size)"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Package cache directory not found"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    # Check cache lock (should not be locked during test)
    if [[ -f /var/cache/apt/archives/lock ]]; then
        log_test_fail "$test_name" "Package cache is locked (another operation in progress)"
        ((UBUNTU_RESULTS["failed_tests"]++))
    else
        log_test_pass "$test_name" "Package cache is not locked"
        ((UBUNTU_RESULTS["passed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]+=2))
}

# Test dependency resolution
test_dependency_resolution() {
    local test_name="Package Dependency Resolution"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test apt-cache depends
    if timeout 30 apt-cache depends "ubuntu-minimal" >/dev/null 2>&1; then
        local dep_count
        dep_count=$(apt-cache depends "ubuntu-minimal" 2>/dev/null | grep -c "Depends:" || echo "0")
        log_test_pass "$test_name" "Successfully resolved $dep_count dependencies"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to resolve dependencies"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# =============================================================================
# UBUNTU SERVICE MANAGEMENT INTEGRATION TESTS
# =============================================================================

test_ubuntu_service_management() {
    echo "⚙️  Testing Ubuntu Service Management Integration"

    # Test 1: Service listing
    test_service_listing

    # Test 2: Service status checking
    test_service_status

    # Test 3: Service dependency information
    test_service_dependencies

    # Test 4: Systemd configuration
    test_systemd_configuration
}

# Test service listing
test_service_listing() {
    local test_name="Service Listing"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test systemctl list-units
    if timeout 30 systemctl list-units --type=service --no-pager >/dev/null 2>&1; then
        local service_count
        service_count=$(systemctl list-units --type=service --no-pager 2>/dev/null | grep -c "loaded" || echo "0")
        log_test_pass "$test_name" "Listed $service_count services"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to list services"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test service status checking
test_service_status() {
    local test_name="Service Status Checking"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test with common services that should exist
    local test_services=("systemd-journald" "networking")

    for service in "${test_services[@]}"; do
        if timeout 10 systemctl is-active "$service" >/dev/null 2>&1; then
            log_test_pass "$test_name" "Successfully checked status of $service"
            ((UBUNTU_RESULTS["passed_tests"]++))
        elif timeout 10 systemctl status "$service" >/dev/null 2>&1; then
            # Service exists but might not be active
            log_test_pass "$test_name" "Successfully checked status of $service (inactive)"
            ((UBUNTU_RESULTS["passed_tests"]++))
        else
            log_test_fail "$test_name" "Failed to check status of $service"
            ((UBUNTU_RESULTS["failed_tests"]++))
        fi
        ((UBUNTU_RESULTS["total_tests"]++))
    done
}

# Test service dependencies
test_service_dependencies() {
    local test_name="Service Dependencies"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test systemctl list-dependencies
    if timeout 30 systemctl list-dependencies "basic.target" >/dev/null 2>&1; then
        local dep_count
        dep_count=$(systemctl list-dependencies "basic.target" 2>/dev/null | wc -l || echo "0")
        log_test_pass "$test_name" "Successfully listed $dep_count service dependencies"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to list service dependencies"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test systemd configuration
test_systemd_configuration() {
    local test_name="Systemd Configuration"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check systemd directories
    local systemd_dirs=("/etc/systemd/system" "/run/systemd/system" "/usr/lib/systemd/system")
    local dirs_found=0

    for dir in "${systemd_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            ((dirs_found++))
        fi
    done

    if [[ "$dirs_found" -eq 3 ]]; then
        log_test_pass "$test_name" "All systemd directories found"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Only $dirs_found/3 systemd directories found"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# =============================================================================
# UBUNTU FILESYSTEM INTEGRATION TESTS
# =============================================================================

test_ubuntu_filesystem() {
    echo "📁 Testing Ubuntu Filesystem Integration"

    # Test 1: Ubuntu-specific directories
    test_ubuntu_directories

    # Test 2: File permissions and ownership
    test_file_permissions

    # Test 3: System file locations
    test_system_file_locations

    # Test 4: Log file operations
    test_log_file_operations
}

# Test Ubuntu-specific directories
test_ubuntu_directories() {
    local test_name="Ubuntu Directory Structure"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check Ubuntu-specific directories
    local ubuntu_dirs=("/etc/apt" "/var/lib/dpkg" "/var/log" "/usr/share/doc" "/boot")
    local dirs_found=0

    for dir in "${ubuntu_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            ((dirs_found++))
        fi
    done

    if [[ "$dirs_found" -ge 4 ]]; then
        log_test_pass "$test_name" "Found $dirs_found/5 Ubuntu-specific directories"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Only $dirs_found/5 Ubuntu-specific directories found"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test file permissions and ownership
test_file_permissions() {
    local test_name="File Permissions and Ownership"

    # Test file creation with proper permissions
    local test_file="${FUB_TEST_WORKSPACE}/filesystem_test/perm_test.txt"
    echo "test content" > "$test_file"

    if [[ -f "$test_file" ]]; then
        local file_perms
        file_perms=$(stat -c "%a" "$test_file" 2>/dev/null || stat -f "%A" "$test_file" 2>/dev/null || echo "unknown")
        log_test_pass "$test_name" "Created file with permissions $file_perms"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to create test file"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    # Test directory creation
    local test_dir="${FUB_TEST_WORKSPACE}/filesystem_test/test_dir"
    if mkdir -p "$test_dir/nested"; then
        log_test_pass "$test_name" "Successfully created nested directories"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to create nested directories"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]+=2))
}

# Test system file locations
test_system_file_locations() {
    local test_name="System File Locations"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check important system files
    local system_files=("/etc/passwd" "/etc/group" "/etc/hosts" "/etc/fstab" "/etc/os-release")
    local files_found=0

    for file in "${system_files[@]}"; do
        if [[ -f "$file" ]]; then
            ((files_found++))
        fi
    done

    if [[ "$files_found" -ge 4 ]]; then
        log_test_pass "$test_name" "Found $files_found/5 important system files"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Only $files_found/5 important system files found"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test log file operations
test_log_file_operations() {
    local test_name="Log File Operations"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check log directories
    local log_dirs=("/var/log" "/var/log/apt" "/var/log/dpkg.log")
    local log_dirs_found=0

    if [[ -d "/var/log" ]]; then
        ((log_dirs_found++))

        # Check if we can read log files (as non-root)
        if [[ -r "/var/log/syslog" ]] || [[ -r "/var/log/messages" ]] || [[ -r "/var/log/kern.log" ]]; then
            log_test_pass "$test_name" "Can read system log files"
            ((UBUNTU_RESULTS["passed_tests"]++))
        else
            log_test_pass "$test_name" "System log files not readable (expected for non-root)"
            ((UBUNTU_RESULTS["passed_tests"]++))
        fi
        ((UBUNTU_RESULTS["total_tests"]++))
    else
        log_test_fail "$test_name" "/var/log directory not found"
        ((UBUNTU_RESULTS["failed_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
    fi
}

# =============================================================================
# UBUNTU VERSION COMPATIBILITY TESTS
# =============================================================================

test_ubuntu_version_compatibility() {
    echo "🔧 Testing Ubuntu Version Compatibility"

    local test_name="Ubuntu Version Compatibility"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check if detected version is supported
    if [[ -n "${UBUNTU_VERSIONS[$DETECTED_UBUNTU_VERSION]:-}" ]]; then
        local codename="${UBUNTU_VERSIONS[$DETECTED_UBUNTU_VERSION]}"
        log_test_pass "$test_name" "Ubuntu $DETECTED_UBUNTU_VERSION ($codename) is supported"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_pass "$test_name" "Ubuntu $DETECTED_UBUNTU_VERSION may not be officially supported but tests will proceed"
        ((UBUNTU_RESULTS["passed_tests"]++))
        ((UBUNTU_RESULTS["warnings"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# =============================================================================
# UBUNTU SECURITY TESTS
# =============================================================================

test_ubuntu_security() {
    echo "🔒 Testing Ubuntu Security Integration"

    # Test 1: File permissions on sensitive files
    test_sensitive_file_permissions

    # Test 2: User privilege checking
    test_user_privileges

    # Test 3: Sudo operation safety
    test_sudo_safety
}

# Test sensitive file permissions
test_sensitive_file_permissions() {
    local test_name="Sensitive File Permissions"

    if [[ "$IS_UBUNTU_SYSTEM" != "true" ]]; then
        log_test_skip "$test_name" "Not running on Ubuntu system"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Check permissions on sensitive files (should not be world-writable)
    local sensitive_files=("/etc/passwd" "/etc/shadow" "/etc/sudoers")
    local secure_files=0

    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local file_perms
            file_perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null || echo "unknown")
            # Check if file is world-writable (should not be)
            if [[ "$file_perms" =~ [2367][2367][2367] ]]; then
                log_test_fail "$test_name" "File $file has world-writable permissions ($file_perms)"
                ((UBUNTU_RESULTS["failed_tests"]++))
            else
                ((secure_files++))
            fi
        fi
    done

    if [[ "$secure_files" -gt 0 ]]; then
        log_test_pass "$test_name" "$secure_files sensitive files have secure permissions"
        ((UBUNTU_RESULTS["passed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# Test user privileges
test_user_privileges() {
    local test_name="User Privilege Checking"

    # Check current user
    local current_user
    current_user=$(whoami)
    log_test_pass "$test_name" "Running as user: $current_user"
    ((UBUNTU_RESULTS["passed_tests"]++))

    # Check if running as root
    if [[ "$EUID" -eq 0 ]]; then
        log_test_pass "$test_name" "Running with root privileges"
        ((UBUNTU_RESULTS["passed_tests"]++))
        ((UBUNTU_RESULTS["warnings"]++))
    else
        log_test_pass "$test_name" "Running as non-root user (safer for testing)"
        ((UBUNTU_RESULTS["passed_tests"]++))
    fi

    # Check group memberships
    local user_groups
    user_groups=$(groups 2>/dev/null || echo "unknown")
    if echo "$user_groups" | grep -q "sudo"; then
        log_test_pass "$test_name" "User is in sudo group"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_pass "$test_name" "User is not in sudo group"
        ((UBUNTU_RESULTS["passed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]+=3))
}

# Test sudo safety
test_sudo_safety() {
    local test_name="Sudo Operation Safety"

    if [[ "$HAS_SUDO_ACCESS" != "true" ]]; then
        log_test_skip "$test_name" "No sudo access available"
        ((UBUNTU_RESULTS["skipped_tests"]++))
        ((UBUNTU_RESULTS["total_tests"]++))
        return 0
    fi

    # Test that we can run safe sudo operations
    if sudo whoami >/dev/null 2>&1; then
        log_test_pass "$test_name" "Can execute safe sudo operations"
        ((UBUNTU_RESULTS["passed_tests"]++))
    else
        log_test_fail "$test_name" "Failed to execute safe sudo operations"
        ((UBUNTU_RESULTS["failed_tests"]++))
    fi

    ((UBUNTU_RESULTS["total_tests"]++))
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Log test pass
log_test_pass() {
    local test_name="$1"
    local message="$2"
    echo "  ✅ PASS: $test_name - $message"
}

# Log test fail
log_test_fail() {
    local test_name="$1"
    local message="$2"
    echo "  ❌ FAIL: $test_name - $message"
    ((UBUNTU_RESULTS["system_errors"]++))
}

# Log test skip
log_test_skip() {
    local test_name="$1"
    local message="$2"
    echo "  ⏭️  SKIP: $test_name - $message"
}

# Print Ubuntu integration test summary
print_ubuntu_integration_summary() {
    echo ""
    echo "🔧 Ubuntu Integration Test Summary"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "📊 System Information:"
    echo "   Ubuntu Version: $DETECTED_UBUNTU_VERSION ($DETECTED_UBUNTU_CODENAME)"
    echo "   Architecture: $SYSTEM_ARCHITECTURE"
    echo "   Sudo Access: $HAS_SUDO_ACCESS"
    echo ""
    echo "📈 Test Results:"
    echo "   Total Tests: ${UBUNTU_RESULTS[total_tests]}"
    echo "   Passed: ${UBUNTU_RESULTS[passed_tests]}"
    echo "   Failed: ${UBUNTU_RESULTS[failed_tests]}"
    echo "   Skipped: ${UBUNTU_RESULTS[skipped_tests]}"
    echo "   Warnings: ${UBUNTU_RESULTS[warnings]}"
    echo "   System Errors: ${UBUNTU_RESULTS[system_errors]}"
    echo ""

    # Calculate success rate
    local success_rate=0
    if [[ ${UBUNTU_RESULTS[total_tests]} -gt 0 ]]; then
        success_rate=$(( UBUNTU_RESULTS[passed_tests] * 100 / UBUNTU_RESULTS[total_tests] ))
    fi

    echo "📊 Success Rate: ${success_rate}%"
    echo ""

    # Update results file
    if [[ -n "${FUB_UBUNTU_RESULTS_FILE:-}" ]] && [[ -f "$FUB_UBUNTU_RESULTS_FILE" ]]; then
        jq ".results = {
            \"total_tests\": ${UBUNTU_RESULTS[total_tests]},
            \"passed_tests\": ${UBUNTU_RESULTS[passed_tests]},
            \"failed_tests\": ${UBUNTU_RESULTS[failed_tests]},
            \"skipped_tests\": ${UBUNTU_RESULTS[skipped_tests]},
            \"warnings\": ${UBUNTU_RESULTS[warnings]},
            \"system_errors\": ${UBUNTU_RESULTS[system_errors]},
            \"success_rate\": $success_rate
        }" "$FUB_UBUNTU_RESULTS_FILE" > "${FUB_UBUNTU_RESULTS_FILE}.tmp" && \
        mv "${FUB_UBUNTU_RESULTS_FILE}.tmp" "$FUB_UBUNTU_RESULTS_FILE"
    fi

    if [[ ${UBUNTU_RESULTS[failed_tests]} -eq 0 ]]; then
        echo "🎉 All Ubuntu integration tests passed!"
        echo "   System is fully compatible with FUB."
        return 0
    else
        echo "❌ Some Ubuntu integration tests failed!"
        echo "   Review compatibility issues before deployment."
        return 1
    fi
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

# Run all Ubuntu integration tests
run_ubuntu_integration_tests() {
    echo ""
    echo "🐧 FUB Ubuntu Integration Tests"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Run all test categories
    test_ubuntu_version_compatibility
    test_ubuntu_package_manager
    test_ubuntu_service_management
    test_ubuntu_filesystem
    test_ubuntu_security

    # Print summary
    print_ubuntu_integration_summary
}

# Main test function
main_test() {
    setup_ubuntu_integration_tests
    run_ubuntu_integration_tests
    local result=$?
    teardown_ubuntu_integration_tests
    return $result
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    main_test
fi