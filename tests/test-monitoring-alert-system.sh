#!/usr/bin/env bash

# FUB Alert System Module Unit Tests
# Comprehensive unit tests for the alert system module

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="alert-system"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Mock UI functions for testing
mock_ui_functions() {
    ui_set_color() {
        case "$1" in
            "reset") echo "" ;;
            *) echo "" ;;
        esac
    }
    ui_reset_color() { echo ""; }
    export -f ui_set_color ui_reset_color
}

# Apply mock functions
mock_ui_functions

# Source the module under test
source "${TEST_ROOT_DIR}/lib/monitoring/alert-system.sh"

# =============================================================================
# UNIT TESTS FOR ALERT SYSTEM MODULE
# =============================================================================

# Test alert system initialization
test_init_alert_system() {
    # Setup test environment
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization
    init_alert_system

    # Verify cache directory was created
    assert_dir_exists "$ALERT_CACHE_DIR" "Alert cache directory created"

    # Verify file paths are correct
    assert_equals "$ALERT_HISTORY_FILE" "${TEST_CACHE_DIR}/alerts/history.json" "History file path correct"
    assert_equals "$ALERT_RULES_FILE" "${TEST_CACHE_DIR}/alerts/rules.json" "Rules file path correct"

    # Verify files were created with correct structure
    assert_file_exists "$ALERT_HISTORY_FILE" "History file created"
    assert_file_exists "$ALERT_RULES_FILE" "Rules file created"

    local history_content
    history_content=$(cat "$ALERT_HISTORY_FILE")
    assert_contains "$history_content" "alerts" "History file has correct structure"
    assert_contains "$history_content" "[]" "History file initialized with empty array"

    local rules_content
    rules_content=$(cat "$ALERT_RULES_FILE")
    assert_contains "$rules_content" "rules" "Rules file has correct structure"
    assert_contains "$rules_content" "cpu_warning" "Rules file contains CPU warning rule"
    assert_contains "$rules_content" "memory_warning" "Rules file contains memory warning rule"
    assert_contains "$rules_content" "disk_warning" "Rules file contains disk warning rule"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test default alert rules creation
test_create_default_alert_rules() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    export ALERT_RULES_FILE="${TEST_CACHE_DIR}/test-rules.json"

    # Create default rules
    create_default_alert_rules

    # Verify rules file was created
    assert_file_exists "$ALERT_RULES_FILE" "Default rules file created"

    local rules_content
    rules_content=$(cat "$ALERT_RULES_FILE")

    # Verify all default rule types are present
    assert_contains "$rules_content" "cpu_warning" "CPU warning rule present"
    assert_contains "$rules_content" "cpu_critical" "CPU critical rule present"
    assert_contains "$rules_content" "memory_warning" "Memory warning rule present"
    assert_contains "$rules_content" "memory_critical" "Memory critical rule present"
    assert_contains "$rules_content" "disk_warning" "Disk warning rule present"
    assert_contains "$rules_content" "disk_critical" "Disk critical rule present"
    assert_contains "$rules_content" "load_average_high" "Load average rule present"
    assert_contains "$rules_content" "io_wait_high" "I/O wait rule present"

    # Verify rule structure
    assert_contains "$rules_content" "threshold" "Rules contain threshold values"
    assert_contains "$rules_content" "severity" "Rules contain severity levels"
    assert_contains "$rules_content" "message" "Rules contain message templates"
    assert_contains "$rules_content" "recommendation" "Rules contain recommendations"

    # Verify specific threshold values
    if echo "$rules_content" | grep -q '"threshold": 80'; then
        print_test_result "CPU warning threshold correct" "PASS"
    else
        print_test_result "CPU warning threshold correct" "FAIL" "Expected threshold 80 for CPU warning"
    fi

    if echo "$rules_content" | grep -q '"threshold": 95'; then
        print_test_result "CPU critical threshold correct" "PASS"
    else
        print_test_result "CPU critical threshold correct" "FAIL" "Expected threshold 95 for CPU critical"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert cooldown functionality
test_is_alert_in_cooldown() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Test with no previous alerts
    if is_alert_in_cooldown "test_alert" 5; then
        print_test_result "Cooldown with no previous alerts" "FAIL" "Should return false for new alert"
    else
        print_test_result "Cooldown with no previous alerts" "PASS"
    fi

    # Add a mock alert to history
    local past_timestamp
    past_timestamp=$(date -d '10 minutes ago' -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-10M -u +"%Y-%m-%dT%H:%M:%SZ")

    local mock_alert
    mock_alert=$(cat << EOF
{
  "id": "test_123",
  "timestamp": "$past_timestamp",
  "alert_id": "test_alert",
  "severity": "warning"
}
EOF
)

    # Add alert to history file
    local temp_history
    temp_history=$(mktemp)
    echo '{"alerts": [' > "$temp_history"
    echo "$mock_alert" >> "$temp_history"
    echo ']}' >> "$temp_history"
    mv "$temp_history" "$ALERT_HISTORY_FILE"

    # Test with recent alert (should be in cooldown)
    if is_alert_in_cooldown "test_alert" 15; then
        print_test_result "Cooldown with recent alert" "PASS" "Alert correctly in cooldown"
    else
        print_test_result "Cooldown with recent alert" "FAIL" "Should be in cooldown period"
    fi

    # Test with expired cooldown
    if is_alert_in_cooldown "test_alert" 5; then
        print_test_result "Cooldown expired" "FAIL" "Should not be in cooldown after 5 minutes"
    else
        print_test_result "Cooldown expired" "PASS" "Cooldown correctly expired"
    fi

    # Test with different alert ID
    if is_alert_in_cooldown "different_alert" 15; then
        print_test_result "Cooldown for different alert" "FAIL" "Different alert should not be in cooldown"
    else
        print_test_result "Cooldown for different alert" "PASS" "Different alert not affected by cooldown"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert message formatting
test_format_alert_message() {
    # Test basic template replacement
    local message1
    message1=$(format_alert_message "CPU usage is high: {{value}}%" "85.5")

    assert_equals "$message1" "CPU usage is high: 85.5%" "Basic template replacement works"

    # Test template with multiple placeholders
    local message2
    message2=$(format_alert_message "Memory at {{value}}%, disk at {{value}}%" "75")

    # Should replace all occurrences
    if [[ "$message2" == "Memory at 75%, disk at 75%" ]]; then
        print_test_result "Multiple template replacements" "PASS"
    else
        print_test_result "Multiple template replacements" "FAIL" "Expected all placeholders replaced"
    fi

    # Test template without placeholder
    local message3
    message3=$(format_alert_message "Simple static message" "123")

    assert_equals "$message3" "Simple static message" "Static message unchanged"

    # Test empty template
    local message4
    message4=$(format_alert_message "" "45")

    assert_equals "$message4" "" "Empty template handled"

    # Test special characters in value
    local message5
    message5=$(format_alert_message "Value: {{value}}" "test with spaces & symbols!")

    assert_contains "$message5" "test with spaces & symbols!" "Special characters handled correctly"
}

# Test alert object creation
test_create_alert() {
    # Create a test alert
    local alert
    alert=$(create_alert "cpu_warning" "High CPU Usage" "warning" "CPU usage is high" "Check processes" "85.5" "cpu_usage")

    # Verify alert structure
    assert_contains "$alert" "id" "Alert contains ID"
    assert_contains "$alert" "timestamp" "Alert contains timestamp"
    assert_contains "$alert" "rule_id" "Alert contains rule ID"
    assert_contains "$alert" "cpu_warning" "Alert contains correct rule ID"
    assert_contains "$alert" "rule_name" "Alert contains rule name"
    assert_contains "$alert" "High CPU Usage" "Alert contains correct rule name"
    assert_contains "$alert" "severity" "Alert contains severity"
    assert_contains "$alert" "warning" "Alert contains correct severity"
    assert_contains "$alert" "message" "Alert contains message"
    assert_contains "$alert" "CPU usage is high" "Alert contains correct message"
    assert_contains "$alert" "recommendation" "Alert contains recommendation"
    assert_contains "$alert" "Check processes" "Alert contains correct recommendation"
    assert_contains "$alert" "metric" "Alert contains metric section"
    assert_contains "$alert" "cpu_usage" "Alert contains metric name"
    assert_contains "$alert" "85.5" "Alert contains metric value"
    assert_contains "$alert" "acknowledged" "Alert contains acknowledged status"
    assert_contains "$alert" "false" "Alert is not acknowledged by default"

    # Test with critical severity
    local critical_alert
    critical_alert=$(create_alert "disk_critical" "Disk Full" "critical" "No disk space" "Clean up now" "98" "disk_usage")

    assert_contains "$critical_alert" "critical" "Critical alert has correct severity"

    # Test with empty values
    local empty_alert
    empty_alert=$(create_alert "" "" "" "" "" "" "")

    if echo "$empty_alert" | grep -q '"id":\|"rule_id":\|"severity":'; then
        print_test_result "Alert creation with empty values" "PASS" "Handled gracefully"
    else
        print_test_result "Alert creation with empty values" "FAIL" "Should create alert structure even with empty values"
    fi
}

# Test alert saving
test_save_alert() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Create a test alert
    local test_alert
    test_alert=$(create_alert "test_rule" "Test Alert" "warning" "Test message" "Test recommendation" "50" "test_metric")

    # Save the alert
    save_alert "$test_alert"

    # Verify alert was saved
    assert_file_exists "$ALERT_HISTORY_FILE" "History file exists after saving alert"

    local history_content
    history_content=$(cat "$ALERT_HISTORY_FILE")

    assert_contains "$history_content" "test_rule" "Alert saved with correct rule ID"
    assert_contains "$history_content" "Test Alert" "Alert saved with correct rule name"
    assert_contains "$history_content" "warning" "Alert saved with correct severity"
    assert_contains "$history_content" "Test message" "Alert saved with correct message"

    # Test saving multiple alerts
    local test_alert2
    test_alert2=$(create_alert "test_rule2" "Test Alert 2" "critical" "Test message 2" "Test recommendation 2" "90" "test_metric2")

    save_alert "$test_alert2"

    local updated_history
    updated_history=$(cat "$ALERT_HISTORY_FILE")

    assert_contains "$updated_history" "test_rule2" "Second alert saved correctly"
    assert_contains "$updated_history" "critical" "Second alert severity correct"

    # Verify alert count increased
    local alert_count
    alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")
    if [[ $alert_count -ge 2 ]]; then
        print_test_result "Multiple alerts saved" "PASS" "Found $alert_count alerts"
    else
        print_test_result "Multiple alerts saved" "FAIL" "Expected at least 2 alerts, found $alert_count"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert checking functionality
test_check_alerts() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Test with alerts disabled
    export ALERT_ENABLED=false
    local mock_metrics='{"cpu": {"usage_percent": 90.0}}'

    # Should return without triggering alerts
    check_alerts "$mock_metrics"

    local alert_count
    alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")
    if [[ $alert_count -eq 0 ]]; then
        print_test_result "Alert checking disabled" "PASS" "No alerts when disabled"
    else
        print_test_result "Alert checking disabled" "FAIL" "Should not trigger alerts when disabled"
    fi

    # Enable alerts and test
    export ALERT_ENABLED=true

    # Create metrics that should trigger CPU warning
    local high_cpu_metrics='{
        "cpu": {"usage_percent": 85.0},
        "memory": {"usage_percent": 60.0},
        "disk": {"usage_percent": 70.0},
        "io": {"wait_percent": 5.0}
    }'

    check_alerts "$high_cpu_metrics"

    local alert_count_after
    alert_count_after=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")
    if [[ $alert_count_after -gt 0 ]]; then
        print_test_result "Alert checking triggered" "PASS" "Alerts triggered for high metrics"
    else
        print_test_result "Alert checking triggered" "FAIL" "Should have triggered alerts for high CPU"
    fi

    # Test with normal metrics (should not trigger alerts)
    local normal_metrics='{
        "cpu": {"usage_percent": 30.0},
        "memory": {"usage_percent": 40.0},
        "disk": {"usage_percent": 50.0},
        "io": {"wait_percent": 2.0}
    }'

    local alerts_before
    alerts_before=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")

    check_alerts "$normal_metrics"

    local alerts_after
    alerts_after=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")

    if [[ $alerts_after -eq $alerts_before ]]; then
        print_test_result "Alert checking normal metrics" "PASS" "No new alerts for normal metrics"
    else
        print_test_result "Alert checking normal metrics" "FAIL" "Should not trigger alerts for normal metrics"
    fi

    # Test with missing metrics file
    check_alerts ""
    # Should handle gracefully without error

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert display
test_display_alert() {
    # Create test alerts for different severities
    local warning_alert
    warning_alert=$(create_alert "test_warning" "Test Warning" "warning" "Warning message" "Warning recommendation" "75" "cpu_usage")

    local critical_alert
    critical_alert=$(create_alert "test_critical" "Test Critical" "critical" "Critical message" "Critical recommendation" "95" "memory_usage")

    local info_alert
    info_alert=$(create_alert "test_info" "Test Info" "info" "Info message" "Info recommendation" "50" "disk_usage")

    # Test warning alert display
    local warning_output
    warning_output=$(display_alert "$warning_alert")

    assert_contains "$warning_output" "WARNING" "Warning alert shows warning label"
    assert_contains "$warning_output" "Warning message" "Warning alert shows message"
    assert_contains "$warning_output" "Warning recommendation" "Warning alert shows recommendation"

    # Test critical alert display
    local critical_output
    critical_output=$(display_alert "$critical_alert")

    assert_contains "$critical_output" "CRITICAL" "Critical alert shows critical label"
    assert_contains "$critical_output" "Critical message" "Critical alert shows message"
    assert_contains "$critical_output" "Critical recommendation" "Critical alert shows recommendation"

    # Test info alert display
    local info_output
    info_output=$(display_alert "$info_alert")

    assert_contains "$info_output" "INFO" "Info alert shows info label"
    assert_contains "$info_output" "Info message" "Info alert shows message"

    # Test with malformed alert
    local malformed_alert='{"invalid": "json"}'
    if display_alert "$malformed_alert" >/dev/null 2>&1; then
        print_test_result "Malformed alert display" "PASS" "Handled gracefully"
    else
        print_test_result "Malformed alert display" "FAIL" "Should handle malformed alert gracefully"
    fi
}

# Test recent alerts retrieval
test_get_recent_alerts() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Test with no alerts
    local no_alerts
    no_alerts=$(get_recent_alerts 24)

    assert_contains "$no_alerts" "recent_alerts" "Recent alerts structure correct"
    assert_contains "$no_alerts" "[]" "Empty alerts array returned"

    # Add some test alerts with different timestamps
    local old_timestamp
    old_timestamp=$(date -d '2 days ago' -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-2d -u +"%Y-%m-%dT%H:%M:%SZ")

    local recent_timestamp
    recent_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local old_alert
    old_alert=$(create_alert "old_test" "Old Alert" "warning" "Old message" "Old recommendation" "50" "test_metric")
    local old_alert_with_timestamp
    old_alert_with_timestamp=$(echo "$old_alert" | sed "s/\"timestamp\": \".*\"/\"timestamp\": \"$old_timestamp\"/")

    local recent_alert
    recent_alert=$(create_alert "recent_test" "Recent Alert" "critical" "Recent message" "Recent recommendation" "80" "test_metric")
    local recent_alert_with_timestamp
    recent_alert_with_timestamp=$(echo "$recent_alert" | sed "s/\"timestamp\": \".*\"/\"timestamp\": \"$recent_timestamp\"/")

    save_alert "$old_alert_with_timestamp"
    save_alert "$recent_alert_with_timestamp"

    # Get recent alerts (last 24 hours)
    local recent_alerts_result
    recent_alerts_result=$(get_recent_alerts 24)

    # Should contain recent alerts structure
    assert_contains "$recent_alerts_result" "recent_alerts" "Recent alerts result has correct structure"

    # Test with different time periods
    local week_alerts
    week_alerts=$(get_recent_alerts 168)  # 7 days
    assert_contains "$week_alerts" "recent_alerts" "Week alerts structure correct"

    # Test with very short time period
    local hour_alerts
    hour_alerts=$(get_recent_alerts 1)
    assert_contains "$hour_alerts" "recent_alerts" "Hour alerts structure correct"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert acknowledgment
test_acknowledge_alert() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Create and save a test alert
    local test_alert
    test_alert=$(create_alert "test_ack" "Test Alert" "warning" "Test message" "Test recommendation" "60" "test_metric")
    save_alert "$test_alert"

    # Extract alert ID
    local alert_id
    alert_id=$(echo "$test_alert" | grep '"id":' | cut -d'"' -f4)

    # Acknowledge the alert
    acknowledge_alert "$alert_id"

    # Verify alert was acknowledged
    local history_content
    history_content=$(cat "$ALERT_HISTORY_FILE")

    if echo "$history_content" | grep -q "\"id\": \"$alert_id\".*\"acknowledged\": true"; then
        print_test_result "Alert acknowledgment" "PASS" "Alert marked as acknowledged"
    else
        print_test_result "Alert acknowledgment" "FAIL" "Alert not marked as acknowledged"
    fi

    # Test acknowledging non-existent alert
    if acknowledge_alert "nonexistent_alert_id" 2>/dev/null; then
        print_test_result "Non-existent alert acknowledgment" "PASS" "Handled gracefully"
    else
        print_test_result "Non-existent alert acknowledgment" "FAIL" "Should handle non-existent alert gracefully"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test old alerts clearing
test_clear_old_alerts() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Add alerts with different timestamps
    local old_timestamp
    old_timestamp=$(date -d '10 days ago' -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-10d -u +"%Y-%m-%dT%H:%M:%SZ")

    local recent_timestamp
    recent_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create old alert
    local old_alert
    old_alert=$(create_alert "old_clear_test" "Old Alert" "warning" "Old message" "Old recommendation" "50" "test_metric")
    local old_alert_with_timestamp
    old_alert_with_timestamp=$(echo "$old_alert" | sed "s/\"timestamp\": \".*\"/\"timestamp\": \"$old_timestamp\"/")

    # Create recent alert
    local recent_alert
    recent_alert=$(create_alert "recent_clear_test" "Recent Alert" "critical" "Recent message" "Recent recommendation" "80" "test_metric")
    local recent_alert_with_timestamp
    recent_alert_with_timestamp=$(echo "$recent_alert" | sed "s/\"timestamp\": \".*\"/\"timestamp\": \"$recent_timestamp\"/")

    save_alert "$old_alert_with_timestamp"
    save_alert "$recent_alert_with_timestamp"

    local alerts_before
    alerts_before=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")

    # Clear alerts older than 5 days
    clear_old_alerts 5

    local alerts_after
    alerts_after=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" || echo "0")

    # Should have fewer alerts (old ones removed)
    if [[ $alerts_after -lt $alerts_before ]]; then
        print_test_result "Old alerts clearing" "PASS" "Old alerts removed: $alerts_before -> $alerts_after"
    else
        print_test_result "Old alerts clearing" "FAIL" "Old alerts not removed"
    fi

    # Recent alert should still exist
    local history_content
    history_content=$(cat "$ALERT_HISTORY_FILE")
    if echo "$history_content" | grep -q "recent_clear_test"; then
        print_test_result "Recent alerts preserved" "PASS"
    else
        print_test_result "Recent alerts preserved" "FAIL" "Recent alert was removed"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert summary
test_get_alert_summary() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Test with no alerts
    local empty_summary
    empty_summary=$(get_alert_summary 24)

    assert_contains "$empty_summary" "total" "Summary contains total count"
    assert_contains "$empty_summary" "critical" "Summary contains critical count"
    assert_contains "$empty_summary" "warning" "Summary contains warning count"
    assert_contains "$empty_summary" "info" "Summary contains info count"
    assert_contains "$empty_summary" "\"total\": 0" "Empty summary shows zero total"

    # Add alerts of different severities
    local critical_alert
    critical_alert=$(create_alert "summary_critical" "Critical" "critical" "Critical message" "Critical recommendation" "95" "test_metric")
    save_alert "$critical_alert"

    local warning_alert1
    warning_alert1=$(create_alert "summary_warning1" "Warning 1" "warning" "Warning message 1" "Warning recommendation 1" "80" "test_metric")
    save_alert "$warning_alert1"

    local warning_alert2
    warning_alert2=$(create_alert "summary_warning2" "Warning 2" "warning" "Warning message 2" "Warning recommendation 2" "75" "test_metric")
    save_alert "$warning_alert2"

    local info_alert
    info_alert=$(create_alert "summary_info" "Info" "info" "Info message" "Info recommendation" "50" "test_metric")
    save_alert "$info_alert"

    # Get summary
    local summary
    summary=$(get_alert_summary 24)

    # Verify counts
    if echo "$summary" | grep -q '"total": 4'; then
        print_test_result "Summary total count" "PASS"
    else
        print_test_result "Summary total count" "FAIL" "Expected total 4"
    fi

    if echo "$summary" | grep -q '"critical": 1'; then
        print_test_result "Summary critical count" "PASS"
    else
        print_test_result "Summary critical count" "FAIL" "Expected 1 critical"
    fi

    if echo "$summary" | grep -q '"warning": 2'; then
        print_test_result "Summary warning count" "PASS"
    else
        print_test_result "Summary warning count" "FAIL" "Expected 2 warnings"
    fi

    if echo "$summary" | grep -q '"info": 1'; then
        print_test_result "Summary info count" "PASS"
    else
        print_test_result "Summary info count" "FAIL" "Expected 1 info"
    fi

    # Test with different time period
    local period_summary
    period_summary=$(get_alert_summary 48)
    assert_contains "$period_summary" "\"period_hours\": 48" "Summary includes correct time period"

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
    if init_alert_system 2>/dev/null; then
        print_test_result "Read-only directory handling" "PASS" "Handled gracefully"
    else
        print_test_result "Read-only directory handling" "FAIL" "Should handle read-only directory"
    fi

    # Restore permissions for cleanup
    chmod 755 "$readonly_dir" 2>/dev/null || true

    # Test with corrupted history file
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo '{"invalid": json}' > "$ALERT_HISTORY_FILE"

    if get_alert_summary 24 >/dev/null 2>&1; then
        print_test_result "Corrupted history file handling" "PASS" "Handled gracefully"
    else
        print_test_result "Corrupted history file handling" "FAIL" "Should handle corrupted file"
    fi

    # Test with missing rules file
    rm -f "$ALERT_RULES_FILE"

    local mock_metrics='{"cpu": {"usage_percent": 90.0}}'
    if check_alerts "$mock_metrics" 2>/dev/null; then
        print_test_result "Missing rules file handling" "PASS" "Handled gracefully"
    else
        print_test_result "Missing rules file handling" "FAIL" "Should handle missing rules file"
    fi

    # Test alert saving with invalid JSON
    local invalid_alert='{"invalid": json}'
    if save_alert "$invalid_alert" 2>/dev/null; then
        print_test_result "Invalid alert JSON handling" "PASS" "Handled gracefully"
    else
        print_test_result "Invalid alert JSON handling" "FAIL" "Should handle invalid JSON"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance and resource usage
test_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    # Test initialization performance
    local start_time
    local end_time
    local duration

    start_time=$(date +%s.%N)
    init_alert_system
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")

    if (( $(echo "$duration < 1" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Initialization performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Initialization performance" "FAIL" "Too slow: ${duration}s"
    fi

    # Test alert creation performance
    start_time=$(date +%s.%N)
    for i in {1..10}; do
        create_alert "perf_test_$i" "Performance Test $i" "warning" "Test message $i" "Test recommendation" "75" "test_metric" >/dev/null
    done
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")

    if (( $(echo "$duration < 1" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Alert creation performance" "PASS" "10 alerts in ${duration}s"
    else
        print_test_result "Alert creation performance" "FAIL" "Too slow: ${duration}s for 10 alerts"
    fi

    # Test alert checking performance
    local mock_metrics='{"cpu": {"usage_percent": 90.0}, "memory": {"usage_percent": 85.0}}'

    start_time=$(date +%s.%N)
    check_alerts "$mock_metrics" >/dev/null
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")

    if (( $(echo "$duration < 2" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Alert checking performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Alert checking performance" "FAIL" "Too slow: ${duration}s"
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
    print_test_header "Alert System Module Unit Tests"

    # Run all test functions
    local test_functions=(
        "test_init_alert_system"
        "test_create_default_alert_rules"
        "test_is_alert_in_cooldown"
        "test_format_alert_message"
        "test_create_alert"
        "test_save_alert"
        "test_check_alerts"
        "test_display_alert"
        "test_get_recent_alerts"
        "test_acknowledge_alert"
        "test_clear_old_alerts"
        "test_get_alert_summary"
        "test_error_handling"
        "test_performance"
    )

    run_test_suite "Alert System Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi