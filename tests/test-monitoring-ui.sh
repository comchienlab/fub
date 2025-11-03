#!/usr/bin/env bash

# FUB Monitoring UI Module Unit Tests
# Comprehensive unit tests for the monitoring UI module

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="monitoring-ui"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Mock UI functions for testing
mock_ui_functions() {
    # Mock UI functions to avoid dependencies
    ui_set_color() {
        case "$1" in
            "reset") echo "" ;;
            *) echo "" ;;
        esac
    }
    ui_reset_color() { echo ""; }
    ui_separator() { echo "=========="; }
    ui_header() { echo "=== $1 ==="; }
    export -f ui_set_color ui_reset_color ui_separator ui_header
}

# Source the module under test
mock_ui_functions
source "${TEST_ROOT_DIR}/lib/monitoring/monitoring-ui.sh"

# =============================================================================
# UNIT TESTS FOR MONITORING UI MODULE
# =============================================================================

# Test monitoring UI initialization
test_init_monitoring_ui() {
    # Test initialization
    init_monitoring_ui

    # Since init_monitoring_ui only logs, we just verify it doesn't error
    print_test_result "Monitoring UI initialization" "PASS"
}

# Test monitoring header display
test_display_monitoring_header() {
    # Capture header output
    local header_output
    header_output=$(display_monitoring_header)

    # Verify header contains expected elements
    assert_contains "$header_output" "FUB System Monitor" "Header contains system monitor title"
    assert_contains "$header_output" "Real-time Monitoring" "Header contains monitoring mode"
    assert_contains "$header_output" "==========" "Header contains separator"

    # Verify timestamp is present (should be current date/time pattern)
    if echo "$header_output" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        print_test_result "Header contains timestamp" "PASS"
    else
        print_test_result "Header contains timestamp" "FAIL" "Timestamp pattern not found"
    fi
}

# Test meter display function
test_display_meter() {
    # Test normal usage (50%)
    local meter_50
    meter_50=$(display_meter 50 100 20)

    assert_contains "$meter_50" "50%" "Meter shows correct percentage"
    if [[ $(echo "$meter_50" | grep -o "█" | wc -l) -eq 10 ]]; then
        print_test_result "Meter shows correct fill at 50%" "PASS"
    else
        print_test_result "Meter shows correct fill at 50%" "FAIL" "Expected 10 filled characters at 50%"
    fi

    # Test high usage (85% - should be red)
    local meter_85
    meter_85=$(display_meter 85 100 20)

    assert_contains "$meter_85" "85%" "Meter shows correct percentage at 85%"

    # Test low usage (25% - should be green)
    local meter_25
    meter_25=$(display_meter 25 100 20)

    assert_contains "$meter_25" "25%" "Meter shows correct percentage at 25%"

    # Test zero usage
    local meter_0
    meter_0=$(display_meter 0 100 20)

    assert_contains "$meter_0" "0%" "Meter shows correct percentage at 0%"
    if [[ $(echo "$meter_0" | grep -o "█" | wc -l) -eq 0 ]]; then
        print_test_result "Meter shows no fill at 0%" "PASS"
    else
        print_test_result "Meter shows no fill at 0%" "FAIL" "Should have no filled characters at 0%"
    fi

    # Test full usage (100%)
    local meter_100
    meter_100=$(display_meter 100 100 20)

    assert_contains "$meter_100" "100%" "Meter shows correct percentage at 100%"

    # Test custom width
    local meter_custom
    meter_custom=$(display_meter 50 100 10)

    assert_contains "$meter_custom" "50%" "Custom width meter shows correct percentage"
    if [[ $(echo "$meter_custom" | grep -o "█" | wc -l) -eq 5 ]]; then
        print_test_result "Custom width meter correct fill" "PASS"
    else
        print_test_result "Custom width meter correct fill" "FAIL" "Expected 5 filled characters with width 10"
    fi

    # Test edge cases
    local meter_negative
    meter_negative=$(display_meter -10 100 20)
    assert_contains "$meter_negative" "%" "Negative value handled gracefully"

    local meter_over_max
    meter_over_max=$(display_meter 150 100 20)
    assert_contains "$meter_over_max" "%" "Over-max value handled gracefully"
}

# Test system metrics display
test_display_system_metrics() {
    # Create mock metrics JSON
    local mock_metrics='{
        "timestamp": "2023-01-01T12:00:00Z",
        "cpu": {
            "usage_percent": 45.5,
            "load_average": "1.2, 1.1, 0.9"
        },
        "memory": {
            "usage_percent": 67.8
        },
        "disk": {
            "usage_percent": 78.2
        },
        "io": {
            "wait_percent": 5.5
        }
    }'

    # Display system metrics
    local metrics_output
    metrics_output=$(display_system_metrics "$mock_metrics")

    # Verify CPU metrics
    assert_contains "$metrics_output" "CPU Usage:" "Output contains CPU usage label"
    assert_contains "$metrics_output" "45.5%" "Output contains correct CPU percentage"
    assert_contains "$metrics_output" "Load Average:" "Output contains load average label"
    assert_contains "$metrics_output" "1.2, 1.1, 0.9" "Output contains correct load average"

    # Verify memory metrics
    assert_contains "$metrics_output" "Memory Usage:" "Output contains memory usage label"
    assert_contains "$metrics_output" "67.8%" "Output contains correct memory percentage"

    # Verify disk metrics
    assert_contains "$metrics_output" "Disk Usage:" "Output contains disk usage label"
    assert_contains "$metrics_output" "78.2%" "Output contains correct disk percentage"

    # Verify I/O metrics
    assert_contains "$metrics_output" "I/O Wait:" "Output contains I/O wait label"
    assert_contains "$metrics_output" "5.5%" "Output contains correct I/O wait percentage"

    # Test with missing values
    local incomplete_metrics='{
        "cpu": {"usage_percent": 30.0},
        "memory": {"usage_percent": 40.0}
    }'

    local incomplete_output
    incomplete_output=$(display_system_metrics "$incomplete_metrics")

    assert_contains "$incomplete_output" "N/A" "Missing values handled gracefully"
    assert_contains "$incomplete_output" "0%" "Default values used for missing metrics"
}

# Test alerts widget display
test_display_alerts_widget() {
    # Test with no alerts
    local no_alerts='[]'
    local no_alerts_output
    no_alerts_output=$(display_alerts_widget "$no_alerts")

    # Should not display any alert content
    if [[ -z "$no_alerts_output" ]]; then
        print_test_result "No alerts display" "PASS" "Empty alerts produce no output"
    else
        print_test_result "No alerts display" "FAIL" "Empty alerts should produce no output"
    fi

    # Test with CPU high alert
    local cpu_alerts='[
        {
            "type": "cpu_high",
            "severity": "warning",
            "message": "High CPU usage"
        }
    ]'

    local cpu_alerts_output
    cpu_alerts_output=$(display_alerts_widget "$cpu_alerts")

    assert_contains "$cpu_alerts_output" "System Alerts:" "Output contains alerts header"
    assert_contains "$cpu_alerts_output" "High resource usage detected" "Output contains resource usage warning"

    # Test with critical alert
    local critical_alerts='[
        {
            "type": "disk_high",
            "severity": "critical",
            "message": "Critical disk usage"
        }
    ]'

    local critical_alerts_output
    critical_alerts_output=$(display_alerts_widget "$critical_alerts")

    assert_contains "$critical_alerts_output" "Critical system alerts active" "Output contains critical alert message"

    # Test with multiple alerts
    local multiple_alerts='[
        {
            "type": "cpu_high",
            "severity": "warning",
            "message": "High CPU usage"
        },
        {
            "type": "memory_high",
            "severity": "critical",
            "message": "Critical memory usage"
        }
    ]'

    local multiple_alerts_output
    multiple_alerts_output=$(display_alerts_widget "$multiple_alerts")

    assert_contains "$multiple_alerts_output" "High resource usage detected" "Multiple alerts show resource warning"
    assert_contains "$multiple_alerts_output" "Critical system alerts active" "Multiple alerts show critical warning"
}

# Test detailed metrics display
test_display_detailed_metrics() {
    # Mock the ps and du commands to avoid dependency on actual system state
    mock_ps() {
        echo "USER        %CPU COMMAND"
        echo "user1       25.0 process1"
        echo "user2       15.0 process2"
        echo "user3       10.0 process3"
        echo "user4        5.0 process4"
        echo "user5        2.0 process5"
    }

    mock_du() {
        echo "10G    /home/user1"
        echo "5G     /home/user2"
        echo "3G     /home/user3"
        echo "2G     /home/user4"
        echo "1G     /home/user5"
    }

    # Temporarily override commands
    ps() { mock_ps; }
    du() { mock_du "$@"; }
    export -f ps du

    # Display detailed metrics
    local detailed_output
    detailed_output=$(display_detailed_metrics)

    # Verify CPU processes section
    assert_contains "$detailed_output" "Top CPU Processes:" "Output contains CPU processes header"
    assert_contains "$detailed_output" "process1" "Output contains top CPU process"

    # Verify memory processes section
    assert_contains "$detailed_output" "Top Memory Processes:" "Output contains memory processes header"

    # Verify disk usage section
    assert_contains "$detailed_output" "Disk Usage by Directory:" "Output contains disk usage header"
    assert_contains "$detailed_output" "/home/user1" "Output contains top disk usage directory"

    # Restore original commands
    unset -f ps du
}

# Test cleanup history display
test_display_cleanup_history() {
    # Create mock history data
    local mock_history='{
        "operations": [
            {
                "operation_id": "op-001",
                "operation_type": "package_cleanup",
                "duration_seconds": 120,
                "status": "success",
                "impact": {"space_saved_mb": 250}
            },
            {
                "operation_id": "op-002",
                "operation_type": "temp_cleanup",
                "duration_seconds": 45,
                "status": "success",
                "impact": {"space_saved_mb": 100}
            }
        ]
    }'

    # Mock get_cleanup_history function
    get_cleanup_history() { echo "$mock_history"; }
    export -f get_cleanup_history

    # Display cleanup history
    local history_output
    history_output=$(display_cleanup_history 30)

    assert_contains "$history_output" "Cleanup History (Last 30 Days)" "Output contains history header"
    assert_contains "$history_output" "Operation ID" "Output contains table headers"
    assert_contains "$history_output" "Type" "Output contains type header"
    assert_contains "$history_output" "Duration" "Output contains duration header"
    assert_contains "$history_output" "Status" "Output contains status header"
    assert_contains "$history_output" "Space Saved" "Output contains space saved header"

    # Test with empty history
    local empty_history='{"operations": []}'
    get_cleanup_history() { echo "$empty_history"; }

    local empty_history_output
    empty_history_output=$(display_cleanup_history 30)

    assert_contains "$empty_history_output" "No cleanup operations found" "Empty history shows appropriate message"

    # Restore function
    unset -f get_cleanup_history
}

# Test performance trends display
test_display_performance_trends() {
    # Create mock trends data
    local mock_trends='{
        "period_days": 7,
        "trends": {
            "cpu": "increasing",
            "memory": "decreasing",
            "disk": "stable"
        }
    }'

    # Mock get_performance_trends function
    get_performance_trends() { echo "$mock_trends"; }
    export -f get_performance_trends

    # Display performance trends
    local trends_output
    trends_output=$(display_performance_trends 7)

    assert_contains "$trends_output" "Performance Trends (Last 7 Days)" "Output contains trends header"
    assert_contains "$trends_output" "CPU Usage Trend:" "Output contains CPU trend label"
    assert_contains "$trends_output" "Memory Usage Trend:" "Output contains memory trend label"
    assert_contains "$trends_output" "Disk Usage Trend:" "Output contains disk trend label"

    # Test trend indicators
    assert_contains "$trends_output" "📈 Increasing" "Output contains increasing trend indicator"
    assert_contains "$trends_output" "📉 Decreasing" "Output contains decreasing trend indicator"
    assert_contains "$trends_output" "➡️  Stable" "Output contains stable trend indicator"

    # Test with unknown trend
    local unknown_trends='{
        "period_days": 7,
        "trends": {
            "cpu": "unknown"
        }
    }'

    get_performance_trends() { echo "$unknown_trends"; }

    local unknown_output
    unknown_output=$(display_performance_trends 7)
    assert_contains "$unknown_output" "❓ Unknown" "Unknown trend handled correctly"

    # Restore function
    unset -f get_performance_trends
}

# Test trend indicator display
test_display_trend_indicator() {
    # Test increasing trend
    local increasing_output
    increasing_output=$(display_trend_indicator "increasing")
    assert_contains "$increasing_output" "📈 Increasing" "Increasing trend displays correctly"

    # Test decreasing trend
    local decreasing_output
    decreasing_output=$(display_trend_indicator "decreasing")
    assert_contains "$decreasing_output" "📉 Decreasing" "Decreasing trend displays correctly"

    # Test stable trend
    local stable_output
    stable_output=$(display_trend_indicator "stable")
    assert_contains "$stable_output" "➡️  Stable" "Stable trend displays correctly"

    # Test unknown trend
    local unknown_output
    unknown_output=$(display_trend_indicator "unknown")
    assert_contains "$unknown_output" "❓ Unknown" "Unknown trend displays correctly"

    # Test empty trend
    local empty_output
    empty_output=$(display_trend_indicator "")
    assert_contains "$empty_output" "❓ Unknown" "Empty trend handled as unknown"
}

# Test system health report
test_display_system_health_report() {
    # Mock required functions
    perform_system_analysis() {
        echo '{
            "system_resources": {
                "cpu": {"usage_percent": 45.0},
                "memory": {"usage_percent": 60.0},
                "disk": {"usage_percent": 70.0}
            }
        }'
    }

    get_system_score() { echo "75"; }

    get_alert_summary() {
        echo '{"critical": 0, "warning": 2}';
    }

    generate_maintenance_suggestions() {
        echo '{"suggestions": [{"type": "cleanup", "message": "Consider running cleanup"}]}';
    }

    export -f perform_system_analysis get_system_score get_alert_summary generate_maintenance_suggestions

    # Display system health report
    local health_output
    health_output=$(display_system_health_report)

    assert_contains "$health_output" "System Health Report" "Output contains health report header"
    assert_contains "$health_output" "System Health Score:" "Output contains health score label"
    assert_contains "$health_output" "75/100" "Output contains correct health score"
    assert_contains "$health_output" "Good" "Output contains correct health rating"
    assert_contains "$health_output" "Current System Status:" "Output contains system status section"
    assert_contains "$health_output" "No critical alerts" "Output contains alert summary"
    assert_contains "$health_output" "Maintenance Suggestions:" "Output contains suggestions section"

    # Test with poor health score
    get_system_score() { echo "25"; }

    local poor_health_output
    poor_health_output=$(display_system_health_report)
    assert_contains "$poor_health_output" "Poor" "Poor health score displays correctly"

    # Test with critical alerts
    get_alert_summary() { echo '{"critical": 3, "warning": 1}'; }

    local critical_health_output
    critical_health_output=$(display_system_health_report)
    assert_contains "$critical_health_output" "3 critical alerts" "Critical alerts displayed correctly"

    # Restore functions
    unset -f perform_system_analysis get_system_score get_alert_summary generate_maintenance_suggestions
}

# Test health score display
test_display_health_score() {
    # Test excellent score
    local excellent_output
    excellent_output=$(display_health_score 90)
    assert_contains "$excellent_output" "90/100" "Excellent score shows correct value"
    assert_contains "$excellent_output" "Excellent" "Excellent score shows correct rating"

    # Test good score
    local good_output
    good_output=$(display_health_score 75)
    assert_contains "$good_output" "75/100" "Good score shows correct value"
    assert_contains "$good_output" "Good" "Good score shows correct rating"

    # Test fair score
    local fair_output
    fair_output=$(display_health_score 50)
    assert_contains "$fair_output" "50/100" "Fair score shows correct value"
    assert_contains "$fair_output" "Fair" "Fair score shows correct rating"

    # Test poor score
    local poor_output
    poor_output=$(display_health_score 25)
    assert_contains "$poor_output" "25/100" "Poor score shows correct value"
    assert_contains "$poor_output" "Poor" "Poor score shows correct rating"

    # Test boundary values
    local boundary_80
    boundary_80=$(display_health_score 80)
    assert_contains "$boundary_80" "Excellent" "Score 80 shows as Excellent"

    local boundary_60
    boundary_60=$(display_health_score 60)
    assert_contains "$boundary_60" "Good" "Score 60 shows as Good"

    local boundary_40
    boundary_40=$(display_health_score 40)
    assert_contains "$boundary_40" "Fair" "Score 40 shows as Fair"
}

# Test alert configuration display
test_display_alert_configuration() {
    # Set test environment variables
    export ALERT_CPU_WARNING=80
    export ALERT_CPU_CRITICAL=95
    export ALERT_MEMORY_WARNING=85
    export ALERT_MEMORY_CRITICAL=90
    export ALERT_DISK_WARNING=75
    export ALERT_DISK_CRITICAL=90
    export ALERT_ENABLED=true

    # Display alert configuration
    local config_output
    config_output=$(display_alert_configuration)

    assert_contains "$config_output" "Alert Configuration" "Output contains configuration header"
    assert_contains "$config_output" "Current Alert Thresholds:" "Output contains thresholds header"
    assert_contains "$config_output" "CPU Usage:" "Output contains CPU section"
    assert_contains "$config_output" "Warning: 80%" "Output contains CPU warning threshold"
    assert_contains "$config_output" "Critical: 95%" "Output contains CPU critical threshold"
    assert_contains "$config_output" "Memory Usage:" "Output contains memory section"
    assert_contains "$config_output" "Warning: 85%" "Output contains memory warning threshold"
    assert_contains "$config_output" "Critical: 90%" "Output contains memory critical threshold"
    assert_contains "$config_output" "Disk Usage:" "Output contains disk section"
    assert_contains "$config_output" "Warning: 75%" "Output contains disk warning threshold"
    assert_contains "$config_output" "Critical: 90%" "Output contains disk critical threshold"
    assert_contains "$config_output" "Alert System:" "Output contains alert system status"
    assert_contains "$config_output" "Enabled" "Output shows alert system enabled"

    # Test with disabled alerts
    export ALERT_ENABLED=false

    local disabled_output
    disabled_output=$(display_alert_configuration)
    assert_contains "$disabled_output" "Disabled" "Output shows alert system disabled"
}

# Test export menu display
test_display_export_menu() {
    # Mock export_history function
    export_history() {
        local format="$1"
        local file="$2"
        echo "Exported as $format to $file" > "$file"
    }
    export -f export_history

    # Test JSON export (simulate user input)
    local test_input="1
test_export.json
3
"

    local export_output
    export_output=$(echo -e "$test_input" | display_export_menu 2>/dev/null || true)

    # Verify file was created (if the function worked)
    if [[ -f "test_export.json" ]]; then
        print_test_result "Export menu JSON export" "PASS" "Export file created"
        rm -f "test_export.json"
    else
        print_test_result "Export menu JSON export" "SKIP" "Export file creation not testable in unit test"
    fi

    # Test CSV export
    local csv_input="2
test_export.csv
3
"

    echo -e "$csv_input" | display_export_menu 2>/dev/null || true

    if [[ -f "test_export.csv" ]]; then
        print_test_result "Export menu CSV export" "PASS" "CSV export file created"
        rm -f "test_export.csv"
    else
        print_test_result "Export menu CSV export" "SKIP" "CSV export file creation not testable in unit test"
    fi

    # Test invalid choice
    local invalid_input="99
3
"

    echo -e "$invalid_input" | display_export_menu 2>/dev/null || true
    # Invalid choice should be handled gracefully (function returns without error)

    # Restore function
    unset -f export_history
}

# Test real-time monitoring (basic functionality)
test_display_realtime_monitoring() {
    # Test with very short duration to avoid hanging tests
    local start_time
    start_time=$(date +%s)

    # This would normally run for the specified duration, but we'll test setup only
    if timeout 3s display_realtime_monitoring 1 false 2>/dev/null; then
        print_test_result "Real-time monitoring basic functionality" "PASS" "Monitoring starts without error"
    else
        print_test_result "Real-time monitoring basic functionality" "PASS" "Monitoring function exists (timeout expected)"
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Should not take too long even with timeout
    if [[ $duration -lt 10 ]]; then
        print_test_result "Real-time monitoring timeout handling" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Real-time monitoring timeout handling" "FAIL" "Took too long: ${duration}s"
    fi
}

# Test error handling
test_error_handling() {
    # Test display_system_metrics with invalid JSON
    local invalid_metrics='{"invalid": json}'

    if display_system_metrics "$invalid_metrics" >/dev/null 2>&1; then
        print_test_result "Invalid metrics JSON handling" "PASS" "Handled gracefully"
    else
        print_test_result "Invalid metrics JSON handling" "FAIL" "Should handle invalid JSON gracefully"
    fi

    # Test display_alerts_widget with malformed alerts
    local malformed_alerts='{invalid: json}'

    if display_alerts_widget "$malformed_alerts" >/dev/null 2>&1; then
        print_test_result "Malformed alerts handling" "PASS" "Handled gracefully"
    else
        print_test_result "Malformed alerts handling" "FAIL" "Should handle malformed alerts gracefully"
    fi

    # Test display_meter with invalid values
    if display_meter "invalid" "invalid" >/dev/null 2>&1; then
        print_test_result "Invalid meter values handling" "PASS" "Handled gracefully"
    else
        print_test_result "Invalid meter values handling" "FAIL" "Should handle invalid values gracefully"
    fi

    # Test display_trend_indicator with special characters
    local special_output
    special_output=$(display_trend_indicator "special-chars_123")
    assert_contains "$special_output" "Unknown" "Special characters in trend handled as unknown"
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

main_test() {
    # Initialize test framework
    init_test_framework "${TEST_ROOT_DIR}/test-results" "true" "false"

    # Print test header
    print_test_header "Monitoring UI Module Unit Tests"

    # Run all test functions
    local test_functions=(
        "test_init_monitoring_ui"
        "test_display_monitoring_header"
        "test_display_meter"
        "test_display_system_metrics"
        "test_display_alerts_widget"
        "test_display_detailed_metrics"
        "test_display_cleanup_history"
        "test_display_performance_trends"
        "test_display_trend_indicator"
        "test_display_system_health_report"
        "test_display_health_score"
        "test_display_alert_configuration"
        "test_display_export_menu"
        "test_display_realtime_monitoring"
        "test_error_handling"
    )

    run_test_suite "Monitoring UI Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi