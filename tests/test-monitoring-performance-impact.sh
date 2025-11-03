#!/usr/bin/env bash

# FUB Monitoring Performance Impact Validation Tests
# Tests to validate that monitoring doesn't significantly impact system performance

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="monitoring-performance-impact"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Source all monitoring modules
source "${TEST_ROOT_DIR}/lib/monitoring/system-analysis.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/performance-monitor.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/history-tracking.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/alert-system.sh"
source "${TEST_ROOT_DIR}/lib/monitoring/btop-integration.sh"

# Performance test utilities
measure_command_performance() {
    local command="$1"
    local iterations="${2:-10}"
    local description="${3:-Command}"

    local total_time=0
    local max_time=0
    local min_time=999999

    echo "Measuring performance of: $description"
    echo "Running $iterations iterations..."

    for ((i=1; i<=iterations; i++)); do
        local start_time
        start_time=$(date +%s.%N)

        eval "$command" >/dev/null 2>&1

        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.001")

        total_time=$(echo "$total_time + $duration" | bc -l 2>/dev/null || echo "$total_time")

        # Update min/max
        if (( $(echo "$duration > $max_time" | bc -l 2>/dev/null || echo "0") )); then
            max_time=$duration
        fi

        if (( $(echo "$duration < $min_time" | bc -l 2>/dev/null || echo "1") )); then
            min_time=$duration
        fi

        echo -n "."
    done

    echo

    local avg_time
    avg_time=$(echo "scale=6; $total_time / $iterations" | bc -l 2>/dev/null || echo "0")

    cat << EOF
Performance Results for $description:
======================================
Iterations: $iterations
Total Time: ${total_time}s
Average Time: ${avg_time}s
Min Time: ${min_time}s
Max Time: ${max_time}s

EOF
}

measure_memory_usage() {
    local command="$1"
    local description="${2:-Command}"

    echo "Measuring memory usage for: $description"

    # Get baseline memory
    local baseline_memory
    baseline_memory=$(ps -o rss= -p $$ | tr -d ' ')

    # Run command in background and measure memory
    eval "$command" >/dev/null 2>&1 &
    local cmd_pid=$!

    # Let it run briefly
    sleep 2

    # Measure memory usage
    local peak_memory
    peak_memory=$(ps -o rss= -p $$ | tr -d ' ')

    # Clean up
    kill "$cmd_pid" 2>/dev/null || true
    wait "$cmd_pid" 2>/dev/null || true

    local memory_increase=$((peak_memory - baseline_memory))

    cat << EOF
Memory Usage Results for $description:
=====================================
Baseline Memory: ${baseline_memory}KB
Peak Memory: ${peak_memory}KB
Memory Increase: ${memory_increase}KB

EOF

    echo "$memory_increase"
}

benchmark_system_resources() {
    local test_name="$1"
    local duration="${2:-10}"

    echo "Benchmarking system resources for: $test_name"
    echo "Duration: ${duration}s"

    # Collect baseline metrics
    local baseline_cpu
    baseline_cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
    local baseline_memory
    baseline_memory=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}' 2>/dev/null || echo "0")

    echo "Baseline CPU: ${baseline_cpu}%"
    echo "Baseline Memory: ${baseline_memory}%"

    # Monitor during test
    local max_cpu="$baseline_cpu"
    local max_memory="$baseline_memory"
    local start_time
    start_time=$(date +%s)

    while [[ $(($(date +%s) - start_time)) -lt $duration ]]; do
        local current_cpu
        current_cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
        local current_memory
        current_memory=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}' 2>/dev/null || echo "0")

        if (( $(echo "$current_cpu > $max_cpu" | bc -l 2>/dev/null || echo "0") )); then
            max_cpu=$current_cpu
        fi

        if (( $(echo "$current_memory > $max_memory" | bc -l 2>/dev/null || echo "0") )); then
            max_memory=$current_memory
        fi

        sleep 1
    done

    local cpu_increase
    cpu_increase=$(echo "$max_cpu - $baseline_cpu" | bc -l 2>/dev/null || echo "0")
    local memory_increase
    memory_increase=$(echo "$max_memory - $baseline_memory" | bc -l 2>/dev/null || echo "0")

    cat << EOF
Resource Impact Results for $test_name:
=======================================
Duration: ${duration}s
Baseline CPU: ${baseline_cpu}%
Peak CPU: ${max_cpu}%
CPU Increase: ${cpu_increase}%
Baseline Memory: ${baseline_memory}%
Peak Memory: ${max_memory}%
Memory Increase: ${memory_increase}%

EOF
}

# =============================================================================
# PERFORMANCE IMPACT VALIDATION TESTS
# =============================================================================

# Test system analysis performance impact
test_system_analysis_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    echo "=== System Analysis Performance Impact Test ==="

    # Test individual components
    measure_command_performance "capture_system_resources" 5 "System Resources Capture"
    measure_command_performance "analyze_package_state" 3 "Package State Analysis"
    measure_command_performance "analyze_service_status" 3 "Service Status Analysis"
    measure_command_performance "analyze_dev_environment" 3 "Development Environment Analysis"

    # Test full analysis
    local analysis_perf
    analysis_perf=$(measure_command_performance "perform_system_analysis quick" 5 "Full System Analysis")

    # Memory usage test
    local analysis_memory
    analysis_memory=$(measure_memory_usage "perform_system_analysis full" "Full System Analysis Memory")

    # Resource impact test
    benchmark_system_resources "System Analysis Full Run" 10

    # Validate performance criteria
    local avg_time
    avg_time=$(echo "$analysis_perf" | grep "Average Time:" | cut -d: -f2 | tr -d ' ')

    if (( $(echo "$avg_time < 2.0" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "System analysis performance criteria" "PASS" "Average time: ${avg_time}s < 2.0s"
    else
        print_test_result "System analysis performance criteria" "FAIL" "Average time: ${avg_time}s >= 2.0s"
    fi

    if [[ $analysis_memory -lt 10240 ]]; then  # Less than 10MB
        print_test_result "System analysis memory criteria" "PASS" "Memory increase: ${analysis_memory}KB < 10MB"
    else
        print_test_result "System analysis memory criteria" "FAIL" "Memory increase: ${analysis_memory}KB >= 10MB"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance monitoring overhead
test_performance_monitoring_overhead() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_performance_monitor

    echo "=== Performance Monitoring Overhead Test ==="

    # Test metrics collection overhead
    measure_command_performance "get_current_metrics" 10 "Current Metrics Collection"

    # Test recording overhead
    measure_command_performance "record_metrics overhead_test" 10 "Metrics Recording"

    # Test trends calculation overhead
    measure_command_performance "get_performance_trends 24" 5 "Performance Trends Calculation"

    # Test summary generation overhead
    measure_command_performance "get_performance_summary 1" 5 "Performance Summary Generation"

    # Memory usage for continuous monitoring
    local monitoring_memory
    monitoring_memory=$(measure_memory_usage "
    for i in {1..20}; do
        record_metrics 'continuous_test_\$i'
        sleep 0.1
    done
" "Continuous Monitoring Memory")

    if [[ $monitoring_memory -lt 20480 ]]; then  # Less than 20MB
        print_test_result "Continuous monitoring memory criteria" "PASS" "Memory: ${monitoring_memory}KB < 20MB"
    else
        print_test_result "Continuous monitoring memory criteria" "FAIL" "Memory: ${monitoring_memory}KB >= 20MB"
    fi

    # Resource impact during monitoring
    benchmark_system_resources "Performance Monitoring Active" 15

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test alert system performance impact
test_alert_system_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_alert_system

    echo "=== Alert System Performance Impact Test ==="

    # Create test metrics that will trigger alerts
    local high_metrics='{
        "cpu": {"usage_percent": 90.0},
        "memory": {"usage_percent": 85.0},
        "disk": {"usage_percent": 88.0}
    }'

    # Test alert checking performance
    measure_command_performance "check_alerts '$high_metrics'" 10 "Alert Checking"

    # Test alert creation performance
    measure_command_performance "create_alert test_rule 'Test Alert' warning 'Test message' 'Test recommendation' 85 test_metric" 10 "Alert Creation"

    # Test alert saving performance
    local test_alert
    test_alert=$(create_alert "perf_test" "Performance Test" "warning" "Test message" "Test recommendation" "75" "test_metric")
    measure_command_performance "save_alert '\$test_alert'" 10 "Alert Saving"

    # Test summary generation performance
    measure_command_performance "get_alert_summary 24" 5 "Alert Summary Generation"

    # Memory usage with many alerts
    local alerts_memory
    alerts_memory=$(measure_memory_usage "
    for i in {1..50}; do
        local alert=\$(create_alert 'perf_test_\$i' 'Performance Test \$i' warning 'Test message \$i' 'Test recommendation \$i' 75 test_metric)
        save_alert \"\$alert\"
    done
" "Multiple Alerts Memory")

    if [[ $alerts_memory -lt 5120 ]]; then  # Less than 5MB
        print_test_result "Multiple alerts memory criteria" "PASS" "Memory: ${alerts_memory}KB < 5MB"
    else
        print_test_result "Multiple alerts memory criteria" "FAIL" "Memory: ${alerts_memory}KB >= 5MB"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test history tracking performance impact
test_history_tracking_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_history_tracking

    echo "=== History Tracking Performance Impact Test ==="

    # Test operation recording performance
    local before_state='{"system_resources": {"cpu": {"usage_percent": 60.0}, "disk": {"used": "10G"}}}'
    local after_state='{"system_resources": {"cpu": {"usage_percent": 40.0}, "disk": {"used": "8G"}}}'
    local details='{"test": "performance_test"}'

    measure_command_performance "record_cleanup_operation test_op test_id '$before_state' '$after_state' 60 success '$details'" 10 "Operation Recording"

    # Test performance snapshot recording
    local metrics='{"cpu": {"usage_percent": 45.0}}'
    measure_command_performance "record_performance_snapshot test_op '2023-01-01T12:00:00Z' '\$metrics'" 10 "Performance Snapshot Recording"

    # Test history retrieval performance
    measure_command_performance "get_cleanup_history 30" 5 "History Retrieval"

    # Test summary generation performance
    measure_command_performance "get_history_summary" 5 "History Summary Generation"

    # Test performance with large history
    local large_history_memory
    large_history_memory=$(measure_memory_usage "
    for i in {1..100}; do
        record_cleanup_operation 'large_test_\$i' 'large_id_\$i' '$before_state' '$after_state' 60 success 'details_\$i'
    done
    update_history_summary
" "Large History Memory")

    if [[ $large_history_memory -lt 10240 ]]; then  # Less than 10MB
        print_test_result "Large history memory criteria" "PASS" "Memory: ${large_history_memory}KB < 10MB"
    else
        print_test_result "Large history memory criteria" "FAIL" "Memory: ${large_history_memory}KB >= 10MB"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test btop integration performance impact
test_btop_integration_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_btop_integration

    echo "=== Btop Integration Performance Impact Test ==="

    # Test configuration generation performance
    measure_command_performance "generate_btop_config" 5 "Btop Configuration Generation"

    # Test data capture performance (fallback mode since btop might not be available)
    measure_command_performance "capture_fallback_data 5" 5 "Fallback Data Capture"

    # Test status checking performance
    measure_command_performance "get_btop_status" 10 "Btop Status Check"

    # Test report generation performance
    local test_data_file="${TEST_CACHE_DIR}/test-data.json"
    echo '{"test": "data"}' > "$test_data_file"
    measure_command_performance "generate_btop_report '$test_data_file'" 5 "Btop Report Generation"

    # Memory usage during data capture
    local btop_memory
    btop_memory=$(measure_memory_usage "capture_fallback_data 10 '$test_data_file'" "Btop Data Capture Memory")

    if [[ $btop_memory -lt 5120 ]]; then  # Less than 5MB
        print_test_result "Btop data capture memory criteria" "PASS" "Memory: ${btop_memory}KB < 5MB"
    else
        print_test_result "Btop data capture memory criteria" "FAIL" "Memory: ${btop_memory}KB >= 5MB"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test concurrent monitoring performance
test_concurrent_monitoring_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize all systems
    init_system_analysis
    init_performance_monitor
    init_alert_system
    init_history_tracking

    echo "=== Concurrent Monitoring Performance Test ==="

    # Test running multiple monitoring operations concurrently
    echo "Testing concurrent monitoring operations..."

    local start_time
    start_time=$(date +%s.%N)

    # Start multiple background monitoring operations
    (
        for i in {1..5}; do
            perform_system_analysis "concurrent_$i" >/dev/null
        done
    ) &
    local analysis_pid=$!

    (
        for i in {1..5}; do
            record_metrics "concurrent_metrics_$i" >/dev/null
        done
    ) &
    local metrics_pid=$!

    (
        for i in {1..3}; do
            local test_alert='{"test": "concurrent_alert_'$i'"}'
            save_alert "$test_alert" >/dev/null
        done
    ) &
    local alerts_pid=$!

    # Wait for all to complete
    wait "$analysis_pid" "$metrics_pid" "$alerts_pid"

    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    echo "Concurrent operations completed in: ${duration}s"

    if (( $(echo "$duration < 10.0" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "Concurrent monitoring performance" "PASS" "Completed in ${duration}s < 10s"
    else
        print_test_result "Concurrent monitoring performance" "FAIL" "Too slow: ${duration}s >= 10s"
    fi

    # Memory usage during concurrent operations
    local concurrent_memory
    concurrent_memory=$(measure_memory_usage "
    # Simulate concurrent operations
    (
        for i in {1..3}; do
            perform_system_analysis 'concurrent_mem_\$i' >/dev/null
        done
    ) &
    local p1=\$!

    (
        for i in {1..3}; do
            record_metrics 'concurrent_mem_metrics_\$i' >/dev/null
        done
    ) &
    local p2=\$!

    (
        for i in {1..3}; do
            local alert=\$(create_alert 'concurrent_mem_alert_\$i' 'Test' warning 'Test' 'Test' 75 test_metric)
            save_alert \"\$alert\" >/dev/null
        done
    ) &
    local p3=\$!

    wait \$p1 \$p2 \$p3
" "Concurrent Operations Memory")

    if [[ $concurrent_memory -lt 15360 ]]; then  # Less than 15MB
        print_test_result "Concurrent operations memory criteria" "PASS" "Memory: ${concurrent_memory}KB < 15MB"
    else
        print_test_result "Concurrent operations memory criteria" "FAIL" "Memory: ${concurrent_memory}KB >= 15MB"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test long-running monitoring performance
test_long_running_monitoring_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize monitoring systems
    init_performance_monitor
    init_alert_system

    echo "=== Long-Running Monitoring Performance Test ==="

    # Simulate long-running monitoring with periodic checks
    local monitoring_duration=30
    local check_interval=2

    echo "Running monitoring for ${monitoring_duration}s with ${check_interval}s intervals..."

    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + monitoring_duration))

    local operation_count=0

    while [[ $(date +%s) -lt $end_time ]]; do
        # Perform monitoring operations
        record_metrics "long_running_test_$operation_count" >/dev/null

        local current_metrics
        current_metrics=$(get_current_metrics)
        check_alerts "$current_metrics" >/dev/null

        operation_count=$((operation_count + 1))
        sleep "$check_interval"
    done

    local actual_duration
    actual_duration=$(($(date +%s) - start_time))

    echo "Long-running monitoring completed:"
    echo "  Duration: ${actual_duration}s (target: ${monitoring_duration}s)"
    echo "  Operations performed: $operation_count"
    echo "  Average interval: $(echo "scale=2; $actual_duration / $operation_count" | bc -l)s"

    # Check performance trends for long-running session
    local trends
    trends=$(get_performance_trends 1)

    if echo "$trends" | grep -q "averages\|peaks"; then
        print_test_result "Long-running monitoring data collection" "PASS" "Performance trends available"
    else
        print_test_result "Long-running monitoring data collection" "FAIL" "No performance trends collected"
    fi

    # Test system hasn't degraded significantly
    local final_metrics
    final_metrics=$(get_current_metrics)
    local final_cpu
    final_cpu=$(echo "$final_metrics" | grep '"usage_percent":' | head -1 | cut -d: -f2 | tr -d ' ')

    if [[ -n "$final_cpu" ]] && (( $(echo "$final_cpu < 95" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "Long-running monitoring system stability" "PASS" "Final CPU: ${final_cpu}% < 95%"
    else
        print_test_result "Long-running monitoring system stability" "FAIL" "High CPU usage: ${final_cpu}%"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test monitoring system scalability
test_monitoring_scalability() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Initialize monitoring systems
    init_performance_monitor
    init_history_tracking
    init_alert_system

    echo "=== Monitoring System Scalability Test ==="

    # Test with increasing load
    local test_sizes=(10 50 100 200)

    for size in "${test_sizes[@]}"; do
        echo "Testing with $size operations..."

        local start_time
        start_time=$(date +%s.%N)

        # Perform operations
        for ((i=1; i<=size; i++)); do
            record_metrics "scalability_test_$i" >/dev/null

            if (( i % 10 == 0 )); then
                local metrics
                metrics=$(get_current_metrics)
                check_alerts "$metrics" >/dev/null
            fi
        done

        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

        local ops_per_second
        ops_per_second=$(echo "scale=2; $size / $duration" | bc -l 2>/dev/null || echo "0")

        echo "  Size: $size operations"
        echo "  Duration: ${duration}s"
        echo "  Operations/second: $ops_per_second"

        # Performance should not degrade significantly
        if (( $(echo "$ops_per_second > 10" | bc -l 2>/dev/null || echo "0") )); then
            print_test_result "Scalability test ($size operations)" "PASS" "$ops_per_second ops/sec > 10"
        else
            print_test_result "Scalability test ($size operations)" "FAIL" "$ops_per_second ops/sec <= 10"
        fi
    done

    # Test memory scaling
    echo "Testing memory scaling with large dataset..."

    local memory_start
    memory_start=$(ps -o rss= -p $$ | tr -d ' ')

    # Create large dataset
    for ((i=1; i<=500; i++)); do
        record_metrics "memory_scalability_$i" >/dev/null
    done

    local memory_end
    memory_end=$(ps -o rss= -p $$ | tr -d ' ')
    local memory_increase=$((memory_end - memory_start))

    echo "Memory increase for 500 operations: ${memory_increase}KB"

    if [[ $memory_increase -lt 10240 ]]; then  # Less than 10MB
        print_test_result "Memory scalability criteria" "PASS" "${memory_increase}KB < 10MB for 500 operations"
    else
        print_test_result "Memory scalability criteria" "FAIL" "${memory_increase}KB >= 10MB for 500 operations"
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
    print_test_header "Monitoring Performance Impact Validation Tests"

    # Run all test functions
    local test_functions=(
        "test_system_analysis_performance"
        "test_performance_monitoring_overhead"
        "test_alert_system_performance"
        "test_history_tracking_performance"
        "test_btop_integration_performance"
        "test_concurrent_monitoring_performance"
        "test_long_running_monitoring_performance"
        "test_monitoring_scalability"
    )

    run_test_suite "Performance Impact Validation Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi