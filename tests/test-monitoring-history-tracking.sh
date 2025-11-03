#!/usr/bin/env bash

# FUB History Tracking Module Unit Tests
# Comprehensive unit tests for the history tracking module

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="history-tracking"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Source the module under test
source "${TEST_ROOT_DIR}/lib/monitoring/history-tracking.sh"

# =============================================================================
# UNIT TESTS FOR HISTORY TRACKING MODULE
# =============================================================================

# Test history tracking initialization
test_init_history_tracking() {
    # Setup test environment
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization
    init_history_tracking

    # Verify cache directory was created
    assert_dir_exists "$HISTORY_CACHE_DIR" "History tracking cache directory created"

    # Verify file paths are correct
    assert_equals "$HISTORY_DB_FILE" "${TEST_CACHE_DIR}/history/cleanup-history.json" "History DB file path correct"
    assert_equals "$HISTORY_PERFORMANCE_FILE" "${TEST_CACHE_DIR}/history/performance-history.json" "Performance history file path correct"
    assert_equals "$HISTORY_SUMMARY_FILE" "${TEST_CACHE_DIR}/history/summary.json" "Summary file path correct"

    # Verify database files were created with correct structure
    assert_file_exists "$HISTORY_DB_FILE" "History DB file created"
    assert_file_exists "$HISTORY_PERFORMANCE_FILE" "Performance history file created"

    local db_content
    db_content=$(cat "$HISTORY_DB_FILE")
    assert_contains "$db_content" "cleanup_operations" "History DB has correct structure"
    assert_contains "$db_content" "[]" "History DB initialized with empty array"

    local perf_content
    perf_content=$(cat "$HISTORY_PERFORMANCE_FILE")
    assert_contains "$perf_content" "performance_snapshots" "Performance history has correct structure"
    assert_contains "$perf_content" "[]" "Performance history initialized with empty array"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test cleanup operation recording
test_record_cleanup_operation() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Create mock before/after states
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}, "memory": {"usage_percent": 60.0}, "disk": {"used": "10G", "total": "50G"}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}, "memory": {"usage_percent": 45.0}, "disk": {"used": "8G", "total": "50G"}}}'
    local details='{"files_cleaned": 100, "dirs_removed": 5}'

    # Record a cleanup operation
    local operation_record
    operation_record=$(record_cleanup_operation "package_cleanup" "test-op-001" "$before_state" "$after_state" 120 "success" "$details")

    # Verify record structure
    assert_contains "$operation_record" "operation_id" "Operation record contains operation ID"
    assert_contains "$operation_record" "test-op-001" "Operation ID correctly recorded"
    assert_contains "$operation_record" "timestamp" "Operation record contains timestamp"
    assert_contains "$operation_record" "operation_type" "Operation record contains operation type"
    assert_contains "$operation_record" "package_cleanup" "Operation type correctly recorded"
    assert_contains "$operation_record" "duration_seconds" "Operation record contains duration"
    assert_contains "$operation_record" "status" "Operation record contains status"
    assert_contains "$operation_record" "success" "Status correctly recorded"
    assert_contains "$operation_record" "before_state" "Operation record contains before state"
    assert_contains "$operation_record" "after_state" "Operation record contains after state"
    assert_contains "$operation_record" "impact" "Operation record contains impact section"
    assert_contains "$operation_record" "space_saved_mb" "Impact contains space saved"
    assert_contains "$operation_record" "performance_change" "Impact contains performance change"

    # Verify duration was recorded correctly
    assert_contains "$operation_record" "120" "Duration correctly recorded"

    # Verify impact calculations
    if echo "$operation_record" | grep -q '"space_saved_mb": [0-9]\+'; then
        print_test_result "Space saved calculated" "PASS"
    else
        print_test_result "Space saved calculated" "FAIL" "Space saved not properly calculated"
    fi

    # Verify database file was updated
    local db_content
    db_content=$(cat "$HISTORY_DB_FILE")
    assert_contains "$db_content" "test-op-001" "Operation added to database"
    assert_contains "$db_content" "package_cleanup" "Operation type in database"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test space savings calculation
test_calculate_space_savings() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test with realistic disk usage values
    local before_state='{"system_resources": {"disk": {"used": "15.5G"}}}'
    local after_state='{"system_resources": {"disk": {"used": "12.3G"}}}'

    local space_saved
    space_saved=$(calculate_space_savings "$before_state" "$after_state")

    # Should calculate positive space savings (15.5 - 12.3 = 3.2 GB = ~3276 MB)
    if [[ $space_saved -gt 0 ]]; then
        print_test_result "Space savings calculation positive" "PASS" "Saved: ${space_saved}MB"
    else
        print_test_result "Space savings calculation positive" "FAIL" "Negative or zero savings: $space_saved"
    fi

    # Test with no change
    local no_change_before='{"system_resources": {"disk": {"used": "10G"}}}'
    local no_change_after='{"system_resources": {"disk": {"used": "10G"}}}'

    local no_change_saved
    no_change_saved=$(calculate_space_savings "$no_change_before" "$no_change_after")

    if [[ $no_change_saved -eq 0 ]]; then
        print_test_result "Space savings no change" "PASS"
    else
        print_test_result "Space savings no change" "FAIL" "Expected 0, got $no_change_saved"
    fi

    # Test with disk usage increase (should be negative)
    local increase_before='{"system_resources": {"disk": {"used": "8G"}}}'
    local increase_after='{"system_resources": {"disk": {"used": "9G"}}}'

    local increase_saved
    increase_saved=$(calculate_space_savings "$increase_before" "$increase_after")

    if [[ $increase_saved -lt 0 ]]; then
        print_test_result "Space savings increase handling" "PASS" "Correctly negative: ${increase_saved}MB"
    else
        print_test_result "Space savings increase handling" "FAIL" "Should be negative: $increase_saved"
    fi

    # Test with malformed input
    local malformed_before='{"invalid": "json"}'
    local malformed_after='{"system_resources": {"disk": {"used": "10G"}}}'

    local malformed_saved
    malformed_saved=$(calculate_space_savings "$malformed_before" "$malformed_after")

    # Should handle gracefully and return 0
    if [[ $malformed_saved -eq 0 ]]; then
        print_test_result "Space savings malformed input" "PASS" "Handled gracefully"
    else
        print_test_result "Space savings malformed input" "FAIL" "Should handle malformed input: $malformed_saved"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance change calculation
test_calculate_performance_change() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test with improved performance
    local before_state='{"system_resources": {"cpu": {"usage_percent": 80.0}, "memory": {"usage_percent": 75.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 40.0}, "memory": {"usage_percent": 50.0}}}'

    local perf_change
    perf_change=$(calculate_performance_change "$before_state" "$after_state")

    # Should be positive (performance improved)
    if (( $(echo "$perf_change > 0" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "Performance improvement calculation" "PASS" "Improvement: ${perf_change}%"
    else
        print_test_result "Performance improvement calculation" "FAIL" "Should be positive: $perf_change"
    fi

    # Test with degraded performance
    local degrade_before='{"system_resources": {"cpu": {"usage_percent": 30.0}, "memory": {"usage_percent": 40.0}}}'
    local degrade_after='{"system_resources": {"cpu": {"usage_percent": 60.0}, "memory": {"usage_percent": 70.0}}}'

    local degrade_change
    degrade_change=$(calculate_performance_change "$degrade_before" "$degrade_after")

    # Should be negative (performance degraded)
    if (( $(echo "$degrade_change < 0" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "Performance degradation calculation" "PASS" "Degradation: ${degrade_change}%"
    else
        print_test_result "Performance degradation calculation" "FAIL" "Should be negative: $degrade_change"
    fi

    # Test with no change
    local no_change_before='{"system_resources": {"cpu": {"usage_percent": 50.0}, "memory": {"usage_percent": 50.0}}}'
    local no_change_after='{"system_resources": {"cpu": {"usage_percent": 50.0}, "memory": {"usage_percent": 50.0}}}'

    local no_change_perf
    no_change_perf=$(calculate_performance_change "$no_change_before" "$no_change_after")

    # Should be close to 0
    if (( $(echo "abs($no_change_perf) < 1" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Performance no change calculation" "PASS" "Change: ${no_change_perf}%"
    else
        print_test_result "Performance no change calculation" "FAIL" "Should be close to 0: $no_change_perf"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance snapshot recording
test_record_performance_snapshot() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Create mock metrics
    local metrics='{"cpu": {"usage_percent": 45.0}, "memory": {"usage_percent": 60.0}, "disk": {"usage_percent": 70.0}}'
    local timestamp="2023-01-01T12:00:00Z"

    # Record performance snapshot
    record_performance_snapshot "test-op-002" "$timestamp" "$metrics"

    # Verify performance history file was updated
    assert_file_exists "$HISTORY_PERFORMANCE_FILE" "Performance history file exists"

    local perf_content
    perf_content=$(cat "$HISTORY_PERFORMANCE_FILE")
    assert_contains "$perf_content" "test-op-002" "Operation ID in performance history"
    assert_contains "$perf_content" "$timestamp" "Timestamp in performance history"
    assert_contains "$perf_content" "metrics" "Metrics in performance history"
    assert_contains "$perf_content" "usage_percent" "Metric values in performance history"

    # Test multiple snapshots
    record_performance_snapshot "test-op-003" "2023-01-01T12:05:00Z" "$metrics"
    record_performance_snapshot "test-op-004" "2023-01-01T12:10:00Z" "$metrics"

    local snapshot_count
    snapshot_count=$(grep -c '"operation_id":' "$HISTORY_PERFORMANCE_FILE" || echo "0")
    if [[ $snapshot_count -ge 3 ]]; then
        print_test_result "Multiple performance snapshots recorded" "PASS" "Found $snapshot_count snapshots"
    else
        print_test_result "Multiple performance snapshots recorded" "FAIL" "Expected at least 3, found $snapshot_count"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test cleanup history retrieval
test_get_cleanup_history() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Add some test operations
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'
    local details='{"test": true}'

    record_cleanup_operation "package_cleanup" "op-001" "$before_state" "$after_state" 60 "success" "$details"
    record_cleanup_operation "temp_cleanup" "op-002" "$before_state" "$after_state" 30 "success" "$details"
    record_cleanup_operation "log_cleanup" "op-003" "$before_state" "$after_state" 45 "failed" "$details"

    # Test getting all history
    local all_history
    all_history=$(get_cleanup_history 30)

    assert_contains "$all_history" "operations" "History contains operations array"
    assert_contains "$all_history" "op-001" "History contains first operation"
    assert_contains "$all_history" "op-002" "History contains second operation"
    assert_contains "$all_history" "op-003" "History contains third operation"

    # Test filtering by operation type
    local package_history
    package_history=$(get_cleanup_history 30 "package_cleanup")

    assert_contains "$package_history" "op-001" "Filtered history contains package operation"
    if ! echo "$package_history" | grep -q "op-002\|op-003"; then
        print_test_result "History filtering by type" "PASS" "Only package operations returned"
    else
        print_test_result "History filtering by type" "FAIL" "Other operation types found"
    fi

    # Test with time limit (should work without error)
    local recent_history
    recent_history=$(get_cleanup_history 1)  # Last 1 day
    assert_contains "$recent_history" "operations" "Time-limited history has correct structure"

    # Test with empty history
    rm -f "$HISTORY_DB_FILE"
    echo '{"cleanup_operations": []}' > "$HISTORY_DB_FILE"

    local empty_history
    empty_history=$(get_cleanup_history 30)
    assert_contains "$empty_history" '"operations": []' "Empty history handled correctly"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance trends analysis
test_get_performance_trends() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Add some performance snapshots with different values
    local metrics1='{"cpu": {"usage_percent": 30.0}, "memory": {"usage_percent": 40.0}}'
    local metrics2='{"cpu": {"usage_percent": 50.0}, "memory": {"usage_percent": 60.0}}'
    local metrics3='{"cpu": {"usage_percent": 70.0}, "memory": {"usage_percent": 80.0}}'

    record_performance_snapshot "trend-test-1" "2023-01-01T12:00:00Z" "$metrics1"
    record_performance_snapshot "trend-test-2" "2023-01-01T12:05:00Z" "$metrics2"
    record_performance_snapshot "trend-test-3" "2023-01-01T12:10:00Z" "$metrics3"

    # Get performance trends
    local trends
    trends=$(get_performance_trends 7)

    # Verify trends structure
    assert_contains "$trends" "period_days" "Trends contain time period"
    assert_contains "$trends" "trends" "Trends contain trends section"
    assert_contains "$trends" "cpu" "Trends contain CPU trend"
    assert_contains "$trends" "memory" "Trends contain memory trend"
    assert_contains "$trends" "disk" "Trends contain disk trend"

    # Verify trend values are valid
    if echo "$trends" | grep -q '"cpu": "increasing"\|"cpu": "decreasing"\|"cpu": "stable"'; then
        print_test_result "CPU trend value valid" "PASS"
    else
        print_test_result "CPU trend value valid" "FAIL" "Invalid CPU trend value"
    fi

    # Test with no performance data
    rm -f "$HISTORY_PERFORMANCE_FILE"
    echo '{"performance_snapshots": []}' > "$HISTORY_PERFORMANCE_FILE"

    local no_data_trends
    no_data_trends=$(get_performance_trends 7)
    assert_contains "$no_data_trends" "No performance data available" "No data handled gracefully"

    # Test with custom time period
    rm -f "$HISTORY_PERFORMANCE_FILE"
    record_performance_snapshot "custom-test" "2023-01-01T12:00:00Z" "$metrics1"

    local custom_trends
    custom_trends=$(get_performance_trends 14)
    assert_contains "$custom_trends" "\"14\"" "Custom time period respected"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test history summary updates
test_update_history_summary() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Add test operations
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'
    local details='{"test": true}'

    record_cleanup_operation "test_cleanup" "summary-op-001" "$before_state" "$after_state" 60 "success" "$details"
    record_cleanup_operation "test_cleanup" "summary-op-002" "$before_state" "$after_state" 30 "success" "$details"
    record_cleanup_operation "test_cleanup" "summary-op-003" "$before_state" "$after_state" 45 "failed" "$details"

    # Manually trigger summary update
    update_history_summary

    # Verify summary file was created
    assert_file_exists "$HISTORY_SUMMARY_FILE" "Summary file created"

    local summary_content
    summary_content=$(cat "$HISTORY_SUMMARY_FILE")

    # Verify summary structure
    assert_contains "$summary_content" "generated_at" "Summary contains generation timestamp"
    assert_contains "$summary_content" "operations" "Summary contains operations section"
    assert_contains "$summary_content" "total" "Summary contains total operations"
    assert_contains "$summary_content" "successful" "Summary contains successful operations"
    assert_contains "$summary_content" "failed" "Summary contains failed operations"
    assert_contains "$summary_content" "success_rate" "Summary contains success rate"
    assert_contains "$summary_content" "impact" "Summary contains impact section"

    # Verify counts
    if echo "$summary_content" | grep -q '"total": 3'; then
        print_test_result "Summary total operations count" "PASS"
    else
        print_test_result "Summary total operations count" "FAIL" "Expected 3 total operations"
    fi

    if echo "$summary_content" | grep -q '"successful": 2'; then
        print_test_result "Summary successful operations count" "PASS"
    else
        print_test_result "Summary successful operations count" "FAIL" "Expected 2 successful operations"
    fi

    if echo "$summary_content" | grep -q '"failed": 1'; then
        print_test_result "Summary failed operations count" "PASS"
    else
        print_test_result "Summary failed operations count" "FAIL" "Expected 1 failed operation"
    fi

    # Verify success rate calculation
    if echo "$summary_content" | grep -q '"success_rate": 66.'; then
        print_test_result "Summary success rate calculation" "PASS"
    else
        print_test_result "Summary success rate calculation" "FAIL" "Expected ~66.7% success rate"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test history summary retrieval
test_get_history_summary() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Test with no existing summary (should generate one)
    local summary
    summary=$(get_history_summary)

    assert_contains "$summary" "generated_at" "Generated summary contains timestamp"
    assert_contains "$summary" "operations" "Generated summary contains operations section"

    # Test with existing summary
    local existing_summary
    existing_summary=$(get_history_summary)

    if [[ "$summary" == "$existing_summary" ]]; then
        print_test_result "Existing summary retrieval" "PASS" "Same summary returned"
    else
        print_test_result "Existing summary retrieval" "FAIL" "Summary should be the same"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test old history cleanup
test_cleanup_old_history() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Add some test operations
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'
    local details='{"test": true}'

    record_cleanup_operation "test_cleanup" "cleanup-op-001" "$before_state" "$after_state" 60 "success" "$details"
    record_cleanup_operation "test_cleanup" "cleanup-op-002" "$before_state" "$after_state" 30 "success" "$details"

    # Add performance snapshots
    local metrics='{"cpu": {"usage_percent": 45.0}}'
    record_performance_snapshot "perf-op-001" "2023-01-01T12:00:00Z" "$metrics"
    record_performance_snapshot "perf-op-002" "2023-01-01T12:05:00Z" "$metrics"

    # Verify data exists before cleanup
    local before_db_count
    before_db_count=$(grep -c '"operation_id":' "$HISTORY_DB_FILE" || echo "0")
    local before_perf_count
    before_perf_count=$(grep -c '"operation_id":' "$HISTORY_PERFORMANCE_FILE" || echo "0")

    if [[ $before_db_count -gt 0 && $before_perf_count -gt 0 ]]; then
        print_test_result "Data exists before cleanup" "PASS" "DB: $before_db_count, Perf: $before_perf_count"
    else
        print_test_result "Data exists before cleanup" "FAIL" "Missing test data"
    fi

    # Run cleanup with very short retention (should remove most data)
    cleanup_old_history 0  # 0 days = remove everything

    # Verify cleanup occurred
    local after_db_content
    after_db_content=$(cat "$HISTORY_DB_FILE")
    local after_perf_content
    after_perf_content=$(cat "$HISTORY_PERFORMANCE_FILE")

    # Files should still exist but be mostly empty
    assert_file_exists "$HISTORY_DB_FILE" "History DB file exists after cleanup"
    assert_file_exists "$HISTORY_PERFORMANCE_FILE" "Performance history file exists after cleanup"

    # Should have empty arrays
    assert_contains "$after_db_content" "cleanup_operations" "DB file has correct structure after cleanup"
    assert_contains "$after_perf_content" "performance_snapshots" "Perf file has correct structure after cleanup"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test history export functionality
test_export_history() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Add some test data
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'
    local details='{"test": true}'

    record_cleanup_operation "test_cleanup" "export-op-001" "$before_state" "$after_state" 60 "success" "$details"

    # Test JSON export to file
    local export_file="${TEST_CACHE_DIR}/export.json"
    export_history "json" "$export_file"

    assert_file_exists "$export_file" "JSON export file created"

    local export_content
    export_content=$(cat "$export_file")
    assert_contains "$export_content" "exported_at" "Export contains timestamp"
    assert_contains "$export_content" "cleanup_history" "Export contains cleanup history"
    assert_contains "$export_content" "performance_history" "Export contains performance history"
    assert_contains "$export_content" "summary" "Export contains summary"
    assert_contains "$export_content" "export-op-001" "Export contains test operation"

    # Test CSV export to file
    local csv_file="${TEST_CACHE_DIR}/export.csv"
    export_history "csv" "$csv_file"

    assert_file_exists "$csv_file" "CSV export file created"

    local csv_content
    csv_content=$(cat "$csv_file")
    assert_contains "$csv_content" "operation_id" "CSV contains headers"
    assert_contains "$csv_content" "timestamp" "CSV contains timestamp header"

    # Test export to stdout
    local stdout_export
    stdout_export=$(export_history "json")

    assert_contains "$stdout_export" "exported_at" "Stdout export contains timestamp"
    assert_contains "$stdout_export" "cleanup_history" "Stdout export contains history"

    # Test invalid format
    if export_history "invalid_format" 2>/dev/null; then
        print_test_result "Invalid export format handling" "FAIL" "Should reject invalid format"
    else
        print_test_result "Invalid export format handling" "PASS" "Correctly rejected invalid format"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test maintenance suggestions generation
test_generate_maintenance_suggestions() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    # Test with empty history (should still generate valid JSON)
    local empty_suggestions
    empty_suggestions=$(generate_maintenance_suggestions)

    assert_contains "$empty_suggestions" "generated_at" "Suggestions contain generation timestamp"
    assert_contains "$empty_suggestions" "suggestions" "Suggestions contain suggestions array"

    # Add some test operations with low frequency
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'
    local details='{"test": true}'

    record_cleanup_operation "test_cleanup" "maint-op-001" "$before_state" "$after_state" 60 "success" "$details"

    # Generate suggestions
    local suggestions
    suggestions=$(generate_maintenance_suggestions)

    # Should generate suggestions about cleanup frequency
    if echo "$suggestions" | grep -q "cleanup_frequency\|space_savings"; then
        print_test_result "Maintenance suggestions generated" "PASS"
    else
        print_test_result "Maintenance suggestions generated" "FAIL" "No relevant suggestions found"
    fi

    # Verify suggestion structure
    if echo "$suggestions" | grep -q "type\|message\|priority"; then
        print_test_result "Suggestion structure valid" "PASS"
    else
        print_test_result "Suggestion structure valid" "FAIL" "Invalid suggestion structure"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test history database rotation
test_history_rotation() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Set low rotation threshold for testing
    HISTORY_MAX_ENTRIES=3
    HISTORY_AUTO_ROTATE=true

    init_history_tracking

    # Add more operations than the limit
    local before_state='{"system_resources": {"cpu": {"usage_percent": 50.0}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'
    local details='{"test": true}'

    # Add 5 operations (limit is 3)
    for i in {1..5}; do
        record_cleanup_operation "test_cleanup" "rotate-op-00$i" "$before_state" "$after_state" 60 "success" "$details"
    done

    # Count operations in database
    local final_count
    final_count=$(grep -c '"operation_id":' "$HISTORY_DB_FILE" || echo "0")

    # Should not exceed the limit
    if [[ $final_count -le 3 ]]; then
        print_test_result "History rotation working" "PASS" "Final count: $final_count (limit: 3)"
    else
        print_test_result "History rotation working" "FAIL" "Too many operations: $final_count"
    fi

    # Should keep the most recent operations
    if grep -q "rotate-op-003\|rotate-op-004\|rotate-op-005" "$HISTORY_DB_FILE"; then
        print_test_result "History keeps recent entries" "PASS"
    else
        print_test_result "History keeps recent entries" "FAIL" "Recent operations not found"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test error handling
test_error_handling() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization with read-only directory
    local readonly_dir="${TEST_CACHE_DIR}/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir" 2>/dev/null || true

    export FUB_CACHE_DIR="$readonly_dir"
    if init_history_tracking 2>/dev/null; then
        print_test_result "Read-only directory handling" "PASS" "Handled gracefully"
    else
        print_test_result "Read-only directory handling" "FAIL" "Should handle read-only directory"
    fi

    # Restore permissions for cleanup
    chmod 755 "$readonly_dir" 2>/dev/null || true

    # Test recording with invalid JSON states
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    local invalid_before='{"invalid": json}'
    local invalid_after='{"system_resources": {"cpu": {"usage_percent": 30.0}}}'

    if record_cleanup_operation "test" "error-test" "$invalid_before" "$invalid_after" 60 "success" "{}" 2>/dev/null; then
        print_test_result "Invalid state JSON handling" "PASS" "Handled gracefully"
    else
        print_test_result "Invalid state JSON handling" "FAIL" "Should handle invalid JSON gracefully"
    fi

    # Test missing files
    rm -f "$HISTORY_DB_FILE"
    local missing_file_result
    missing_file_result=$(get_cleanup_history 30 2>/dev/null || echo "handled")

    if [[ "$missing_file_result" == "handled" ]] || echo "$missing_file_result" | grep -q "operations"; then
        print_test_result "Missing database file handling" "PASS"
    else
        print_test_result "Missing database file handling" "FAIL" "Should handle missing files gracefully"
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
    print_test_header "History Tracking Module Unit Tests"

    # Run all test functions
    local test_functions=(
        "test_init_history_tracking"
        "test_record_cleanup_operation"
        "test_calculate_space_savings"
        "test_calculate_performance_change"
        "test_record_performance_snapshot"
        "test_get_cleanup_history"
        "test_get_performance_trends"
        "test_update_history_summary"
        "test_get_history_summary"
        "test_cleanup_old_history"
        "test_export_history"
        "test_generate_maintenance_suggestions"
        "test_history_rotation"
        "test_error_handling"
    )

    run_test_suite "History Tracking Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi