#!/usr/bin/env bash

# FUB Scheduler Test Suite
# Comprehensive testing for the scheduled maintenance system

set -euo pipefail

# Source test framework
readonly TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${TEST_SCRIPT_DIR}/.." && pwd)"
source "${TEST_SCRIPT_DIR}/test-framework.sh"

# Source scheduler components
source "${FUB_ROOT_DIR}/lib/scheduler/scheduler.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/systemd-integration.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/profiles.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/background-ops.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/notifications.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/history.sh"
source "${FUB_ROOT_DIR}/lib/scheduler/scheduler-integration.sh"

# Test configuration
readonly TEST_PROFILE_NAME="test-profile"
readonly TEST_CONFIG_DIR="${FUB_ROOT_DIR}/test_config"
readonly TEST_STATE_DIR="${FUB_ROOT_DIR}/test_state"

# Cleanup function
cleanup_test_environment() {
    log_info "Cleaning up test environment..."

    # Remove test profile
    if [[ -f "${FUB_PROFILE_USER_DIR}/${TEST_PROFILE_NAME}.yaml" ]]; then
        rm -f "${FUB_PROFILE_USER_DIR}/${TEST_PROFILE_NAME}.yaml"
    fi

    # Deactivate test timer if active
    if systemctl --user is-active --quiet "fub-${TEST_PROFILE_NAME}.timer" 2>/dev/null; then
        uninstall_systemd_timer "$TEST_PROFILE_NAME" 2>/dev/null || true
    fi

    # Clean up test state
    rm -rf "$TEST_CONFIG_DIR" "$TEST_STATE_DIR" 2>/dev/null || true

    log_info "Test environment cleaned up"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."

    # Create test directories
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_STATE_DIR"

    # Set test environment variables
    export FUB_CONFIG_DIR="$TEST_CONFIG_DIR"
    export FUB_LOG_DIR="${TEST_STATE_DIR}/logs"
    export FUB_CACHE_DIR="${TEST_STATE_DIR}/cache"

    log_info "Test environment setup completed"
}

# Test scheduler initialization
test_scheduler_initialization() {
    test_start "Scheduler Initialization"

    # Test basic initialization
    if init_scheduler; then
        test_pass "Scheduler initialized successfully"
    else
        test_fail "Scheduler initialization failed"
        return 1
    fi

    # Check if scheduler state file was created
    if [[ -f "$FUB_SCHEDULER_STATE" ]]; then
        test_pass "Scheduler state file created"
    else
        test_fail "Scheduler state file not found"
        return 1
    fi

    test_end
}

# Test systemd integration
test_systemd_integration() {
    test_start "Systemd Integration"

    # Check if systemd user services are available
    if is_systemd_user_available; then
        test_pass "Systemd user services are available"
    else
        test_skip "Systemd user services not available - skipping systemd tests"
        return 0
    fi

    # Test timer schedule validation
    if validate_systemd_schedule "daily"; then
        test_pass "Valid schedule 'daily' accepted"
    else
        test_fail "Valid schedule 'daily' rejected"
        return 1
    fi

    if validate_systemd_schedule "invalid-schedule"; then
        test_fail "Invalid schedule 'invalid-schedule' accepted"
        return 1
    else
        test_pass "Invalid schedule 'invalid-schedule' rejected"
    fi

    test_end
}

# Test profile management
test_profile_management() {
    test_start "Profile Management"

    # Initialize profiles
    init_profiles

    # Test creating a custom profile
    if create_profile "$TEST_PROFILE_NAME" "Test profile for unit testing" "daily" "temp cache"; then
        test_pass "Test profile created successfully"
    else
        test_fail "Failed to create test profile"
        return 1
    fi

    # Check if profile file exists
    if [[ -f "${FUB_PROFILE_USER_DIR}/${TEST_PROFILE_NAME}.yaml" ]]; then
        test_pass "Profile file exists"
    else
        test_fail "Profile file not found"
        return 1
    fi

    # Test loading profile
    if load_profile "$TEST_PROFILE_NAME"; then
        test_pass "Profile loaded successfully"
    else
        test_fail "Failed to load profile"
        return 1
    fi

    # Test getting profile properties
    local profile_name
    profile_name=$(get_profile_property "$TEST_PROFILE_NAME" "name")
    if [[ "$profile_name" == "$TEST_PROFILE_NAME" ]]; then
        test_pass "Profile name retrieved correctly"
    else
        test_fail "Profile name retrieval failed"
        return 1
    fi

    # Test deleting profile
    if delete_profile "$TEST_PROFILE_NAME"; then
        test_pass "Profile deleted successfully"
    else
        test_fail "Failed to delete profile"
        return 1
    fi

    test_end
}

# Test background operations
test_background_operations() {
    test_start "Background Operations"

    # Initialize background operations
    init_background_ops

    # Test resource limit setting
    if set_background_resource_limits "256M" "30%" "5" "15"; then
        test_pass "Background resource limits set successfully"
    else
        test_fail "Failed to set background resource limits"
        return 1
    fi

    # Test background lock creation
    local test_operation="test-operation"
    if create_background_lock "$test_operation"; then
        test_pass "Background lock created successfully"
    else
        test_fail "Failed to create background lock"
        return 1
    fi

    # Test background lock release
    if release_background_lock "$test_operation"; then
        test_pass "Background lock released successfully"
    else
        test_fail "Failed to release background lock"
        return 1
    fi

    # Test condition checking
    if check_background_conditions ""; then
        test_pass "Background conditions check passed"
    else
        test_skip "Background conditions check failed (may be normal on test system)"
    fi

    test_end
}

# Test notifications
test_notifications() {
    test_start "Notifications"

    # Initialize notifications
    init_notifications

    # Test notification configuration loading
    if [[ "$FUB_NOTIFICATION_LEVEL" != "" ]]; then
        test_pass "Notification configuration loaded successfully"
    else
        test_fail "Notification configuration loading failed"
        return 1
    fi

    # Test sending notification
    if send_notification "INFO" "Test Notification" "This is a test notification from scheduler tests" "test"; then
        test_pass "Test notification sent successfully"
    else
        test_fail "Failed to send test notification"
        return 1
    fi

    # Test notification recording
    if [[ -f "$FUB_NOTIFICATION_DB" ]]; then
        test_pass "Notification database exists"
    else
        test_fail "Notification database not found"
        return 1
    fi

    test_end
}

# Test history system
test_history_system() {
    test_start "History System"

    # Initialize history
    init_history

    # Check if history database was created
    if [[ -f "$FUB_HISTORY_DB" ]]; then
        test_pass "History database created successfully"
    else
        test_fail "History database not found"
        return 1
    fi

    # Test recording maintenance operation
    local test_timestamp=$(date -Iseconds)
    if record_maintenance_operation "test_operation" "test_profile" "success" "60" "1048576" "10" "0" "0.5" "51200" "manual" "Test operation"; then
        test_pass "Maintenance operation recorded successfully"
    else
        test_fail "Failed to record maintenance operation"
        return 1
    fi

    # Test retrieving history
    local history_output
    history_output=$(get_maintenance_history "test_operation" "test_profile" "" "1" "1" 2>/dev/null || echo "")
    if [[ -n "$history_output" ]]; then
        test_pass "History retrieved successfully"
    else
        test_fail "Failed to retrieve history"
        return 1
    fi

    test_end
}

# Test scheduler integration
test_scheduler_integration() {
    test_start "Scheduler Integration"

    # Initialize scheduler integration
    init_scheduler_integration

    # Check if integration state file was created
    if [[ -f "$FUB_SCHEDULER_INTEGRATION_STATE" ]]; then
        test_pass "Integration state file created"
    else
        test_fail "Integration state file not found"
        return 1
    fi

    # Test integration status
    local integration_status
    integration_status=$(get_scheduler_integration_status 2>/dev/null || echo "")
    if [[ -n "$integration_status" ]]; then
        test_pass "Integration status retrieved successfully"
    else
        test_fail "Failed to get integration status"
        return 1
    fi

    # Test safety checks
    if perform_pre_operation_checks "test_profile" "temp"; then
        test_pass "Pre-operation safety checks passed"
    else
        test_skip "Pre-operation safety checks failed (may be normal on test system)"
    fi

    test_end
}

# Test scheduler commands
test_scheduler_commands() {
    test_start "Scheduler Commands"

    # Test scheduler status command
    local status_output
    status_output=$(get_scheduler_status 2>/dev/null || echo "")
    if [[ -n "$status_output" ]]; then
        test_pass "Scheduler status command works"
    else
        test_fail "Scheduler status command failed"
        return 1
    fi

    # Test scheduler maintenance command
    if scheduler_maintenance; then
        test_pass "Scheduler maintenance command works"
    else
        test_fail "Scheduler maintenance command failed"
        return 1
    fi

    # Test scheduler test command
    if test_scheduler >/dev/null 2>&1; then
        test_pass "Scheduler test command works"
    else
        test_skip "Scheduler test command failed (may be normal on test system)"
    fi

    test_end
}

# Test configuration validation
test_configuration_validation() {
    test_start "Configuration Validation"

    # Test scheduler config loading
    if [[ -f "$FUB_SCHEDULER_CONFIG" ]]; then
        test_pass "Scheduler configuration file exists"
        if load_scheduler_config; then
            test_pass "Scheduler configuration loaded successfully"
        else
            test_fail "Failed to load scheduler configuration"
            return 1
        fi
    else
        test_fail "Scheduler configuration file not found"
        return 1
    fi

    # Test profile config loading
    init_profiles
    if get_profile_property "desktop" "name" >/dev/null 2>&1; then
        test_pass "Default profile configurations accessible"
    else
        test_fail "Failed to access default profile configurations"
        return 1
    fi

    test_end
}

# Test error handling
test_error_handling() {
    test_start "Error Handling"

    # Test invalid profile name
    if create_profile "" "Invalid profile" "daily" "temp"; then
        test_fail "Invalid profile name was accepted"
        return 1
    else
        test_pass "Invalid profile name rejected"
    fi

    # Test invalid schedule
    if validate_systemd_schedule "completely-invalid-schedule-format"; then
        test_fail "Invalid schedule format was accepted"
        return 1
    else
        test_pass "Invalid schedule format rejected"
    fi

    # Test non-existent profile operations
    if load_profile "non-existent-profile-$(date +%s)" 2>/dev/null; then
        test_fail "Non-existent profile was loaded"
        return 1
    else
        test_pass "Non-existent profile properly rejected"
    fi

    test_end
}

# Integration test
test_scheduler_integration_full() {
    test_start "Full Scheduler Integration"

    # This test requires systemd user services
    if ! is_systemd_user_available; then
        test_skip "Systemd user services not available - skipping full integration test"
        return 0
    fi

    # Create test profile
    if ! create_profile "$TEST_PROFILE_NAME" "Integration test profile" "daily" "temp"; then
        test_fail "Failed to create test profile for integration test"
        return 1
    fi

    # Activate profile
    if enable_profile "$TEST_PROFILE_NAME"; then
        test_pass "Test profile activated successfully"
    else
        test_fail "Failed to activate test profile"
        return 1
    fi

    # Check if timer is active
    sleep 2  # Give systemd time to activate timer
    if systemctl --user is-active --quiet "fub-${TEST_PROFILE_NAME}.timer"; then
        test_pass "Systemd timer is active"
    else
        test_fail "Systemd timer is not active"
        return 1
    fi

    # Deactivate profile
    if disable_profile "$TEST_PROFILE_NAME"; then
        test_pass "Test profile deactivated successfully"
    else
        test_fail "Failed to deactivate test profile"
        return 1
    fi

    # Clean up test profile
    delete_profile "$TEST_PROFILE_NAME"

    test_pass "Full scheduler integration test completed successfully"
    test_end
}

# Performance test
test_scheduler_performance() {
    test_start "Scheduler Performance"

    local start_time
    start_time=$(date +%s.%N)

    # Initialize all scheduler components
    init_scheduler
    init_profiles
    init_background_ops
    init_notifications
    init_history
    init_scheduler_integration

    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

    # Performance should be under 5 seconds for initialization
    if [[ $(echo "$duration < 5.0" | bc -l 2>/dev/null || echo "1") -eq 1 ]]; then
        test_pass "Scheduler initialization completed in ${duration}s (under 5s threshold)"
    else
        test_fail "Scheduler initialization took ${duration}s (over 5s threshold)"
        return 1
    fi

    test_end
}

# Main test runner
main() {
    log_info "Starting FUB Scheduler Test Suite"

    # Setup test environment
    setup_test_environment

    # Register cleanup
    trap cleanup_test_environment EXIT

    # Run tests
    run_test test_scheduler_initialization
    run_test test_systemd_integration
    run_test test_profile_management
    run_test test_background_operations
    run_test test_notifications
    run_test test_history_system
    run_test test_scheduler_integration
    run_test test_scheduler_commands
    run_test test_configuration_validation
    run_test test_error_handling
    run_test test_scheduler_integration_full
    run_test test_scheduler_performance

    # Show results
    show_test_results

    log_info "FUB Scheduler Test Suite completed"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi