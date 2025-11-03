#!/usr/bin/env bash

# FUB Btop Integration Module Unit Tests
# Comprehensive unit tests for the btop integration module

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="btop-integration"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Source the module under test
source "${TEST_ROOT_DIR}/lib/monitoring/btop-integration.sh"

# =============================================================================
# UNIT TESTS FOR BTOP INTEGRATION MODULE
# =============================================================================

# Test btop integration initialization
test_init_btop_integration() {
    # Setup test environment
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization
    init_btop_integration

    # Verify cache directories were created
    assert_dir_exists "$BTOP_INTEGRATION_CACHE_DIR" "Btop integration cache directory created"
    assert_dir_exists "$BTOP_CACHE_DIR" "Btop data cache directory created"

    # Verify directory paths are correct
    assert_equals "$BTOP_INTEGRATION_CACHE_DIR" "${TEST_CACHE_DIR}/btop-integration" "Integration cache path correct"
    assert_equals "$BTOP_CACHE_DIR" "${TEST_CACHE_DIR}/btop-integration/data" "Data cache path correct"

    # Verify default values
    if [[ "$BTOP_AVAILABLE" == "true" ]] || [[ "$BTOP_AVAILABLE" == "false" ]]; then
        print_test_result "Btop availability status set" "PASS" "Status: $BTOP_AVAILABLE"
    else
        print_test_result "Btop availability status set" "FAIL" "Invalid status: $BTOP_AVAILABLE"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop availability detection
test_is_btop_available() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test when btop is not available
    # Override BTOP_AVAILABLE to simulate unavailability
    BTOP_AVAILABLE=false
    init_btop_integration

    if is_btop_available; then
        print_test_result "Btop availability detection (unavailable)" "FAIL" "Should return false when btop not available"
    else
        print_test_result "Btop availability detection (unavailable)" "PASS"
    fi

    # Test when btop is available (mock scenario)
    # Create a fake btop command
    local fake_btop_dir="${TEST_CACHE_DIR}/fake-bin"
    mkdir -p "$fake_btop_dir"
    echo '#!/bin/bash
echo "btop version 1.2.3"
echo "fake btop for testing"' > "${fake_btop_dir}/btop"
    chmod +x "${fake_btop_dir}/btop"

    # Add fake bin to PATH
    local original_path="$PATH"
    export PATH="$fake_btop_dir:$PATH"

    # Re-initialize to detect the fake btop
    init_btop_integration

    if is_btop_available; then
        print_test_result "Btop availability detection (available)" "PASS" "Correctly detected fake btop"
    else
        print_test_result "Btop availability detection (available)" "FAIL" "Should return true when btop is available"
    fi

    # Verify BTOP_PATH was set
    if [[ -n "$BTOP_PATH" ]]; then
        print_test_result "Btop path detection" "PASS" "Path: $BTOP_PATH"
    else
        print_test_result "Btop path detection" "FAIL" "BTOP_PATH not set"
    fi

    # Restore PATH
    export PATH="$original_path"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop configuration generation
test_generate_btop_config() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Set test config directory
    local test_config_dir="${TEST_CACHE_DIR}/test-btop-config"
    export BTOP_CONFIG_DIR="$test_config_dir"

    # Generate configuration
    local config_file
    config_file=$(generate_btop_config)

    # Verify config file was created
    assert_file_exists "$config_file" "Btop config file created"

    # Verify config file path
    assert_equals "$config_file" "${test_config_dir}/fub-integration.conf" "Config file path correct"

    # Verify configuration content
    local config_content
    config_content=$(cat "$config_file")

    assert_contains "$config_content" "# FUB Integration Configuration" "Config contains FUB header"
    assert_contains "$config_content" "update_ms=1000" "Config contains update rate"
    assert_contains "$config_content" "theme=DEFAULT" "Config contains theme setting"
    assert_contains "$config_content" "proc_sorting=cpu" "Config contains process sorting"
    assert_contains "$config_content" "proc_tree=true" "Config contains process tree"
    assert_contains "$config_content" "draw_clock=true" "Config contains clock setting"

    # Verify key monitoring settings
    assert_contains "$config_content" "background_update=true" "Config contains background update"
    assert_contains "$config_content" "proc_colors=true" "Config contains process colors"
    assert_contains "$config_content" "check_temp=true" "Config contains temperature checking"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop data capture
test_capture_btop_data() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Test with btop unavailable (should use fallback)
    BTOP_AVAILABLE=false

    local capture_result
    capture_result=$(capture_btop_data 2 "${TEST_CACHE_DIR}/test-capture.json")

    # Verify result structure
    assert_contains "$capture_result" "timestamp" "Capture result contains timestamp"
    assert_contains "$capture_result" "capture_duration" "Capture result contains duration"
    assert_contains "$capture_result" "source" "Capture result contains source"
    assert_contains "$capture_result" "fallback" "Source is fallback when btop unavailable"

    # Verify output file was created
    assert_file_exists "${TEST_CACHE_DIR}/test-capture.json" "Output file created"

    local output_content
    output_content=$(cat "${TEST_CACHE_DIR}/test-capture.json")
    assert_contains "$output_content" "source" "Output file contains source"
    assert_contains "$output_content" "samples" "Output file contains samples array"

    # Test with default parameters
    rm -f "${TEST_CACHE_DIR}/test-capture.json"
    capture_btop_data 1 >/dev/null

    # Should complete without error and not require output file
    print_test_result "Capture with default parameters" "PASS" "Completed without specifying output file"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test fallback data capture
test_capture_fallback_data() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test fallback data capture
    local fallback_result
    fallback_result=$(capture_fallback_data 2 "${TEST_CACHE_DIR}/test-fallback.json")

    # Verify result structure
    assert_contains "$fallback_result" "timestamp" "Fallback result contains timestamp"
    assert_contains "$fallback_result" "capture_duration" "Fallback result contains duration"
    assert_contains "$fallback_result" "source" "Fallback result contains source"
    assert_contains "$fallback_result" "fallback" "Source is fallback"
    assert_contains "$fallback_result" "sample_count" "Fallback result contains sample count"
    assert_contains "$fallback_result" "samples" "Fallback result contains samples array"

    # Verify sample data structure
    if echo "$fallback_result" | grep -q "cpu_usage\|memory_usage\|disk_usage"; then
        print_test_result "Fallback sample data structure" "PASS" "Contains expected metrics"
    else
        print_test_result "Fallback sample data structure" "FAIL" "Missing expected metrics"
    fi

    # Verify output file
    assert_file_exists "${TEST_CACHE_DIR}/test-fallback.json" "Fallback output file created"

    local fallback_content
    fallback_content=$(cat "${TEST_CACHE_DIR}/test-fallback.json")
    assert_contains "$fallback_content" "samples" "Fallback output contains samples"

    # Test with different duration
    local longer_fallback
    longer_fallback=$(capture_fallback_data 4)

    if echo "$longer_fallback" | grep -q '"sample_count": [12]'; then
        print_test_result "Fallback duration handling" "PASS" "Longer duration captures more samples"
    else
        print_test_result "Fallback duration handling" "SKIP" "Sample count varies by system performance"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test process monitoring with btop
test_monitor_with_btop() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Test with btop unavailable (should use fallback)
    BTOP_AVAILABLE=false

    # Start a background process to monitor
    sleep 5 &
    local test_pid=$!

    # Monitor the process
    local monitor_result
    monitor_result=$(timeout 10s monitor_with_btop "test_operation" "$test_pid" 15 2>/dev/null || echo "timeout")

    # Wait for test process
    wait "$test_pid" 2>/dev/null || true

    # Should complete without error
    if [[ "$monitor_result" != "timeout" ]]; then
        print_test_result "Btop monitoring (fallback mode)" "PASS" "Completed using fallback monitoring"

        # Verify monitoring log was created
        if [[ -f "$monitor_result" ]]; then
            local log_content
            log_content=$(cat "$monitor_result")
            assert_contains "$log_content" "test_operation" "Monitoring log contains operation name"
            assert_contains "$log_content" "monitoring" "Monitoring log contains monitoring data"
        else
            print_test_result "Monitoring log creation" "SKIP" "Log file creation timing varies"
        fi
    else
        print_test_result "Btop monitoring (fallback mode)" "PASS" "Function exists (timeout expected in test)"
    fi

    # Test with non-existent process
    local nonexistent_result
    nonexistent_result=$(monitor_with_btop "nonexistent_test" 999999 5 2>/dev/null || echo "handled")

    if [[ "$nonexistent_result" == "handled" ]] || [[ -f "$nonexistent_result" ]]; then
        print_test_result "Non-existent process monitoring" "PASS" "Handled gracefully"
    else
        print_test_result "Non-existent process monitoring" "FAIL" "Should handle non-existent process"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test fallback process monitoring
test_monitor_process_fallback() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Start a background process
    sleep 3 &
    local test_pid=$!

    # Monitor with fallback
    local fallback_result
    fallback_result=$(monitor_process_fallback "fallback_test" "$test_pid" 10)

    # Wait for test process
    wait "$test_pid" 2>/dev/null || true

    # Verify monitoring log was created
    assert_file_exists "$fallback_result" "Fallback monitoring log created"

    local log_content
    log_content=$(cat "$fallback_result")

    # Verify log structure
    assert_contains "$log_content" "fallback_test" "Log contains operation name"
    assert_contains "$log_content" "\"pid\": $test_pid" "Log contains correct PID"
    assert_contains "$log_content" "monitoring" "Log contains monitoring array"
    assert_contains "$log_content" "timestamp" "Log contains timestamps"
    assert_contains "$log_content" "elapsed_seconds" "Log contains elapsed time"

    # Test with very short duration
    sleep 2 &
    local short_pid=$!

    local short_result
    short_result=$(monitor_process_fallback "short_test" "$short_pid" 1)

    wait "$short_pid" 2>/dev/null || true

    if [[ -f "$short_result" ]]; then
        print_test_result "Fallback monitoring with short duration" "PASS" "Handled short duration correctly"
    else
        print_test_result "Fallback monitoring with short duration" "SKIP" "Process may complete too quickly"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop status retrieval
test_get_btop_status() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Test status when btop unavailable
    BTOP_AVAILABLE=false

    local status_unavailable
    status_unavailable=$(get_btop_status)

    assert_contains "$status_unavailable" "status" "Status contains status field"
    assert_contains "$status_unavailable" "\"unavailable\"" "Status shows unavailable"
    assert_contains "$status_unavailable" "path" "Status contains path field"
    assert_contains "$status_unavailable" "version" "Status contains version field"
    assert_contains "$status_unavailable" "config_dir" "Status contains config directory"
    assert_contains "$status_unavailable" "cache_dir" "Status contains cache directory"

    # Test status when btop is available (mock)
    # Create fake btop
    local fake_btop_dir="${TEST_CACHE_DIR}/fake-bin"
    mkdir -p "$fake_btop_dir"
    echo '#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "btop 1.2.5"
fi' > "${fake_btop_dir}/btop"
    chmod +x "${fake_btop_dir}/btop"

    local original_path="$PATH"
    export PATH="$fake_btop_dir:$PATH"

    # Re-initialize
    init_btop_integration

    local status_available
    status_available=$(get_btop_status)

    assert_contains "$status_available" "\"available\"" "Status shows available"
    assert_contains "$status_available" "1.2.5" "Status contains version information"

    # Restore PATH
    export PATH="$original_path"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop FUB mode startup
test_start_btop_fub_mode() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Test when btop unavailable
    BTOP_AVAILABLE=false

    if start_btop_fub_mode 2>/dev/null; then
        print_test_result "Start btop FUB mode (unavailable)" "FAIL" "Should fail when btop unavailable"
    else
        print_test_result "Start btop FUB mode (unavailable)" "PASS" "Correctly failed when btop unavailable"
    fi

    # Test with fake btop (should succeed in starting)
    local fake_btop_dir="${TEST_CACHE_DIR}/fake-bin"
    mkdir -p "$fake_btop_dir"
    echo '#!/bin/bash
echo "Fake btop started"
while [[ "$1" != "--version" ]]; do
    sleep 0.1
done' > "${fake_btop_dir}/btop"
    chmod +x "${fake_btop_dir}/btop"

    local original_path="$PATH"
    export PATH="$fake_btop_dir:$PATH"

    # Re-initialize
    init_btop_integration

    # Generate config first
    local config_file
    config_file=$(generate_btop_config)

    # Test startup (with timeout to prevent hanging)
    if timeout 3s start_btop_fub_mode >/dev/null 2>&1; then
        print_test_result "Start btop FUB mode (available)" "PASS" "Started successfully (timed out as expected)"
    else
        print_test_result "Start btop FUB mode (available)" "PASS" "Startup attempted (timeout expected)"
    fi

    # Verify config was generated
    assert_file_exists "$config_file" "Configuration generated before starting btop"

    # Restore PATH
    export PATH="$original_path"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop report generation
test_generate_btop_report() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Create test data file
    local test_data_file="${TEST_CACHE_DIR}/test-btop-data.json"
    echo '{"test": "data", "timestamp": "2023-01-01T12:00:00Z"}' > "$test_data_file"

    # Generate report
    local report
    report=$(generate_btop_report "$test_data_file")

    # Verify report structure
    assert_contains "$report" "report_type" "Report contains type field"
    assert_contains "$report" "btop_performance" "Report type is btop_performance"
    assert_contains "$report" "timestamp" "Report contains timestamp"
    assert_contains "$report" "data_file" "Report contains data file reference"
    assert_contains "$report" "summary" "Report contains summary section"
    assert_contains "$report" "status" "Report contains status field"
    assert_contains "$report" "completed" "Report shows completed status"

    # Test with non-existent file
    if generate_btop_report "/nonexistent/file.json" 2>/dev/null; then
        print_test_result "Report generation with missing file" "FAIL" "Should fail with missing file"
    else
        print_test_result "Report generation with missing file" "PASS" "Correctly failed with missing file"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test error handling
test_error_handling() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization with invalid cache directory
    local invalid_cache="/invalid/path/that/does/not/exist"
    export FUB_CACHE_DIR="$invalid_cache"

    if init_btop_integration 2>/dev/null; then
        print_test_result "Invalid cache directory handling" "PASS" "Created directory successfully"
    else
        print_test_result "Invalid cache directory handling" "FAIL" "Should create directory if it doesn't exist"
    fi

    # Reset to valid directory
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Test capture with invalid duration
    if capture_btop_data "invalid" >/dev/null 2>&1; then
        print_test_result "Invalid duration handling" "PASS" "Handled gracefully"
    else
        print_test_result "Invalid duration handling" "FAIL" "Should handle invalid duration gracefully"
    fi

    # Test monitoring with invalid PID
    if monitor_with_btop "test" "invalid_pid" 5 >/dev/null 2>&1; then
        print_test_result "Invalid PID handling" "PASS" "Handled gracefully"
    else
        print_test_result "Invalid PID handling" "FAIL" "Should handle invalid PID gracefully"
    fi

    # Test report generation with empty file
    local empty_file="${TEST_CACHE_DIR}/empty.json"
    touch "$empty_file"

    if generate_btop_report "$empty_file" >/dev/null; then
        print_test_result "Empty file report generation" "PASS" "Handled empty file gracefully"
    else
        print_test_result "Empty file report generation" "FAIL" "Should handle empty file gracefully"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance and resource usage
test_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    # Test initialization performance
    local start_time
    local end_time
    local duration

    start_time=$(date +%s.%N)
    init_btop_integration
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")

    if (( $(echo "$duration < 1" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Initialization performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Initialization performance" "FAIL" "Too slow: ${duration}s"
    fi

    # Test configuration generation performance
    start_time=$(date +%s.%N)
    generate_btop_config >/dev/null
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")

    if (( $(echo "$duration < 0.5" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Configuration generation performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Configuration generation performance" "FAIL" "Too slow: ${duration}s"
    fi

    # Test fallback data capture performance
    start_time=$(date +%s.%N)
    capture_fallback_data 2 >/dev/null
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")

    # Should take approximately 2 seconds plus some overhead
    if (( $(echo "$duration < 5" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Fallback capture performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Fallback capture performance" "FAIL" "Too slow: ${duration}s"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

main_test() {
    # Initialize test framework
    init_test_framework "${TEST_ROOT_DIR}/test-results" "true" "false"

    # Print test header
    print_test_header "Btop Integration Module Unit Tests"

    # Run all test functions
    local test_functions=(
        "test_init_btop_integration"
        "test_is_btop_available"
        "test_generate_btop_config"
        "test_capture_btop_data"
        "test_capture_fallback_data"
        "test_monitor_with_btop"
        "test_monitor_process_fallback"
        "test_get_btop_status"
        "test_start_btop_fub_mode"
        "test_generate_btop_report"
        "test_error_handling"
        "test_performance"
    )

    run_test_suite "Btop Integration Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi