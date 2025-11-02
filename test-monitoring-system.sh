#!/usr/bin/env bash

# Test Script for FUB Monitoring System
# Validates all monitoring components and integration

set -euo pipefail

# Source the monitoring integration
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${FUB_SCRIPT_DIR}/lib/monitoring/monitoring-integration.sh"

# Test configuration
TEST_LOG_FILE="${FUB_SCRIPT_DIR}/test-monitoring.log"
TEST_RESULTS_FILE="${FUB_SCRIPT_DIR}/test-monitoring-results.json"

# Initialize test environment
init_test_environment() {
    echo "FUB Monitoring System Test Suite" > "$TEST_LOG_FILE"
    echo "Started at: $(date)" >> "$TEST_LOG_FILE"
    echo >> "$TEST_LOG_FILE"

    # Ensure monitoring is enabled for tests
    export MONITORING_ENABLED=true
    export FUB_LOG_LEVEL=DEBUG

    echo '{"tests": [], "summary": {"total": 0, "passed": 0, "failed": 0}}' > "$TEST_RESULTS_FILE"
}

# Log test result
log_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"

    echo "[$status] $test_name: $message" >> "$TEST_LOG_FILE"

    if [[ "$status" == "PASS" ]]; then
        echo "$(ui_set_color green)✓ PASS$(ui_reset_color): $test_name - $message"
    else
        echo "$(ui_set_color red)✗ FAIL$(ui_reset_color): $test_name - $message"
    fi
}

# Add test result to JSON
add_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local duration="$4"

    local temp_file
    temp_file=$(mktemp)

    # Read current results and add new test
    grep -v '"summary":' "$TEST_RESULTS_FILE" > "$temp_file" 2>/dev/null || echo '{"tests": []' > "$temp_file"

    # Remove closing bracket and add new test
    sed '$ s/}]$/,/' "$temp_file" > "${temp_file}.new"
    mv "${temp_file}.new" "$temp_file"

    cat >> "$temp_file" << EOF
  {
    "name": "$test_name",
    "status": "$status",
    "message": "$message",
    "duration_ms": $duration
  }
]}
EOF

    # Update summary
    local total_tests
    total_tests=$(grep -c '"status":' "$temp_file" 2>/dev/null || echo "0")
    local passed_tests
    passed_tests=$(grep -c '"status": "PASS"' "$temp_file" 2>/dev/null || echo "0")
    local failed_tests
    failed_tests=$(grep -c '"status": "FAIL"' "$temp_file" 2>/dev/null || echo "0")

    sed -i '' '$s/}}$/}, "summary": {"total": '$total_tests', "passed": '$passed_tests', "failed": '$failed_tests'}}/' "$temp_file"

    mv "$temp_file" "$TEST_RESULTS_FILE"
}

# Run individual test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo "Running test: $test_name"

    local start_time
    start_time=$(date +%s%N 2>/dev/null || date +%s)000000000

    local test_result
    if eval "$test_command" >/dev/null 2>&1; then
        test_result="PASS"
        log_test_result "$test_name" "$test_result" "Test completed successfully"
    else
        test_result="FAIL"
        log_test_result "$test_name" "$test_result" "Test failed"
    fi

    local end_time
    end_time=$(date +%s%N 2>/dev/null || date +%s)000000000
    local duration=$(( (end_time - start_time) / 1000000 ))

    add_test_result "$test_name" "$test_result" "Test completed" "$duration"

    return $([[ "$test_result" == "PASS" ]] && echo 0 || echo 1)
}

# Test system analysis
test_system_analysis() {
    local analysis
    analysis=$(perform_system_analysis "test")

    if echo "$analysis" | grep -q "system_resources" && \
       echo "$analysis" | grep -q "package_state" && \
       echo "$analysis" | grep -q "timestamp"; then
        return 0
    else
        return 1
    fi
}

# Test performance monitor
test_performance_monitor() {
    local metrics
    metrics=$(get_current_metrics)

    if echo "$metrics" | grep -q "cpu" && \
       echo "$metrics" | grep -q "memory" && \
       echo "$metrics" | grep -q "disk"; then
        return 0
    else
        return 1
    fi
}

# Test btop integration
test_btop_integration() {
    local status
    status=$(get_btop_status)

    if echo "$status" | grep -q "status"; then
        return 0
    else
        return 1
    fi
}

# Test alert system
test_alert_system() {
    # Create test metrics that should trigger alerts
    local test_metrics
    test_metrics='{"cpu": {"usage_percent": 90}, "memory": {"usage_percent": 85}}'

    local alerts
    alerts=$(check_performance_alerts "$test_metrics")

    # Should generate some alerts for high usage
    if [[ -n "$alerts" ]]; then
        return 0
    else
        return 1
    fi
}

# Test history tracking
test_history_tracking() {
    local summary
    summary=$(get_history_summary)

    if echo "$summary" | grep -q "operations"; then
        return 0
    else
        return 1
    fi
}

# Test monitoring integration
test_monitoring_integration() {
    local status
    status=$(get_monitoring_status)

    if echo "$status" | grep -q "monitoring_enabled" && \
       echo "$status" | grep -q "current_metrics"; then
        return 0
    else
        return 1
    fi
}

# Test alert configuration
test_alert_configuration() {
    # Test that alert rules exist and are properly formatted
    if [[ -f "$ALERT_RULES_FILE" ]]; then
        local rule_count
        rule_count=$(grep -c '"id":' "$ALERT_RULES_FILE" 2>/dev/null || echo "0")

        if [[ $rule_count -gt 0 ]]; then
            return 0
        fi
    fi

    return 1
}

# Test cache directories
test_cache_directories() {
    local dirs=(
        "$SYSTEM_ANALYSIS_CACHE_DIR"
        "$PERFORMANCE_MONITOR_CACHE_DIR"
        "$BTOP_CACHE_DIR"
        "$ALERT_CACHE_DIR"
        "$HISTORY_CACHE_DIR"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            return 1
        fi
    done

    return 0
}

# Test monitoring report generation
test_monitoring_report() {
    local temp_file
    temp_file=$(mktemp)

    if generate_monitoring_report "$temp_file" 2>/dev/null && \
       [[ -f "$temp_file" ]] && \
       grep -q "report_type" "$temp_file"; then
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file" 2>/dev/null || true
        return 1
    fi
}

# Test monitoring cleanup
test_monitoring_cleanup() {
    # Test that cleanup function exists and can run
    if cleanup_monitoring_data 1 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Main test runner
main() {
    echo "FUB Monitoring System Test Suite"
    echo "================================="
    echo

    # Initialize test environment
    init_test_environment
    init_monitoring_system

    local total_tests=0
    local passed_tests=0

    # Run all tests
    run_test "System Analysis" "test_system_analysis" && ((passed_tests++))
    ((total_tests++))

    run_test "Performance Monitor" "test_performance_monitor" && ((passed_tests++))
    ((total_tests++))

    run_test "Btop Integration" "test_btop_integration" && ((passed_tests++))
    ((total_tests++))

    run_test "Alert System" "test_alert_system" && ((passed_tests++))
    ((total_tests++))

    run_test "History Tracking" "test_history_tracking" && ((passed_tests++))
    ((total_tests++))

    run_test "Monitoring Integration" "test_monitoring_integration" && ((passed_tests++))
    ((total_tests++))

    run_test "Alert Configuration" "test_alert_configuration" && ((passed_tests++))
    ((total_tests++))

    run_test "Cache Directories" "test_cache_directories" && ((passed_tests++))
    ((total_tests++))

    run_test "Monitoring Report Generation" "test_monitoring_report" && ((passed_tests++))
    ((total_tests++))

    run_test "Monitoring Cleanup" "test_monitoring_cleanup" && ((passed_tests++))
    ((total_tests++))

    # Display final results
    echo
    echo "Test Results Summary"
    echo "===================="
    echo "Total tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $((total_tests - passed_tests))"
    echo "Success rate: $(echo "$passed_tests $total_tests" | awk '{printf "%.1f", ($1/$2)*100}')%"
    echo

    if [[ $passed_tests -eq $total_tests ]]; then
        echo "$(ui_set_color green)✓ All tests passed!$(ui_reset_color)"
        echo "Test log: $TEST_LOG_FILE"
        echo "Test results: $TEST_RESULTS_FILE"
        return 0
    else
        echo "$(ui_set_color red)✗ Some tests failed. Check the log for details.$(ui_reset_color)"
        echo "Test log: $TEST_LOG_FILE"
        echo "Test results: $TEST_RESULTS_FILE"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi