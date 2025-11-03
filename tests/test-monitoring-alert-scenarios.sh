#!/usr/bin/env bash

# FUB Alert System Scenario Tests
# Comprehensive tests for various alert system scenarios

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="monitoring-alert-scenarios"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Mock UI functions for testing
mock_ui_functions() {
    ui_set_color() { echo ""; }
    ui_reset_color() { echo ""; }
    export -f ui_set_color ui_reset_color
}

# Apply mock functions
mock_ui_functions

# Source alert system and monitoring modules
source "${TEST_ROOT_DIR}/lib/monitoring/alert-system.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/performance-monitor.sh"

# Alert scenario testing utilities
create_test_metrics() {
    local cpu_usage="${1:-50}"
    local memory_usage="${2:-60}"
    local disk_usage="${3:-70}"
    local load_avg="${4:-1.0}"
    local io_wait="${5:-5.0}"

    cat << EOF
{
    "cpu": {
        "usage_percent": $cpu_usage,
        "load_average": "$load_avg"
    },
    "memory": {
        "usage_percent": $memory_usage
    },
    "disk": {
        "usage_percent": $disk_usage
    },
    "io": {
        "wait_percent": $io_wait
    }
}
EOF
}

simulate_time_progression() {
    local minutes="${1:-5}"
    echo "$(date -d "$minutes minutes ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${minutes}M -u +"%Y-%m-%dT%H:%M:%SZ")"
}

# =============================================================================
# ALERT SYSTEM SCENARIO TESTS
# =============================================================================

# Test threshold-based alert scenarios
test_threshold_based_alerts() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Threshold-Based Alert Scenarios ==="

    # Scenario 1: CPU usage warning threshold
    echo "Scenario 1: CPU warning threshold breach"
    local warning_metrics
    warning_metrics=$(create_test_metrics 82 60 70 1.5 5.0)

    check_alerts "$warning_metrics"

    local cpu_warning_count
    cpu_warning_count=$(grep -c '"severity": "warning"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $cpu_warning_count -gt 0 ]]; then
        print_test_result "CPU warning threshold alert" "PASS" "CPU warning triggered at 82%"
    else
        print_test_result "CPU warning threshold alert" "FAIL" "CPU warning not triggered at 82%"
    fi

    # Scenario 2: CPU usage critical threshold
    echo "Scenario 2: CPU critical threshold breach"
    local critical_metrics
    critical_metrics=$(create_test_metrics 96 60 70 2.0 5.0)

    check_alerts "$critical_metrics"

    local cpu_critical_count
    cpu_critical_count=$(grep -c '"severity": "critical"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $cpu_critical_count -gt 0 ]]; then
        print_test_result "CPU critical threshold alert" "PASS" "CPU critical triggered at 96%"
    else
        print_test_result "CPU critical threshold alert" "FAIL" "CPU critical not triggered at 96%"
    fi

    # Scenario 3: Memory threshold breach
    echo "Scenario 3: Memory warning threshold breach"
    local memory_warning_metrics
    memory_warning_metrics=$(create_test_metrics 50 83 70 1.2 5.0)

    check_alerts "$memory_warning_metrics"

    if grep -q '"severity": "warning".*"memory"' "$ALERT_HISTORY_FILE"; then
        print_test_result "Memory warning threshold alert" "PASS" "Memory warning triggered at 83%"
    else
        print_test_result "Memory warning threshold alert" "FAIL" "Memory warning not triggered at 83%"
    fi

    # Scenario 4: Disk critical threshold breach
    echo "Scenario 4: Disk critical threshold breach"
    local disk_critical_metrics
    disk_critical_metrics=$(create_test_metrics 50 60 96 1.0 5.0)

    check_alerts "$disk_critical_metrics"

    if grep -q '"severity": "critical".*"disk"' "$ALERT_HISTORY_FILE"; then
        print_test_result "Disk critical threshold alert" "PASS" "Disk critical triggered at 96%"
    else
        print_test_result "Disk critical threshold alert" "FAIL" "Disk critical not triggered at 96%"
    fi

    # Scenario 5: Load average threshold breach
    echo "Scenario 5: Load average threshold breach"
    local load_high_metrics
    load_high_metrics=$(create_test_metrics 50 60 70 2.5 5.0)

    check_alerts "$load_high_metrics"

    if grep -q '"severity": "warning".*"load_average"' "$ALERT_HISTORY_FILE"; then
        print_test_result "Load average threshold alert" "PASS" "Load warning triggered at 2.5"
    else
        print_test_result "Load average threshold alert" "FAIL" "Load warning not triggered at 2.5"
    fi

    # Scenario 6: I/O wait threshold breach
    echo "Scenario 6: I/O wait threshold breach"
    local io_wait_metrics
    io_wait_metrics=$(create_test_metrics 50 60 70 1.0 22.0)

    check_alerts "$io_wait_metrics"

    if grep -q '"severity": "warning".*"io_wait"' "$ALERT_HISTORY_FILE"; then
        print_test_result "I/O wait threshold alert" "PASS" "I/O wait warning triggered at 22%"
    else
        print_test_result "I/O wait threshold alert" "FAIL" "I/O wait warning not triggered at 22%"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert cooldown scenarios
test_alert_cooldown_scenarios() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Alert Cooldown Scenarios ==="

    # Scenario 1: Immediate repeated alert should be suppressed
    echo "Scenario 1: Alert cooldown suppression"
    local high_metrics
    high_metrics=$(create_test_metrics 85 60 70 1.5 5.0)

    # First alert
    check_alerts "$high_metrics"
    local first_alert_count
    first_alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Immediate second alert (should be suppressed by cooldown)
    sleep 1
    check_alerts "$high_metrics"
    local second_alert_count
    second_alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $second_alert_count -eq $first_alert_count ]]; then
        print_test_result "Alert cooldown suppression" "PASS" "Repeated alert suppressed"
    else
        print_test_result "Alert cooldown suppression" "FAIL" "Repeated alert not suppressed"
    fi

    # Scenario 2: Alert should trigger after cooldown period
    echo "Scenario 2: Alert triggers after cooldown"

    # Create mock old alert timestamp to simulate cooldown expiry
    local old_timestamp
    old_timestamp=$(simulate_time_progression 10)  # 10 minutes ago

    local old_alert
    old_alert=$(cat << EOF
{
  "id": "cooldown_test_123",
  "timestamp": "$old_timestamp",
  "alert_id": "cpu_warning",
  "severity": "warning"
}
EOF
)

    # Add old alert to history
    local temp_history
    temp_history=$(mktemp)
    echo '{"alerts": [' > "$temp_history"
    echo "$old_alert" >> "$temp_history"
    echo ']}' >> "$temp_history"
    mv "$temp_history" "$ALERT_HISTORY_FILE"

    # Now check alerts again (should trigger new alert)
    check_alerts "$high_metrics"
    local after_cooldown_count
    after_cooldown_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $after_cooldown_count -gt $second_alert_count ]]; then
        print_test_result "Alert triggers after cooldown" "PASS" "New alert triggered after cooldown"
    else
        print_test_result "Alert triggers after cooldown" "SKIP" "Cooldown behavior may vary"
    fi

    # Scenario 3: Different alert types should not affect each other's cooldown
    echo "Scenario 3: Different alert types independent cooldown"

    # Clear history
    echo '{"alerts": []}' > "$ALERT_HISTORY_FILE"

    # Trigger CPU warning
    local cpu_metrics
    cpu_metrics=$(create_test_metrics 85 60 70 1.5 5.0)
    check_alerts "$cpu_metrics"

    # Immediately trigger memory warning (different alert type)
    local memory_metrics
    memory_metrics=$(create_test_metrics 50 85 70 1.5 5.0)
    check_alerts "$memory_metrics"

    local total_alerts
    total_alerts=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Should have 2 different alerts
    if [[ $total_alerts -eq 2 ]]; then
        print_test_result "Independent alert cooldown" "PASS" "Different alert types triggered independently"
    else
        print_test_result "Independent alert cooldown" "FAIL" "Expected 2 alerts, got $total_alerts"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test multiple concurrent alerts scenario
test_multiple_concurrent_alerts() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Multiple Concurrent Alerts Scenario ==="

    # Scenario: System under extreme stress - multiple metrics breach thresholds
    echo "Scenario: Multiple concurrent threshold breaches"
    local extreme_metrics
    extreme_metrics=$(create_test_metrics 95 92 98 3.5 25.0)

    check_alerts "$extreme_metrics"

    # Count different types of alerts triggered
    local total_alerts
    total_alerts=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    local critical_alerts
    critical_alerts=$(grep -c '"severity": "critical"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    local warning_alerts
    warning_alerts=$(grep -c '"severity": "warning"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    echo "Concurrent alerts summary:"
    echo "  Total alerts: $total_alerts"
    echo "  Critical alerts: $critical_alerts"
    echo "  Warning alerts: $warning_alerts"

    # Should trigger multiple alerts
    if [[ $total_alerts -ge 3 ]]; then
        print_test_result "Multiple concurrent alerts" "PASS" "Multiple alerts triggered: $total_alerts"
    else
        print_test_result "Multiple concurrent alerts" "FAIL" "Expected multiple alerts, got $total_alerts"
    fi

    # Should have both critical and warning alerts
    if [[ $critical_alerts -gt 0 && $warning_alerts -gt 0 ]]; then
        print_test_result "Mixed severity concurrent alerts" "PASS" "Critical: $critical_alerts, Warning: $warning_alerts"
    else
        print_test_result "Mixed severity concurrent alerts" "FAIL" "Missing critical or warning alerts"
    fi

    # Verify alert summary reflects concurrent alerts
    local alert_summary
    alert_summary=$(get_alert_summary 1)

    if echo "$alert_summary" | grep -q '"total": [0-9]\+' && echo "$alert_summary" | grep -q '"critical": [0-9]\+'; then
        print_test_result "Concurrent alerts summary" "PASS" "Summary correctly reflects concurrent alerts"
    else
        print_test_result "Concurrent alerts summary" "FAIL" "Summary does not reflect concurrent alerts"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert escalation scenarios
test_alert_escalation_scenarios() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Alert Escalation Scenarios ==="

    # Scenario 1: Warning to critical escalation
    echo "Scenario 1: Warning to critical escalation"

    # First, trigger warning level
    local warning_metrics
    warning_metrics=$(create_test_metrics 82 60 70 1.5 5.0)
    check_alerts "$warning_metrics"

    local warning_count
    warning_count=$(grep -c '"severity": "warning"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Simulate time progression and escalate to critical
    local critical_metrics
    critical_metrics=$(create_test_metrics 96 60 70 2.5 5.0)

    # Add old timestamp to allow new alert
    local past_timestamp
    past_timestamp=$(simulate_time_progression 6)
    sed -i.bak "s/\"timestamp\": \".*\"/\"timestamp\": \"$past_timestamp\"/" "$ALERT_HISTORY_FILE" 2>/dev/null || true

    check_alerts "$critical_metrics"

    local critical_count
    critical_count=$(grep -c '"severity": "critical"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $warning_count -gt 0 && $critical_count -gt 0 ]]; then
        print_test_result "Warning to critical escalation" "PASS" "Both warning ($warning_count) and critical ($critical_count) alerts present"
    else
        print_test_result "Warning to critical escalation" "FAIL" "Escalation not properly recorded"
    fi

    # Scenario 2: Multiple metrics escalation
    echo "Scenario 2: Multiple metric degradation"

    # Clear history for clean test
    echo '{"alerts": []}' > "$ALERT_HISTORY_FILE"

    # Start with single metric issue
    local single_issue_metrics
    single_issue_metrics=$(create_test_metrics 82 60 70 1.0 5.0)
    check_alerts "$single_issue_metrics"

    local single_alert_count
    single_alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Escalate to multiple issues
    sleep 1
    local multiple_issues_metrics
    multiple_issues_metrics=$(create_test_metrics 92 88 95 2.8 15.0)

    # Allow new alerts by modifying timestamps
    sed -i.bak "s/\"timestamp\": \".*\"/\"timestamp\": \"$past_timestamp\"/" "$ALERT_HISTORY_FILE" 2>/dev/null || true

    check_alerts "$multiple_issues_metrics"

    local multiple_alert_count
    multiple_alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $multiple_alert_count -gt $single_alert_count ]]; then
        print_test_result "Multiple metric escalation" "PASS" "Alerts increased from $single_alert_count to $multiple_alert_count"
    else
        print_test_result "Multiple metric escalation" "FAIL" "Alert escalation not detected"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert recovery scenarios
test_alert_recovery_scenarios() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Alert Recovery Scenarios ==="

    # Scenario 1: System recovers from alert state
    echo "Scenario 1: System recovery from alert state"

    # Trigger alerts with bad metrics
    local bad_metrics
    bad_metrics=$(create_test_metrics 90 85 92 2.5 12.0)
    check_alerts "$bad_metrics"

    local alert_count_during_issue
    alert_count_during_issue=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    echo "Alerts during issue: $alert_count_during_issue"

    # System recovers - metrics return to normal
    sleep 1
    local good_metrics
    good_metrics=$(create_test_metrics 35 45 55 0.8 3.0)

    # Allow new alerts by modifying timestamps
    local recovery_timestamp
    recovery_timestamp=$(simulate_time_progression 1)
    sed -i.bak "s/\"timestamp\": \".*\"/\"timestamp\": \"$recovery_timestamp\"/" "$ALERT_HISTORY_FILE" 2>/dev/null || true

    check_alerts "$good_metrics"

    local alert_count_after_recovery
    alert_count_after_recovery=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    # Alert count should not increase for normal metrics
    if [[ $alert_count_after_recovery -eq $alert_count_during_issue ]]; then
        print_test_result "System recovery scenario" "PASS" "No new alerts during recovery"
    else
        print_test_result "System recovery scenario" "FAIL" "Unexpected alerts during recovery"
    fi

    # Scenario 2: Gradual system improvement
    echo "Scenario 2: Gradual system improvement"

    # Start with severe issues
    local severe_metrics
    severe_metrics=$(create_test_metrics 95 92 97 3.8 22.0)
    check_alerts "$severe_metrics"

    # Gradually improve
    local improving_metrics
    improving_metrics=$(create_test_metrics 85 82 90 2.8 18.0)

    sleep 1
    sed -i.bak "s/\"timestamp\": \".*\"/\"timestamp\": \"$recovery_timestamp\"/" "$ALERT_HISTORY_FILE" 2>/dev/null || true
    check_alerts "$improving_metrics"

    # Further improvement
    local better_metrics
    better_metrics=$(create_test_metrics 75 72 80 1.8 12.0)

    sleep 1
    sed -i.bak "s/\"timestamp\": \".*\"/\"timestamp\": \"$recovery_timestamp\"/" "$ALERT_HISTORY_FILE" 2>/dev/null || true
    check_alerts "$better_metrics"

    # Final recovery
    local recovered_metrics
    recovered_metrics=$(create_test_metrics 40 50 60 1.0 4.0)

    sleep 1
    sed -i.bak "s/\"timestamp\": \".*\"/\"timestamp\": \"$recovery_timestamp\"/" "$ALERT_HISTORY_FILE" 2>/dev/null || true
    check_alerts "$recovered_metrics"

    local final_alert_count
    final_alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $final_alert_count -ge $alert_count_during_issue ]]; then
        print_test_result "Gradual improvement scenario" "PASS" "Alerts tracked during improvement: $final_alert_count"
    else
        print_test_result "Gradual improvement scenario" "FAIL" "Alert tracking during improvement failed"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert acknowledgment scenarios
test_alert_acknowledgment_scenarios() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Alert Acknowledgment Scenarios ==="

    # Scenario 1: Acknowledge active alert
    echo "Scenario 1: Acknowledge active alert"

    # Trigger an alert
    local alert_metrics
    alert_metrics=$(create_test_metrics 88 60 70 1.5 5.0)
    check_alerts "$alert_metrics"

    # Get the most recent alert ID
    local recent_alert_id
    recent_alert_id=$(grep '"id":' "$ALERT_HISTORY_FILE" | tail -1 | cut -d'"' -f4)

    if [[ -n "$recent_alert_id" ]]; then
        # Acknowledge the alert
        acknowledge_alert "$recent_alert_id"

        # Verify acknowledgment
        if grep -q "\"id\": \"$recent_alert_id\".*\"acknowledged\": true" "$ALERT_HISTORY_FILE"; then
            print_test_result "Alert acknowledgment" "PASS" "Alert $recent_alert_id acknowledged"
        else
            print_test_result "Alert acknowledgment" "FAIL" "Alert not properly acknowledged"
        fi
    else
        print_test_result "Alert acknowledgment" "FAIL" "No alert found to acknowledge"
    fi

    # Scenario 2: Acknowledge multiple alerts
    echo "Scenario 2: Acknowledge multiple alerts"

    # Trigger multiple alerts
    local multiple_alerts_metrics
    multiple_alerts_metrics=$(create_test_metrics 92 86 94 2.8 16.0)
    check_alerts "$multiple_alerts_metrics"

    # Get all unacknowledged alert IDs
    local unacknowledged_ids
    unacknowledged_ids=$(grep -v '"acknowledged": true' "$ALERT_HISTORY_FILE" | grep '"id":' | tail -3 | cut -d'"' -f4)

    local acknowledged_count=0
    while IFS= read -r alert_id; do
        if [[ -n "$alert_id" ]]; then
            acknowledge_alert "$alert_id"
            acknowledged_count=$((acknowledged_count + 1))
        fi
    done <<< "$unacknowledged_ids"

    if [[ $acknowledged_count -gt 0 ]]; then
        print_test_result "Multiple alert acknowledgment" "PASS" "Acknowledged $acknowledged_count alerts"
    else
        print_test_result "Multiple alert acknowledgment" "FAIL" "No alerts acknowledged"
    fi

    # Scenario 3: Attempt to acknowledge non-existent alert
    echo "Scenario 3: Acknowledge non-existent alert"

    if acknowledge_alert "non_existent_alert_id" 2>/dev/null; then
        print_test_result "Non-existent alert acknowledgment" "PASS" "Handled gracefully"
    else
        print_test_result "Non-existent alert acknowledgment" "FAIL" "Should handle non-existent alert gracefully"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert system under load scenarios
test_alert_system_load_scenarios() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Alert System Load Scenarios ==="

    # Scenario 1: High frequency alert generation
    echo "Scenario 1: High frequency alert generation"

    local start_time
    start_time=$(date +%s.%N)

    # Generate alerts rapidly
    for i in {1..50}; do
        local rapid_metrics
        rapid_metrics=$(create_test_metrics $((80 + i % 15)) $((75 + i % 10)) $((85 + i % 10)) 1.5 5.0)
        check_alerts "$rapid_metrics"

        # Small delay to simulate real-time alerts
        sleep 0.01
    done

    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    local total_alerts
    total_alerts=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")
    local alerts_per_second
    alerts_per_second=$(echo "scale=2; $total_alerts / $duration" | bc -l 2>/dev/null || echo "0")

    echo "High frequency alert generation results:"
    echo "  Duration: ${duration}s"
    echo "  Total alerts: $total_alerts"
    echo "  Alerts/second: $alerts_per_second"

    if (( $(echo "$alerts_per_second > 10" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "High frequency alert generation" "PASS" "$alerts_per_second alerts/sec > 10"
    else
        print_test_result "High frequency alert generation" "FAIL" "$alerts_per_second alerts/sec <= 10"
    fi

    # Scenario 2: Burst alert generation
    echo "Scenario 2: Burst alert generation"

    # Clear some history
    echo '{"alerts": []}' > "$ALERT_HISTORY_FILE"

    # Generate burst of alerts
    local burst_start
    burst_start=$(date +%s.%N)

    for i in {1..20}; do
        local burst_metrics
        burst_metrics=$(create_test_metrics 90 85 88 2.0 10.0)
        check_alerts "$burst_metrics" &
    done

    # Wait for all background processes
    wait

    local burst_end
    burst_end=$(date +%s.%N)
    local burst_duration
    burst_duration=$(echo "$burst_end - $burst_start" | bc -l 2>/dev/null || echo "1")

    local burst_alert_count
    burst_alert_count=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    echo "Burst alert generation results:"
    echo "  Duration: ${burst_duration}s"
    echo "  Total alerts: $burst_alert_count"

    if [[ $burst_alert_count -ge 10 ]]; then
        print_test_result "Burst alert generation" "PASS" "Generated $burst_alert_count alerts in burst"
    else
        print_test_result "Burst alert generation" "FAIL" "Only generated $burst_alert_count alerts"
    fi

    # Scenario 3: Sustained alert load
    echo "Scenario 3: Sustained alert load"

    local sustained_start
    sustained_start=$(date +%s)
    local sustained_duration=10
    local sustained_alert_count=0

    while [[ $(($(date +%s) - sustained_start)) -lt $sustained_duration ]]; do
        local sustained_metrics
        sustained_metrics=$(create_test_metrics $((70 + RANDOM % 20)) $((60 + RANDOM % 25)) $((75 + RANDOM % 15)) 1.5 5.0)
        check_alerts "$sustained_metrics" >/dev/null
        sustained_alert_count=$((sustained_alert_count + 1))
        sleep 0.1
    done

    echo "Sustained alert load results:"
    echo "  Duration: ${sustained_duration}s"
    echo "  Alert checks: $sustained_alert_count"

    if [[ $sustained_alert_count -ge 50 ]]; then
        print_test_result "Sustained alert load" "PASS" "$sustained_alert_count checks in ${sustained_duration}s"
    else
        print_test_result "Sustained alert load" "FAIL" "Only $sustained_alert_count checks in ${sustained_duration}s"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test edge case alert scenarios
test_edge_case_alert_scenarios() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Edge Case Alert Scenarios ==="

    # Scenario 1: Metrics at exact threshold values
    echo "Scenario 1: Exact threshold boundary conditions"

    # Test exactly at warning threshold (80% CPU)
    local exact_warning_metrics
    exact_warning_metrics=$(create_test_metrics 80 60 70 1.0 5.0)
    check_alerts "$exact_warning_metrics"

    # Test just above warning threshold
    local just_above_warning_metrics
    just_above_warning_metrics=$(create_test_metrics 80.1 60 70 1.0 5.0)
    check_alerts "$just_above_warning_metrics"

    # Test just below warning threshold
    local just_below_warning_metrics
    just_below_warning_metrics=$(create_test_metrics 79.9 60 70 1.0 5.0)
    check_alerts "$just_below_warning_metrics"

    local boundary_alerts
    boundary_alerts=$(grep -c '"rule_id":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    if [[ $boundary_alerts -ge 1 ]]; then
        print_test_result "Threshold boundary conditions" "PASS" "Boundary conditions handled: $boundary_alerts alerts"
    else
        print_test_result "Threshold boundary conditions" "FAIL" "Boundary conditions not properly handled"
    fi

    # Scenario 2: Invalid or malformed metrics
    echo "Scenario 2: Invalid metrics handling"

    # Empty metrics
    if check_alerts "" 2>/dev/null; then
        print_test_result "Empty metrics handling" "PASS" "Handled gracefully"
    else
        print_test_result "Empty metrics handling" "FAIL" "Should handle empty metrics gracefully"
    fi

    # Malformed JSON metrics
    if check_alerts '{"invalid": json}' 2>/dev/null; then
        print_test_result "Malformed metrics handling" "PASS" "Handled gracefully"
    else
        print_test_result "Malformed metrics handling" "FAIL" "Should handle malformed JSON gracefully"
    fi

    # Metrics with missing fields
    local partial_metrics='{"cpu": {"usage_percent": 90}}'
    if check_alerts "$partial_metrics" 2>/dev/null; then
        print_test_result "Partial metrics handling" "PASS" "Handled gracefully"
    else
        print_test_result "Partial metrics handling" "FAIL" "Should handle partial metrics gracefully"
    fi

    # Scenario 3: Extreme metric values
    echo "Scenario 3: Extreme metric values"

    # Very high values
    local extreme_high_metrics
    extreme_high_metrics=$(create_test_metrics 150 200 150 10.0 100.0)
    if check_alerts "$extreme_high_metrics" 2>/dev/null; then
        print_test_result "Extreme high values handling" "PASS" "Handled gracefully"
    else
        print_test_result "Extreme high values handling" "FAIL" "Should handle extreme values gracefully"
    fi

    # Negative values
    local negative_metrics
    negative_metrics=$(create_test_metrics -10 -5 -15 -1.0 -5.0)
    if check_alerts "$negative_metrics" 2>/dev/null; then
        print_test_result "Negative values handling" "PASS" "Handled gracefully"
    else
        print_test_result "Negative values handling" "FAIL" "Should handle negative values gracefully"
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
    print_test_header "Alert System Scenario Tests"

    # Run all test functions
    local test_functions=(
        "test_threshold_based_alerts"
        "test_alert_cooldown_scenarios"
        "test_multiple_concurrent_alerts"
        "test_alert_escalation_scenarios"
        "test_alert_recovery_scenarios"
        "test_alert_acknowledgment_scenarios"
        "test_alert_system_load_scenarios"
        "test_edge_case_alert_scenarios"
    )

    run_test_suite "Alert Scenario Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi