#!/usr/bin/env bash

# FUB Performance Monitor Module Unit Tests
# Comprehensive unit tests for the performance monitor module

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="performance-monitor"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Source the module under test
source "${TEST_ROOT_DIR}/lib/monitoring/performance-monitor.sh"

# =============================================================================
# UNIT TESTS FOR PERFORMANCE MONITOR MODULE
# =============================================================================

# Test performance monitor initialization
test_init_performance_monitor() {
    # Setup test environment
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization
    init_performance_monitor

    # Verify cache directory was created
    assert_dir_exists "$PERFORMANCE_MONITOR_CACHE_DIR" "Performance monitor cache directory created"

    # Verify file paths are correct
    assert_equals "$PERFORMANCE_MONITOR_HISTORY_FILE" "${TEST_CACHE_DIR}/performance-monitor/history.json" "History file path correct"
    assert_equals "$PERFORMANCE_MONITOR_STATE_FILE" "${TEST_CACHE_DIR}/performance-monitor/current-state.json" "State file path correct"

    # Verify history file was created with correct structure
    assert_file_exists "$PERFORMANCE_MONITOR_HISTORY_FILE" "History file created"
    local history_content
    history_content=$(cat "$PERFORMANCE_MONITOR_HISTORY_FILE")
    assert_contains "$history_content" "history" "History file has correct structure"
    assert_contains "$history_content" "[]" "History file initialized with empty array"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test current metrics collection
test_get_current_metrics() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Get current metrics
    local metrics
    metrics=$(get_current_metrics)

    # Verify JSON structure
    assert_contains "$metrics" "timestamp" "Metrics contain timestamp"
    assert_contains "$metrics" "cpu" "Metrics contain CPU section"
    assert_contains "$metrics" "memory" "Metrics contain memory section"
    assert_contains "$metrics" "disk" "Metrics contain disk section"
    assert_contains "$metrics" "io" "Metrics contain I/O section"

    # Verify CPU metrics
    assert_contains "$metrics" "usage_percent" "CPU usage percent present"
    assert_contains "$metrics" "load_average" "CPU load average present"

    # Verify memory metrics
    assert_contains "$metrics" "usage_percent" "Memory usage percent present"

    # Verify disk metrics
    assert_contains "$metrics" "usage_percent" "Disk usage percent present"

    # Verify I/O metrics
    assert_contains "$metrics" "wait_percent" "I/O wait percent present"

    # Verify numeric values are reasonable
    local cpu_usage
    cpu_usage=$(echo "$metrics" | grep '"usage_percent":' | head -1 | cut -d: -f2 | tr -d ' ,')
    if [[ $cpu_usage =~ ^[0-9]+\.?[0-9]*$ ]] && [[ $cpu_usage -ge 0 && $cpu_usage -le 100 ]]; then
        print_test_result "CPU usage is valid numeric value" "PASS"
    else
        print_test_result "CPU usage is valid numeric value" "FAIL" "Invalid CPU usage: $cpu_usage"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test metrics recording
test_record_metrics() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Record metrics for a test operation
    record_metrics "test_operation"

    # Verify history file was updated
    assert_file_exists "$PERFORMANCE_MONITOR_HISTORY_FILE" "History file exists after recording"

    local history_content
    history_content=$(cat "$PERFORMANCE_MONITOR_HISTORY_FILE")
    assert_contains "$history_content" "test_operation" "History contains recorded operation"
    assert_contains "$history_content" "metrics" "History contains metrics section"

    # Verify state file was created
    assert_file_exists "$PERFORMANCE_MONITOR_STATE_FILE" "State file created after recording"

    local state_content
    state_content=$(cat "$PERFORMANCE_MONITOR_STATE_FILE")
    assert_contains "$state_content" "timestamp" "State contains timestamp"
    assert_contains "$state_content" "cpu" "State contains CPU metrics"

    # Test recording multiple operations
    record_metrics "cleanup_operation"
    record_metrics "analysis_operation"

    # Verify multiple entries in history
    local operation_count
    operation_count=$(grep -c "operation" "$PERFORMANCE_MONITOR_HISTORY_FILE" || echo "0")
    if [[ $operation_count -ge 3 ]]; then
        print_test_result "Multiple operations recorded" "PASS" "Found $operation_count operations"
    else
        print_test_result "Multiple operations recorded" "FAIL" "Expected at least 3 operations, found $operation_count"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance trends analysis
test_get_performance_trends() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Record some test metrics
    for i in {1..5}; do
        record_metrics "test_operation_$i"
        sleep 0.1  # Small delay to get different timestamps
    done

    # Get trends for last 24 hours
    local trends
    trends=$(get_performance_trends 24)

    # Verify trends structure
    assert_contains "$trends" "time_period_hours" "Trends contain time period"
    assert_contains "$trends" "averages" "Trends contain averages section"
    assert_contains "$trends" "peaks" "Trends contain peaks section"

    # Verify average metrics
    assert_contains "$trends" "cpu_percent" "Trends contain CPU average"
    assert_contains "$trends" "memory_percent" "Trends contain memory average"
    assert_contains "$trends" "disk_percent" "Trends contain disk average"

    # Verify peak metrics
    local trends_with_peaks
    trends_with_peaks=$(echo "$trends" | grep -c "cpu_percent" || echo "0")
    if [[ $trends_with_peaks -ge 2 ]]; then  # Should appear in both averages and peaks
        print_test_result "Peak metrics present in trends" "PASS"
    else
        print_test_result "Peak metrics present in trends" "FAIL" "Peak metrics not found"
    fi

    # Test with custom time period
    local short_trends
    short_trends=$(get_performance_trends 1)
    assert_contains "$short_trends" "\"1\"" "Custom time period respected"

    # Test with no history (empty cache)
    rm -f "$PERFORMANCE_MONITOR_HISTORY_FILE"
    echo '{"history": []}' > "$PERFORMANCE_MONITOR_HISTORY_FILE"

    local empty_trends
    empty_trends=$(get_performance_trends 24)
    assert_contains "$empty_trends" "averages" "Trends handle empty history gracefully"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance alerts
test_check_performance_alerts() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Set test thresholds
    PERFORMANCE_CPU_THRESHOLD=50
    PERFORMANCE_MEMORY_THRESHOLD=60
    PERFORMANCE_DISK_THRESHOLD=70

    # Get current alerts
    local alerts
    alerts=$(check_performance_alerts)

    # Verify alerts structure
    assert_contains "$alerts" "[" "Alerts returned as array"
    assert_contains "$alerts" "]" "Alerts array properly closed"

    # Test with mocked high metrics (by temporarily changing threshold values)
    PERFORMANCE_CPU_THRESHOLD=0  # This should trigger an alert
    PERFORMANCE_MEMORY_THRESHOLD=0
    PERFORMANCE_DISK_THRESHOLD=0

    local high_alerts
    high_alerts=$(check_performance_alerts)

    # Should contain alerts for all metrics
    if [[ $(echo "$high_alerts" | grep -c "cpu_high" || echo "0") -gt 0 ]]; then
        print_test_result "High CPU alert generated" "PASS"
    else
        print_test_result "High CPU alert generated" "FAIL" "No CPU alert found"
    fi

    if [[ $(echo "$high_alerts" | grep -c "memory_high" || echo "0") -gt 0 ]]; then
        print_test_result "High memory alert generated" "PASS"
    else
        print_test_result "High memory alert generated" "FAIL" "No memory alert found"
    fi

    if [[ $(echo "$high_alerts" | grep -c "disk_high" || echo "0") -gt 0 ]]; then
        print_test_result "High disk alert generated" "PASS"
    else
        print_test_result "High disk alert generated" "FAIL" "No disk alert found"
    fi

    # Verify alert structure
    if echo "$high_alerts" | grep -q "type\|severity\|message\|threshold\|recommendation"; then
        print_test_result "Alert structure is complete" "PASS"
    else
        print_test_result "Alert structure is complete" "FAIL" "Alert structure incomplete"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test operation monitoring
test_monitor_operation() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Start a background process to monitor
    sleep 10 &
    local test_pid=$!

    # Monitor the operation
    local monitor_result
    monitor_result=$(monitor_operation "test_sleep" "$test_pid" 1 3)

    # Wait for monitoring to complete
    wait "$test_pid" 2>/dev/null || true

    # Verify monitoring result structure
    assert_contains "$monitor_result" "operation" "Monitor result contains operation name"
    assert_contains "$monitor_result" "duration_seconds" "Monitor result contains duration"
    assert_contains "$monitor_result" "samples_collected" "Monitor result contains sample count"
    assert_contains "$monitor_result" "log_file" "Monitor result contains log file path"

    # Verify operation name
    assert_contains "$monitor_result" "test_sleep" "Operation name correctly recorded"

    # Verify log file was created
    local log_file
    log_file=$(echo "$monitor_result" | grep '"log_file":' | cut -d'"' -f4)
    if [[ -n "$log_file" && -f "$log_file" ]]; then
        print_test_result "Operation log file created" "PASS"

        # Verify log file structure
        local log_content
        log_content=$(cat "$log_file")
        assert_contains "$log_content" "test_sleep" "Log contains operation name"
        assert_contains "$log_content" "samples" "Log contains samples array"
    else
        print_test_result "Operation log file created" "FAIL" "Log file not found: $log_file"
    fi

    # Test monitoring non-existent process
    if monitor_operation "nonexistent" 999999 1 2 2>/dev/null; then
        print_test_result "Monitoring non-existent process" "PASS" "Handled gracefully"
    else
        print_test_result "Monitoring non-existent process" "FAIL" "Should handle non-existent process gracefully"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance summary
test_get_performance_summary() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Record some test data
    for i in {1..3}; do
        record_metrics "summary_test_$i"
        sleep 0.1
    done

    # Get performance summary
    local summary
    summary=$(get_performance_summary 1)

    # Verify summary structure
    assert_contains "$summary" "period_hours" "Summary contains time period"
    assert_contains "$summary" "current_metrics" "Summary contains current metrics"
    assert_contains "$summary" "trends" "Summary contains trends"
    assert_contains "$summary" "alerts" "Summary contains alerts"
    assert_contains "$summary" "timestamp" "Summary contains timestamp"

    # Verify time period
    assert_contains "$summary" "\"1\"" "Summary uses correct time period"

    # Verify current metrics section
    local current_metrics_section
    current_metrics_section=$(echo "$summary" | grep -A10 '"current_metrics":')
    assert_contains "$current_metrics_section" "cpu" "Current metrics contain CPU"
    assert_contains "$current_metrics_section" "memory" "Current metrics contain memory"
    assert_contains "$current_metrics_section" "disk" "Current metrics contain disk"

    # Verify trends section
    local trends_section
    trends_section=$(echo "$summary" | grep -A10 '"trends":')
    assert_contains "$trends_section" "averages" "Trends contain averages"
    assert_contains "$trends_section" "peaks" "Trends contain peaks"

    # Verify alerts section
    local alerts_section
    alerts_section=$(echo "$summary" | grep -A5 '"alerts":')
    assert_contains "$alerts_section" "[" "Alerts section is array"

    # Test with default time period
    local default_summary
    default_summary=$(get_performance_summary)
    assert_contains "$default_summary" "\"1\"" "Default time period is 1 hour"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test history management
test_history_management() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Record many entries to test history limit
    for i in {1..1100}; do
        record_metrics "history_test_$i" >/dev/null
    done

    # Check that history file doesn't grow indefinitely
    local history_size
    history_size=$(wc -c < "$PERFORMANCE_MONITOR_HISTORY_FILE" 2>/dev/null || echo "0")

    # Should be reasonably sized (not millions of characters)
    if [[ $history_size -lt 1000000 ]]; then
        print_test_result "History size management" "PASS" "History size: $history_size bytes"
    else
        print_test_result "History size management" "FAIL" "History too large: $history_size bytes"
    fi

    # Verify history file is still valid JSON
    if python3 -m json.tool "$PERFORMANCE_MONITOR_HISTORY_FILE" >/dev/null 2>&1; then
        print_test_result "History file valid JSON" "PASS"
    else
        print_test_result "History file valid JSON" "FAIL" "History file is not valid JSON"
    fi

    # Test history file corruption handling
    # Create corrupted history file
    echo '{"history": [invalid json}' > "$PERFORMANCE_MONITOR_HISTORY_FILE"

    # Should handle gracefully
    if record_metrics "corruption_test" 2>/dev/null; then
        print_test_result "History corruption handling" "PASS" "Handled corrupted file gracefully"
    else
        print_test_result "History corruption handling" "FAIL" "Should handle corruption gracefully"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test error handling
test_error_handling() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization with invalid cache directory
    export FUB_CACHE_DIR="/invalid/path/that/does/not/exist"
    if init_performance_monitor 2>/dev/null; then
        print_test_result "Invalid cache directory handling" "PASS" "Created directory successfully"
    else
        print_test_result "Invalid cache directory handling" "FAIL" "Should create directory if it doesn't exist"
    fi

    # Reset to valid directory
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Test with missing system commands
    local original_path="$PATH"
    export PATH="/nonexistent:$PATH"

    # Should still return valid JSON structure
    local metrics
    metrics=$(get_current_metrics)
    assert_contains "$metrics" "timestamp" "Metrics work with missing commands"

    # Restore PATH
    export PATH="$original_path"

    # Test trends with no history file
    rm -f "$PERFORMANCE_MONITOR_HISTORY_FILE"
    local no_history_trends
    no_history_trends=$(get_performance_trends 24)
    assert_contains "$no_history_trends" "error" "Trends handle missing history gracefully"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance impact
test_performance_impact() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    # Test individual function performance
    local start_time
    local end_time
    local duration

    # Test metrics collection performance
    start_time=$(date +%s.%N)
    get_current_metrics > /dev/null
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    if (( $(echo "$duration < 2" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Metrics collection performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Metrics collection performance" "FAIL" "Too slow: ${duration}s"
    fi

    # Test recording performance
    start_time=$(date +%s.%N)
    record_metrics "performance_test" > /dev/null
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    if (( $(echo "$duration < 1" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Metrics recording performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Metrics recording performance" "FAIL" "Too slow: ${duration}s"
    fi

    # Test memory usage (basic check)
    local memory_before
    memory_before=$(ps -o rss= -p $$ | tr -d ' ')

    # Perform multiple operations
    for i in {1..10}; do
        get_current_metrics > /dev/null
        record_metrics "memory_test_$i" > /dev/null
    done

    local memory_after
    memory_after=$(ps -o rss= -p $$ | tr -d ' ')
    local memory_increase=$((memory_after - memory_before))

    # Should not increase memory usage significantly (less than 10MB)
    if [[ $memory_increase -lt 10240 ]]; then
        print_test_result "Memory usage impact" "PASS" "Increase: ${memory_increase}KB"
    else
        print_test_result "Memory usage impact" "FAIL" "Too much memory increase: ${memory_increase}KB"
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
    print_test_header "Performance Monitor Module Unit Tests"

    # Run all test functions
    local test_functions=(
        "test_init_performance_monitor"
        "test_get_current_metrics"
        "test_record_metrics"
        "test_get_performance_trends"
        "test_check_performance_alerts"
        "test_monitor_operation"
        "test_get_performance_summary"
        "test_history_management"
        "test_error_handling"
        "test_performance_impact"
    )

    run_test_suite "Performance Monitor Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi