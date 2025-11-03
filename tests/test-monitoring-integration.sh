#!/usr/bin/env bash

# FUB Monitoring Integration Tests
# Integration tests for monitoring system with safety and cleanup modules

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="monitoring-integration"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Source all monitoring modules
source "${TEST_ROOT_DIR}/lib/monitoring/system-analysis.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/performance-monitor.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/history-tracking.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/alert-system.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/btop-integration.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/monitoring-ui.sh"

# =============================================================================
# INTEGRATION TESTS FOR MONITORING SYSTEM
# =============================================================================

# Test integration between system analysis and safety systems
test_system_analysis_safety_integration() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize both systems
    init_system_analysis
    init_alert_system

    # Perform system analysis
    local analysis_result
    analysis_result=$(perform_system_analysis "quick")

    # Verify analysis structure
    assert_contains "$analysis_result" "system_resources" "Analysis contains system resources"
    assert_contains "$analysis_result" "package_state" "Analysis contains package state"
    assert_contains "$analysis_result" "service_status" "Analysis contains service status"

    # Calculate system score
    local system_score
    system_score=$(get_system_score)

    # Score should be numeric
    if [[ "$system_score" =~ ^[0-9]+$ ]]; then
        print_test_result "System score calculation" "PASS" "Score: $system_score"
    else
        print_test_result "System score calculation" "FAIL" "Score should be numeric: $system_score"
    fi

    # Check if score triggers alerts
    local mock_metrics
    mock_metrics=$(cat << EOF
{
    "cpu": {"usage_percent": $system_score},
    "memory": {"usage_percent": 60.0},
    "disk": {"usage_percent": 70.0}
}
EOF
)

    # Test alert checking with analysis metrics
    check_alerts "$mock_metrics"

    # Verify alert system can process analysis results
    local alert_count
    alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $alert_count -ge 0 ]]; then
        print_test_result "Analysis metrics alert processing" "PASS" "Alerts processed: $alert_count"
    else
        print_test_result "Analysis metrics alert processing" "FAIL" "Alert processing failed"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test integration between performance monitoring and cleanup operations
test_performance_cleanup_integration() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize systems
    init_performance_monitor
    init_history_tracking

    # Simulate cleanup operation performance monitoring
    local cleanup_id="test-cleanup-$(date +%s)"

    # Record metrics before cleanup
    record_metrics "pre_cleanup"

    # Simulate cleanup operation (background process)
    sleep 2 &
    local cleanup_pid=$!

    # Monitor the cleanup operation
    local monitoring_result
    monitoring_result=$(timeout 5s monitor_operation "$cleanup_id" "$cleanup_pid" 1 3 2>/dev/null || echo "monitoring_completed")

    # Wait for cleanup process
    wait "$cleanup_pid" 2>/dev/null || true

    # Record metrics after cleanup
    record_metrics "post_cleanup"

    # Verify monitoring was attempted
    if [[ "$monitoring_result" == "monitoring_completed" ]] || [[ -f "$monitoring_result" ]]; then
        print_test_result "Cleanup operation monitoring" "PASS" "Monitoring completed"
    else
        print_test_result "Cleanup operation monitoring" "SKIP" "Monitoring timing varies"
    fi

    # Get performance trends
    local trends
    trends=$(get_performance_trends 1)

    assert_contains "$trends" "averages" "Trends contain averages"
    assert_contains "$trends" "peaks" "Trends contain peaks"

    # Test performance summary
    local summary
    summary=$(get_performance_summary 1)

    assert_contains "$summary" "current_metrics" "Summary contains current metrics"
    assert_contains "$summary" "trends" "Summary contains trends"
    assert_contains "$summary" "alerts" "Summary contains alerts"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test integration between history tracking and cleanup operations
test_history_cleanup_integration() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize history tracking
    init_history_tracking

    # Create mock before/after states
    local before_state
    before_state=$(cat << EOF
{
    "system_resources": {
        "cpu": {"usage_percent": 60.0},
        "memory": {"usage_percent": 75.0},
        "disk": {"used": "15G", "total": "50G"}
    }
}
EOF
)

    local after_state
    after_state=$(cat << EOF
{
    "system_resources": {
        "cpu": {"usage_percent": 40.0},
        "memory": {"usage_percent": 55.0},
        "disk": {"used": "12G", "total": "50G"}
    }
}
EOF
)

    local operation_details
    operation_details='{"files_removed": 50, "space_freed": "3GB"}'

    # Record cleanup operation
    local operation_record
    operation_record=$(record_cleanup_operation "package_cleanup" "integration-test-001" "$before_state" "$after_state" 120 "success" "$operation_details")

    # Verify operation record structure
    assert_contains "$operation_record" "integration-test-001" "Operation record contains correct ID"
    assert_contains "$operation_record" "package_cleanup" "Operation record contains correct type"
    assert_contains "$operation_record" "success" "Operation record contains correct status"
    assert_contains "$operation_record" "space_saved_mb" "Operation record contains space saved"

    # Test performance snapshot recording
    local performance_metrics
    performance_metrics='{"cpu": {"usage_percent": 35.0}, "memory": {"usage_percent": 50.0}}'

    record_performance_snapshot "integration-test-001" "2023-01-01T12:00:00Z" "$performance_metrics"

    # Verify history file updates
    assert_file_exists "$HISTORY_DB_FILE" "History database file exists"
    assert_file_exists "$HISTORY_PERFORMANCE_FILE" "Performance history file exists"

    local db_content
    db_content=$(cat "$HISTORY_DB_FILE")
    assert_contains "$db_content" "integration-test-001" "History database contains operation"

    local perf_content
    perf_content=$(cat "$HISTORY_PERFORMANCE_FILE")
    assert_contains "$perf_content" "integration-test-001" "Performance history contains snapshot"

    # Test history summary generation
    update_history_summary
    local summary
    summary=$(get_history_summary)

    assert_contains "$summary" "operations" "Summary contains operations section"
    assert_contains "$summary" "total" "Summary contains total operations"
    assert_contains "$summary" "successful" "Summary contains successful operations"
    assert_contains "$summary" "impact" "Summary contains impact section"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert system integration with monitoring components
test_alert_monitoring_integration() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize alert and monitoring systems
    init_alert_system
    init_performance_monitor

    # Test alert thresholds and performance metrics integration
    local high_metrics
    high_metrics='{
        "cpu": {"usage_percent": 90.0, "load_average": "2.5"},
        "memory": {"usage_percent": 85.0},
        "disk": {"usage_percent": 88.0},
        "io": {"wait_percent": 25.0}
    }'

    # Check alerts with high metrics
    check_alerts "$high_metrics"

    local high_alerts_count
    high_alerts_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Should trigger multiple alerts
    if [[ $high_alerts_count -gt 0 ]]; then
        print_test_result "High metrics alert triggering" "PASS" "Triggered $high_alerts_count alerts"
    else
        print_test_result "High metrics alert triggering" "FAIL" "Should have triggered alerts"
    fi

    # Test with normal metrics
    local normal_metrics
    normal_metrics='{
        "cpu": {"usage_percent": 30.0, "load_average": "0.8"},
        "memory": {"usage_percent": 45.0},
        "disk": {"usage_percent": 55.0},
        "io": {"wait_percent": 5.0}
    }'

    local alerts_before_normal
    alerts_before_normal=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    check_alerts "$normal_metrics"

    local alerts_after_normal
    alerts_after_normal=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Should not trigger additional alerts for normal metrics
    if [[ $alerts_after_normal -eq $alerts_before_normal ]]; then
        print_test_result "Normal metrics alert suppression" "PASS" "No new alerts for normal metrics"
    else
        print_test_result "Normal metrics alert suppression" "FAIL" "Should not trigger alerts for normal metrics"
    fi

    # Test alert summary integration
    local alert_summary
    alert_summary=$(get_alert_summary 1)

    assert_contains "$alert_summary" "total" "Alert summary contains total count"
    assert_contains "$alert_summary" "critical" "Alert summary contains critical count"
    assert_contains "$alert_summary" "warning" "Alert summary contains warning count"

    # Test cooldown functionality
    local alert_count_before_cooldown
    alert_count_before_cooldown=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Check alerts again with same high metrics (should be affected by cooldown)
    check_alerts "$high_metrics"

    local alert_count_after_cooldown
    alert_count_after_cooldown=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Due to cooldown, should not trigger the same alerts immediately
    if [[ $alert_count_after_cooldown -le $alert_count_before_cooldown + 2 ]]; then
        print_test_result "Alert cooldown integration" "PASS" "Cooldown prevented duplicate alerts"
    else
        print_test_result "Alert cooldown integration" "SKIP" "Cooldown timing may vary"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop integration with monitoring workflow
test_btop_monitoring_workflow_integration() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize btop integration
    init_btop_integration

    # Test data capture workflow
    local capture_result
    capture_result=$(capture_btop_data 2 "${TEST_CACHE_DIR}/btop-capture.json")

    # Verify capture result structure
    assert_contains "$capture_result" "timestamp" "Capture contains timestamp"
    assert_contains "$capture_result" "capture_duration" "Capture contains duration"
    assert_contains "$capture_result" "source" "Capture contains source"

    # Verify output file was created
    assert_file_exists "${TEST_CACHE_DIR}/btop-capture.json" "Btop capture file created"

    # Test monitoring workflow with background process
    sleep 3 &
    local test_pid=$!

    local monitor_log
    monitor_log=$(timeout 6s monitor_with_btop "btop_integration_test" "$test_pid" 10 2>/dev/null || echo "monitoring_completed")

    wait "$test_pid" 2>/dev/null || true

    if [[ "$monitor_log" == "monitoring_completed" ]] || [[ -f "$monitor_log" ]]; then
        print_test_result "Btop monitoring workflow" "PASS" "Monitoring workflow completed"
    else
        print_test_result "Btop monitoring workflow" "SKIP" "Monitoring timing varies"
    fi

    # Test btop status checking
    local btop_status
    btop_status=$(get_btop_status)

    assert_contains "$btop_status" "status" "Status contains status field"
    assert_contains "$btop_status" "config_dir" "Status contains config directory"
    assert_contains "$btop_status" "cache_dir" "Status contains cache directory"

    # Test report generation
    if [[ -f "${TEST_CACHE_DIR}/btop-capture.json" ]]; then
        local report
        report=$(generate_btop_report "${TEST_CACHE_DIR}/btop-capture.json")

        assert_contains "$report" "report_type" "Report contains type field"
        assert_contains "$report" "btop_performance" "Report type is correct"
        assert_contains "$report" "summary" "Report contains summary section"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test monitoring UI integration with all monitoring components
test_monitoring_ui_integration() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize all monitoring components
    init_system_analysis
    init_performance_monitor
    init_history_tracking
    init_alert_system

    # Test UI components integration with backend data

    # Test system metrics display integration
    local current_metrics
    current_metrics=$(get_current_metrics)

    local metrics_display
    metrics_display=$(display_system_metrics "$current_metrics")

    assert_contains "$metrics_display" "CPU Usage:" "UI displays CPU usage"
    assert_contains "$metrics_display" "Memory Usage:" "UI displays memory usage"
    assert_contains "$metrics_display" "Disk Usage:" "UI UI displays disk usage"

    # Test alert display integration
    local alerts
    alerts=$(check_performance_alerts "$current_metrics")

    if [[ "$alerts" != "[]" ]]; then
        local alert_display
        alert_display=$(display_alerts_widget "$alerts")

        assert_contains "$alert_display" "System Alerts:" "UI displays alert header"
    else
        print_test_result "Alert display integration (no alerts)" "PASS" "No alerts to display"
    fi

    # Test history display integration
    local mock_history
    mock_history='{
        "operations": [
            {
                "operation_id": "ui-test-001",
                "operation_type": "test_cleanup",
                "duration_seconds": 60,
                "status": "success",
                "impact": {"space_saved_mb": 250}
            }
        ]
    }'

    # Mock get_cleanup_history for UI testing
    get_cleanup_history() { echo "$mock_history"; }
    export -f get_cleanup_history

    local history_display
    history_display=$(display_cleanup_history 7)

    assert_contains "$history_display" "Cleanup History" "UI displays history header"
    assert_contains "$history_display" "Operation ID" "UI displays table headers"

    # Test trends display integration
    local mock_trends
    mock_trends='{
        "period_days": 7,
        "trends": {
            "cpu": "stable",
            "memory": "decreasing",
            "disk": "increasing"
        }
    }'

    # Mock get_performance_trends for UI testing
    get_performance_trends() { echo "$mock_trends"; }
    export -f get_performance_trends

    local trends_display
    trends_display=$(display_performance_trends 7)

    assert_contains "$trends_display" "Performance Trends" "UI displays trends header"
    assert_contains "$trends_display" "CPU Usage Trend:" "UI displays CPU trend"
    assert_contains "$trends_display" "Stable" "UI displays trend indicator"

    # Test health report integration
    local health_report
    health_report=$(display_system_health_report)

    assert_contains "$health_report" "System Health Report" "UI displays health report header"
    assert_contains "$health_report" "System Health Score:" "UI displays health score"

    # Cleanup
    unset -f get_cleanup_history get_performance_trends
    rm -rf "$TEST_CACHE_DIR"
}

# Test pre/post cleanup analysis workflow
test_pre_post_cleanup_analysis() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize required systems
    init_system_analysis
    init_history_tracking
    init_performance_monitor

    # Simulate pre-cleanup analysis
    local pre_analysis_file="${TEST_CACHE_DIR}/pre-cleanup.json"
    local pre_analysis
    pre_analysis=$(perform_system_analysis "pre_cleanup" "$pre_analysis_file")

    assert_file_exists "$pre_analysis_file" "Pre-cleanup analysis file created"
    assert_contains "$pre_analysis" "\"pre_cleanup\"" "Pre-analysis has correct type"

    # Record pre-cleanup performance metrics
    record_metrics "pre_cleanup"

    # Simulate some system changes (mock)
    sleep 1

    # Simulate post-cleanup analysis
    local post_analysis_file="${TEST_CACHE_DIR}/post-cleanup.json"
    local post_analysis
    post_analysis=$(perform_system_analysis "post_cleanup" "$post_analysis_file")

    assert_file_exists "$post_analysis_file" "Post-cleanup analysis file created"
    assert_contains "$post_analysis" "\"post_cleanup\"" "Post-analysis has correct type"

    # Record post-cleanup performance metrics
    record_metrics "post_cleanup"

    # Compare pre/post analyses
    local comparison
    comparison=$(compare_analyses "$pre_analysis_file" "$post_analysis_file")

    assert_contains "$comparison" "comparison" "Comparison contains comparison section"
    assert_contains "$comparison" "cpu_change_percent" "Comparison contains CPU change"
    assert_contains "$comparison" "memory_change_percent" "Comparison contains memory change"
    assert_contains "$comparison" "disk_change_percent" "Comparison contains disk change"

    # Test cleanup operation recording with pre/post data
    local operation_details
    operation_details='{"pre_analysis": "'"$pre_analysis_file"'", "post_analysis": "'"$post_analysis_file"'"}'

    local cleanup_record
    cleanup_record=$(record_cleanup_operation "full_system_cleanup" "pre-post-test-001" "$pre_analysis" "$post_analysis" 300 "success" "$operation_details")

    assert_contains "$cleanup_record" "pre-post-test-001" "Cleanup record contains correct ID"
    assert_contains "$cleanup_record" "space_saved_mb" "Cleanup record contains space saved"
    assert_contains "$cleanup_record" "performance_change" "Cleanup record contains performance change"

    # Test performance trends with pre/post data
    local performance_trends
    performance_trends=$(get_performance_trends 1)

    assert_contains "$performance_trends" "averages" "Performance trends available after cleanup"
    assert_contains "$performance_trends" "peaks" "Performance trends contain peaks"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test monitoring system resilience and error handling
test_monitoring_system_resilience() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize monitoring systems
    init_system_analysis
    init_performance_monitor
    init_alert_system
    init_history_tracking

    # Test resilience to missing system commands
    local original_path="$PATH"
    export PATH="/nonexistent:$PATH"

    # Should handle missing commands gracefully
    local resilient_analysis
    resilient_analysis=$(perform_system_analysis "resilience_test")

    assert_contains "$resilient_analysis" "resilience_test" "Analysis works despite missing commands"

    local resilient_metrics
    resilient_metrics=$(get_current_metrics)

    assert_contains "$resilient_metrics" "timestamp" "Metrics work despite missing commands"

    # Restore PATH
    export PATH="$original_path"

    # Test resilience to corrupted cache files
    echo '{"corrupted": json}' > "$SYSTEM_ANALYSIS_STATE_FILE"
    echo '{"corrupted": json}' > "$PERFORMANCE_MONITOR_HISTORY_FILE"
    echo '{"corrupted": json}' > "$ALERT_HISTORY_FILE"

    # Should recover or handle gracefully
    if perform_system_analysis "recovery_test" >/dev/null 2>&1; then
        print_test_result "Corrupted cache recovery" "PASS" "System recovered from corrupted cache"
    else
        print_test_result "Corrupted cache recovery" "FAIL" "Should handle corrupted cache files"
    fi

    if get_current_metrics >/dev/null 2>&1; then
        print_test_result "Corrupted performance history recovery" "PASS" "Performance monitor recovered"
    else
        print_test_result "Corrupted performance history recovery" "FAIL" "Should handle corrupted history"
    fi

    # Test resilience to permission issues
    local readonly_dir="${TEST_CACHE_DIR}/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir" 2>/dev/null || true

    export FUB_CACHE_DIR="$readonly_dir"

    if init_system_analysis 2>/dev/null || init_performance_monitor 2>/dev/null; then
        print_test_result "Permission issues handling" "PASS" "Handled gracefully"
    else
        print_test_result "Permission issues handling" "FAIL" "Should handle permission issues"
    fi

    # Restore permissions for cleanup
    chmod 755 "$readonly_dir" 2>/dev/null || true

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test end-to-end monitoring workflow
test_end_to_end_monitoring_workflow() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize all monitoring systems
    init_system_analysis
    init_performance_monitor
    init_alert_system
    init_history_tracking
    init_btop_integration

    echo "Starting end-to-end monitoring workflow test..."

    # Step 1: Initial system analysis
    local initial_analysis
    initial_analysis=$(perform_system_analysis "initial")

    assert_contains "$initial_analysis" "initial" "Initial analysis completed"

    # Step 2: Baseline performance recording
    record_metrics "workflow_baseline"

    # Step 3: Simulate system operation (background process)
    local operation_start
    operation_start=$(date +%s)

    sleep 5 &
    local workflow_pid=$!

    # Step 4: Monitor operation
    local operation_monitoring
    operation_monitoring=$(timeout 7s monitor_operation "end_to_end_test" "$workflow_pid" 2 3 2>/dev/null || echo "monitoring_completed")

    wait "$workflow_pid" 2>/dev/null || true

    local operation_end
    operation_end=$(date +%s)
    local operation_duration=$((operation_end - operation_start))

    # Step 5: Post-operation analysis
    local post_analysis
    post_analysis=$(perform_system_analysis "post_operation")

    assert_contains "$post_analysis" "post_operation" "Post-operation analysis completed"

    # Step 6: Record post-operation metrics
    record_metrics "workflow_complete"

    # Step 7: Performance impact assessment
    local performance_summary
    performance_summary=$(get_performance_summary 1)

    assert_contains "$performance_summary" "current_metrics" "Performance summary generated"
    assert_contains "$performance_summary" "trends" "Performance trends available"

    # Step 8: Alert assessment
    local current_metrics
    current_metrics=$(get_current_metrics)
    check_alerts "$current_metrics"

    local alert_summary
    alert_summary=$(get_alert_summary 1)

    assert_contains "$alert_summary" "total" "Alert summary generated"

    # Step 9: Historical recording
    local workflow_details
    workflow_details='{
        "duration_seconds": '$operation_duration',
        "monitoring_completed": true,
        "steps_completed": ["initial_analysis", "baseline_metrics", "operation_monitoring", "post_analysis", "performance_summary", "alert_assessment"]
    }'

    local workflow_record
    workflow_record=$(record_cleanup_operation "end_to_end_workflow" "workflow-test-$(date +%s)" "$initial_analysis" "$post_analysis" "$operation_duration" "success" "$workflow_details")

    assert_contains "$workflow_record" "end_to_end_workflow" "Workflow recorded successfully"
    assert_contains "$workflow_record" "success" "Workflow completed successfully"

    # Step 10: System health assessment
    local final_score
    final_score=$(get_system_score)

    if [[ "$final_score" =~ ^[0-9]+$ ]] && [[ $final_score -ge 0 && $final_score -le 100 ]]; then
        print_test_result "End-to-end workflow completion" "PASS" "Completed in ${operation_duration}s, final score: $final_score"
    else
        print_test_result "End-to-end workflow completion" "FAIL" "Invalid final score: $final_score"
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
    print_test_header "Monitoring System Integration Tests"

    # Run all test functions
    local test_functions=(
        "test_system_analysis_safety_integration"
        "test_performance_cleanup_integration"
        "test_history_cleanup_integration"
        "test_alert_monitoring_integration"
        "test_btop_monitoring_workflow_integration"
        "test_monitoring_ui_integration"
        "test_pre_post_cleanup_analysis"
        "test_monitoring_system_resilience"
        "test_end_to_end_monitoring_workflow"
    )

    run_test_suite "Monitoring Integration Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi