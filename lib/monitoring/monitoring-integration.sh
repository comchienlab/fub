#!/usr/bin/env bash

# FUB Monitoring Integration Module
# Main integration point for all monitoring components

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "${FUB_SCRIPT_DIR}/lib/common.sh"
    source "${FUB_SCRIPT_DIR}/lib/ui.sh"
    source "${FUB_SCRIPT_DIR}/lib/config.sh"
fi

# Source all monitoring modules
source "${FUB_SCRIPT_DIR}/lib/monitoring/system-analysis.sh"
source "${FUB_SCRIPT_DIR}/lib/monitoring/performance-monitor.sh"
source "${FUB_SCRIPT_DIR}/lib/monitoring/btop-integration.sh"
source "${FUB_SCRIPT_DIR}/lib/monitoring/alert-system.sh"
source "${FUB_SCRIPT_DIR}/lib/monitoring/history-tracking.sh"
source "${FUB_SCRIPT_DIR}/lib/monitoring/monitoring-ui.sh"

# Monitoring integration constants
readonly MONITORING_INTEGRATION_VERSION="1.0.0"
readonly MONITORING_INTEGRATION_DESCRIPTION="Comprehensive monitoring system integration"

# Monitoring configuration
MONITORING_ENABLED=${MONITORING_ENABLED:-true}
MONITORING_AUTOSTART=${MONITORING_AUTOSTART:-false}
MONITORING_LOG_LEVEL=${MONITORING_LOG_LEVEL:-INFO}

# Initialize all monitoring modules
init_monitoring_system() {
    log_info "Initializing FUB Monitoring System v$MONITORING_INTEGRATION_VERSION"

    # Check if monitoring is enabled
    if [[ "$MONITORING_ENABLED" != "true" ]]; then
        log_info "Monitoring system is disabled"
        return 0
    fi

    # Initialize all monitoring modules
    init_system_analysis
    init_performance_monitor
    init_btop_integration
    init_alert_system
    init_history_tracking
    init_monitoring_ui

    log_info "Monitoring system initialized successfully"
}

# Start pre-cleanup analysis
start_precleanup_analysis() {
    local operation_name="$1"
    local operation_id="$2"

    if [[ "$MONITORING_ENABLED" != "true" ]]; then
        return 0
    fi

    log_info "Starting pre-cleanup analysis for operation: $operation_name"

    # Perform comprehensive system analysis
    local before_analysis
    before_analysis=$(perform_system_analysis "full")

    # Save before state
    local before_file="${SYSTEM_ANALYSIS_CACHE_DIR}/${operation_id}_before.json"
    echo "$before_analysis" > "$before_file"

    # Record baseline performance
    record_metrics "$operation_name"

    # Check for immediate alerts
    local current_metrics
    current_metrics=$(get_current_metrics)
    check_alerts "$current_metrics"

    log_info "Pre-cleanup analysis completed"
    echo "$before_file"
}

# Start cleanup operation monitoring
start_cleanup_monitoring() {
    local operation_name="$1"
    local operation_id="$2"
    local monitoring_duration="${3:-300}"

    if [[ "$MONITORING_ENABLED" != "true" ]]; then
        return 0
    fi

    log_info "Starting monitoring for cleanup operation: $operation_name"

    # Start performance monitoring in background
    (
        local start_time
        start_time=$(date +%s)
        local end_time=$((start_time + monitoring_duration))

        while [[ $(date +%s) -lt $end_time ]]; do
            record_metrics "$operation_name"
            sleep 10
        done
    ) &

    local monitor_pid=$!
    echo "$monitor_pid"
}

# Complete post-cleanup analysis
complete_postcleanup_analysis() {
    local operation_name="$1"
    local operation_id="$2"
    local operation_status="$3"
    local before_file="$4"

    if [[ "$MONITORING_ENABLED" != "true" ]]; then
        return 0
    fi

    log_info "Starting post-cleanup analysis for operation: $operation_name"

    # Perform post-cleanup system analysis
    local after_analysis
    after_analysis=$(perform_system_analysis "full")

    # Save after state
    local after_file="${SYSTEM_ANALYSIS_CACHE_DIR}/${operation_id}_after.json"
    echo "$after_analysis" > "$after_file"

    # Compare before and after states
    local comparison
    comparison=$(compare_analyses "$before_file" "$after_file")

    # Calculate operation duration
    local start_time
    local end_time
    start_time=$(date -r "$before_file" +%s 2>/dev/null || date +%s)
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Create operation details
    local operation_details
    operation_details=$(cat << EOF
{
  "operation_name": "$operation_name",
  "comparison": $comparison,
  "alerts_triggered": $(check_alerts "$(get_current_metrics)")
}
EOF
)

    # Record the operation in history
    record_cleanup_operation \
        "$operation_name" \
        "$operation_id" \
        "$(cat "$before_file")" \
        "$(cat "$after_file")" \
        "$duration" \
        "$operation_status" \
        "$operation_details"

    # Generate summary report
    generate_cleanup_summary "$operation_name" "$before_file" "$after_file" "$comparison"

    log_info "Post-cleanup analysis completed"
    echo "$after_file"
}

# Generate cleanup summary report
generate_cleanup_summary() {
    local operation_name="$1"
    local before_file="$2"
    local after_file="$3"
    local comparison="$4"

    log_info "Generating cleanup summary for: $operation_name"

    # Calculate metrics
    local space_saved
    local performance_change
    space_saved=$(calculate_space_savings "$(cat "$before_file")" "$(cat "$after_file")")
    performance_change=$(calculate_performance_change "$(cat "$before_file")" "$(cat "$after_file")")

    # Display summary
    echo
    ui_separator
    echo "$(ui_set_color bold)Cleanup Operation Summary$(ui_reset_color)"
    ui_separator
    echo "Operation: $operation_name"
    echo "Space Saved: $(display_space_saved "$space_saved")"
    echo "Performance Impact: $(display_performance_change "$performance_change")"
    echo "System Score: $(get_system_score "$(cat "$after_file")")/100"
    ui_separator
    echo
}

# Display formatted space saved
display_space_saved() {
    local space_mb="$1"

    if [[ $space_mb -lt 1024 ]]; then
        echo "$(ui_set_color green)${space_mb} MB$(ui_reset_color)"
    elif [[ $space_mb -lt 1048576 ]]; then
        local space_gb
        space_gb=$(echo "$space_mb" | awk '{printf "%.1f", $1/1024}')
        echo "$(ui_set_color green)${space_gb} GB$(ui_reset_color)"
    else
        echo "$(ui_set_color green)More than 1 TB$(ui_reset_color)"
    fi
}

# Display formatted performance change
display_performance_change() {
    local change="$1"

    if (( $(echo "$change > 5" | bc -l 2>/dev/null || echo "0") )); then
        echo "$(ui_set_color green)+${change}% improvement$(ui_reset_color)"
    elif (( $(echo "$change < -5" | bc -l 2>/dev/null || echo "0") )); then
        echo "$(ui_set_color red)${change}% degradation$(ui_reset_color)"
    else
        echo "$(ui_set_color dim)No significant change$(ui_reset_color)"
    fi
}

# Get monitoring status
get_monitoring_status() {
    local btop_status
    btop_status=$(get_btop_status)

    local current_metrics
    current_metrics=$(get_current_metrics)

    local alert_summary
    alert_summary=$(get_alert_summary 24)

    local history_summary
    history_summary=$(get_history_summary)

    cat << EOF
{
  "monitoring_enabled": $MONITORING_ENABLED,
  "btop_integration": $btop_status,
  "current_metrics": $current_metrics,
  "alert_summary": $alert_summary,
  "history_summary": $history_summary,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Start interactive monitoring
start_interactive_monitoring() {
    if [[ "$MONITORING_ENABLED" != "true" ]]; then
        log_error "Monitoring system is disabled"
        return 1
    fi

    display_monitoring_menu
}

# Generate comprehensive monitoring report
generate_monitoring_report() {
    local output_file="$1"

    log_info "Generating comprehensive monitoring report"

    local report
    report=$(cat << EOF
{
  "report_type": "comprehensive_monitoring",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "system_analysis": $(perform_system_analysis "full"),
  "monitoring_status": $(get_monitoring_status),
  "performance_trends": $(get_performance_trends 7),
  "cleanup_history": $(get_cleanup_history 30),
  "alert_summary": $(get_alert_summary 24),
  "maintenance_suggestions": $(generate_maintenance_suggestions)
}
EOF
)

    if [[ -n "$output_file" ]]; then
        echo "$report" > "$output_file"
        log_info "Monitoring report saved to $output_file"
    else
        echo "$report"
    fi
}

# Cleanup monitoring data
cleanup_monitoring_data() {
    local days="${1:-$HISTORY_RETENTION_DAYS}"

    log_info "Cleaning up monitoring data older than $days days"

    # Clean up old history
    cleanup_old_history "$days"

    # Clean up old alerts
    clear_old_alerts "$days"

    # Clean up old analysis files
    find "$SYSTEM_ANALYSIS_CACHE_DIR" -name "*.json" -mtime +$days -delete 2>/dev/null || true
    find "$PERFORMANCE_MONITOR_CACHE_DIR" -name "*.json" -mtime +$days -delete 2>/dev/null || true
    find "$BTOP_CACHE_DIR" -name "*" -mtime +$days -delete 2>/dev/null || true

    log_info "Monitoring data cleanup completed"
}

# Test monitoring system
test_monitoring_system() {
    log_info "Testing monitoring system components"

    local test_passed=0
    local test_failed=0

    # Test system analysis
    if perform_system_analysis "test" >/dev/null 2>&1; then
        log_debug "✓ System analysis test passed"
        test_passed=$((test_passed + 1))
    else
        log_error "✗ System analysis test failed"
        test_failed=$((test_failed + 1))
    fi

    # Test performance monitor
    if get_current_metrics >/dev/null 2>&1; then
        log_debug "✓ Performance monitor test passed"
        test_passed=$((test_passed + 1))
    else
        log_error "✗ Performance monitor test failed"
        test_failed=$((test_failed + 1))
    fi

    # Test btop integration
    if get_btop_status >/dev/null 2>&1; then
        log_debug "✓ Btop integration test passed"
        test_passed=$((test_passed + 1))
    else
        log_error "✗ Btop integration test failed"
        test_failed=$((test_failed + 1))
    fi

    # Test alert system
    if check_performance_alerts "$(get_current_metrics)" >/dev/null 2>&1; then
        log_debug "✓ Alert system test passed"
        test_passed=$((test_passed + 1))
    else
        log_error "✗ Alert system test failed"
        test_failed=$((test_failed + 1))
    fi

    # Test history tracking
    if get_history_summary >/dev/null 2>&1; then
        log_debug "✓ History tracking test passed"
        test_passed=$((test_passed + 1))
    else
        log_error "✗ History tracking test failed"
        test_failed=$((test_failed + 1))
    fi

    log_info "Monitoring system test completed: $test_passed passed, $test_failed failed"

    [[ $test_failed -eq 0 ]]
}

# Show monitoring help
show_monitoring_help() {
    cat << 'EOF'
FUB Monitoring System Help

The monitoring system provides comprehensive system performance analysis and cleanup impact tracking.

Key Features:
- Real-time system monitoring
- Pre/post cleanup analysis
- Performance trend analysis
- Intelligent alert system
- Historical cleanup tracking
- btop integration (when available)

Usage Examples:

# Start interactive monitoring
fub monitor

# Pre-cleanup analysis
start_precleanup_analysis <operation_name> <operation_id>

# Post-cleanup analysis
complete_postcleanup_analysis <operation_name> <operation_id> <status> <before_file>

# Generate monitoring report
generate_monitoring_report <output_file>

# Test monitoring system
test_monitoring_system

# Cleanup old data
cleanup_monitoring_data [days]

Configuration:
- MONITORING_ENABLED: Enable/disable monitoring (default: true)
- MONITORING_LOG_LEVEL: Logging level (default: INFO)
- ALERT_*_THRESHOLD: Alert thresholds for CPU, memory, disk
- HISTORY_*_DAYS: Data retention settings

Files:
- ~/.cache/fub/monitoring/: Monitoring cache directory
- ~/.cache/fub/alerts/: Alert history and configuration
- ~/.cache/fub/history/: Cleanup operation history

For more information, see the individual module documentation.
EOF
}

# Initialize monitoring integration
init_monitoring_system