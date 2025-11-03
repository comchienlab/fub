#!/usr/bin/env bash

# FUB System Analysis Module Unit Tests
# Comprehensive unit tests for the system analysis module

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test module setup
readonly TEST_MODULE_NAME="system-analysis"
readonly TEST_CACHE_DIR="/tmp/fub-test-${TEST_MODULE_NAME}-$$"

# Source the module under test
source "${TEST_ROOT_DIR}/lib/monitoring/system-analysis.sh"

# =============================================================================
# UNIT TESTS FOR SYSTEM ANALYSIS MODULE
# =============================================================================

# Test module initialization
test_init_system_analysis() {
    # Setup test environment
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization
    init_system_analysis

    # Verify cache directory was created
    assert_dir_exists "$SYSTEM_ANALYSIS_CACHE_DIR" "System analysis cache directory created"

    # Verify state file location is correct
    assert_equals "$SYSTEM_ANALYSIS_STATE_FILE" "${TEST_CACHE_DIR}/system-analysis/current-state.json" "State file path correct"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test system resources capture
test_capture_system_resources() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Capture system resources
    local resources
    resources=$(capture_system_resources)

    # Verify JSON structure
    assert_contains "$resources" "timestamp" "Resources output contains timestamp"
    assert_contains "$resources" "cpu" "Resources output contains CPU section"
    assert_contains "$resources" "memory" "Resources output contains memory section"
    assert_contains "$resources" "disk" "Resources output contains disk section"
    assert_contains "$resources" "network" "Resources output contains network section"

    # Verify CPU metrics
    assert_contains "$resources" "usage_percent" "CPU usage percent present"
    assert_contains "$resources" "load_average" "Load average present"
    assert_contains "$resources" "processes" "Process count present"

    # Verify memory metrics
    assert_contains "$resources" "total_mb" "Memory total present"
    assert_contains "$resources" "used_mb" "Memory used present"
    assert_contains "$resources" "free_mb" "Memory free present"
    assert_contains "$resources" "usage_percent" "Memory usage percent present"

    # Verify disk metrics
    assert_contains "$resources" "total" "Disk total present"
    assert_contains "$resources" "used" "Disk used present"
    assert_contains "$resources" "available" "Disk available present"
    assert_contains "$resources" "usage_percent" "Disk usage percent present"

    # Verify network metrics
    assert_contains "$resources" "rx_bytes" "Network RX bytes present"
    assert_contains "$resources" "tx_bytes" "Network TX bytes present"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test package state analysis
test_analyze_package_state() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Analyze package state
    local packages
    packages=$(analyze_package_state)

    # Verify JSON structure
    assert_contains "$packages" "timestamp" "Package analysis contains timestamp"
    assert_contains "$packages" "packages" "Package analysis contains packages section"

    # Verify package manager sections
    assert_contains "$packages" "apt" "APT section present"
    assert_contains "$packages" "snap" "Snap section present"
    assert_contains "$packages" "flatpak" "Flatpak section present"
    assert_contains "$packages" "npm" "NPM section present"

    # Verify APT metrics
    assert_contains "$packages" "installed" "APT installed count present"
    assert_contains "$packages" "updates_available" "APT updates available present"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test service status analysis
test_analyze_service_status() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Analyze service status
    local services
    services=$(analyze_service_status)

    # Verify JSON structure
    assert_contains "$services" "timestamp" "Service analysis contains timestamp"
    assert_contains "$services" "services" "Service analysis contains services section"

    # Verify service metrics
    assert_contains "$services" "active" "Active services count present"
    assert_contains "$services" "failed" "Failed services count present"
    assert_contains "$services" "enabled" "Enabled services count present"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test development environment analysis
test_analyze_dev_environment() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Analyze development environment
    local dev_env
    dev_env=$(analyze_dev_environment)

    # Verify JSON structure
    assert_contains "$dev_env" "timestamp" "Dev environment analysis contains timestamp"
    assert_contains "$dev_env" "development" "Dev environment analysis contains development section"

    # Verify development metrics
    assert_contains "$dev_env" "docker_running" "Docker running status present"
    assert_contains "$dev_env" "container_count" "Container count present"
    assert_contains "$dev_env" "project_directories" "Project directories count present"
    assert_contains "$dev_env" "tools" "Development tools section present"

    # Verify tools section
    assert_contains "$dev_env" "git" "Git tool status present"
    assert_contains "$dev_env" "node" "Node tool status present"
    assert_contains "$dev_env" "python" "Python tool status present"
    assert_contains "$dev_env" "docker" "Docker tool status present"
    assert_contains "$dev_env" "vscode" "VSCode tool status present"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test comprehensive system analysis
test_perform_system_analysis() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Test full analysis
    local analysis
    analysis=$(perform_system_analysis "full")

    # Verify comprehensive structure
    assert_contains "$analysis" "timestamp" "Full analysis contains timestamp"
    assert_contains "$analysis" "analysis_type" "Full analysis contains analysis type"
    assert_contains "$analysis" "system_resources" "Full analysis contains system resources"
    assert_contains "$analysis" "package_state" "Full analysis contains package state"
    assert_contains "$analysis" "service_status" "Full analysis contains service status"
    assert_contains "$analysis" "development_environment" "Full analysis contains development environment"

    # Verify analysis type
    assert_contains "$analysis" "\"full\"" "Analysis type is correctly set to full"

    # Test with output file
    local output_file="${TEST_CACHE_DIR}/test-analysis.json"
    perform_system_analysis "quick" "$output_file"

    assert_file_exists "$output_file" "Analysis output file created"
    assert_contains "$(cat "$output_file")" "\"quick\"" "Output file contains correct analysis type"

    # Verify state file was created
    assert_file_exists "$SYSTEM_ANALYSIS_STATE_FILE" "State file created"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test system score calculation
test_get_system_score() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Test with no analysis file (should return default score)
    local default_score
    default_score=$(get_system_score "/nonexistent/file.json")
    assert_equals "$default_score" "50" "Default system score is 50"

    # Create a mock analysis file
    local mock_analysis="${TEST_CACHE_DIR}/mock-analysis.json"
    cat > "$mock_analysis" << 'EOF'
{
  "system_resources": {
    "cpu": {"usage_percent": 30.5},
    "memory": {"usage_percent": 45.2},
    "disk": {"usage_percent": 60.0}
  },
  "service_status": {
    "services": {"failed": 0}
  }
}
EOF

    local score
    score=$(get_system_score "$mock_analysis")

    # Score should be between 0 and 100
    if [[ $score -ge 0 && $score -le 100 ]]; then
        print_test_result "System score within valid range" "PASS"
    else
        print_test_result "System score within valid range" "FAIL" "Score $score is not between 0 and 100"
    fi

    # Test with failed services
    cat > "$mock_analysis" << 'EOF'
{
  "system_resources": {
    "cpu": {"usage_percent": 30.5},
    "memory": {"usage_percent": 45.2},
    "disk": {"usage_percent": 60.0}
  },
  "service_status": {
    "services": {"failed": 5}
  }
}
EOF

    local score_with_failures
    score_with_failures=$(get_system_score "$mock_analysis")

    # Score should be lower with failed services
    if [[ $score_with_failures -lt $score ]]; then
        print_test_result "System score lower with failed services" "PASS"
    else
        print_test_result "System score lower with failed services" "FAIL" "Score $score_with_failures should be less than $score"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test analysis comparison
test_compare_analyses() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Create mock before and after analysis files
    local before_file="${TEST_CACHE_DIR}/before.json"
    local after_file="${TEST_CACHE_DIR}/after.json"

    # Before analysis
    cat > "$before_file" << 'EOF'
{
  "system_resources": {
    "cpu": {"usage_percent": 50.0},
    "memory": {"usage_percent": 60.0},
    "disk": {"usage_percent": 70.0}
  }
}
EOF

    # After analysis (improved metrics)
    cat > "$after_file" << 'EOF'
{
  "system_resources": {
    "cpu": {"usage_percent": 30.0},
    "memory": {"usage_percent": 45.0},
    "disk": {"usage_percent": 65.0}
  }
}
EOF

    # Compare analyses
    local comparison
    comparison=$(compare_analyses "$before_file" "$after_file")

    # Verify comparison structure
    assert_contains "$comparison" "comparison" "Comparison output contains comparison section"
    assert_contains "$comparison" "cpu_change_percent" "Comparison contains CPU change"
    assert_contains "$comparison" "memory_change_percent" "Comparison contains memory change"
    assert_contains "$comparison" "disk_change_percent" "Comparison contains disk change"

    # Verify change values (should be negative indicating improvement)
    assert_contains "$comparison" "-" "CPU change is negative (improvement)"
    assert_contains "$comparison" "-" "Memory change is negative (improvement)"
    assert_contains "$comparison" "-" "Disk change is negative (improvement)"

    # Test error handling with missing files
    if compare_analyses "/nonexistent/before.json" "$after_file" 2>/dev/null; then
        print_test_result "Error handling for missing before file" "FAIL" "Should have failed with missing file"
    else
        print_test_result "Error handling for missing before file" "PASS"
    fi

    if compare_analyses "$before_file" "/nonexistent/after.json" 2>/dev/null; then
        print_test_result "Error handling for missing after file" "FAIL" "Should have failed with missing file"
    else
        print_test_result "Error handling for missing after file" "PASS"
    fi

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test error handling and edge cases
test_error_handling() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"

    # Test initialization with read-only directory (should handle gracefully)
    local readonly_dir="${TEST_CACHE_DIR}/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir" 2>/dev/null || true

    export FUB_CACHE_DIR="$readonly_dir"
    if init_system_analysis 2>/dev/null; then
        print_test_result "Initialization with read-only directory" "PASS" "Handled gracefully"
    else
        print_test_result "Initialization with read-only directory" "FAIL" "Should handle read-only directory gracefully"
    fi

    # Restore permissions for cleanup
    chmod 755 "$readonly_dir" 2>/dev/null || true

    # Test with missing system commands (mock scenario)
    local original_path="$PATH"
    export PATH="/nonexistent:$PATH"

    # Should still return valid JSON structure even if commands fail
    local resources
    resources=$(capture_system_resources)
    assert_contains "$resources" "timestamp" "Resources capture works with missing commands"
    assert_contains "$resources" "cpu" "CPU section present even with missing commands"

    # Restore PATH
    export PATH="$original_path"

    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
}

# Test performance and resource usage
test_performance() {
    export FUB_CACHE_DIR="$TEST_CACHE_DIR"
    init_system_analysis

    # Test that functions complete in reasonable time
    local start_time
    local end_time
    local duration

    # Test system resources capture performance
    start_time=$(date +%s.%N)
    capture_system_resources > /dev/null
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    # Should complete within 5 seconds
    if (( $(echo "$duration < 5" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "System resources capture performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "System resources capture performance" "FAIL" "Took too long: ${duration}s"
    fi

    # Test full analysis performance
    start_time=$(date +%s.%N)
    perform_system_analysis "full" > /dev/null
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    # Should complete within 10 seconds
    if (( $(echo "$duration < 10" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "Full system analysis performance" "PASS" "Completed in ${duration}s"
    else
        print_test_result "Full system analysis performance" "FAIL" "Took too long: ${duration}s"
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
    print_test_header "System Analysis Module Unit Tests"

    # Run all test functions
    local test_functions=(
        "test_init_system_analysis"
        "test_capture_system_resources"
        "test_analyze_package_state"
        "test_analyze_service_status"
        "test_analyze_dev_environment"
        "test_perform_system_analysis"
        "test_get_system_score"
        "test_compare_analyses"
        "test_error_handling"
        "test_performance"
    )

    run_test_suite "System Analysis Tests" "${test_functions[@]}"

    # Print test summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test
fi