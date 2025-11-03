#!/usr/bin/env bash

# FUB Comprehensive Monitoring Test Suite
# Master test runner for all monitoring system tests

set -euo pipefail

# Test framework and source dependencies
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${TEST_ROOT_DIR}/tests/test-framework.sh"
source "${TEST_ROOT_DIR}/lib/common.sh"

# Test configuration
readonly TEST_SUITE_NAME="FUB Monitoring System Comprehensive Tests"
readonly TEST_SUITE_VERSION="1.0.0"
readonly TEST_RESULTS_DIR="${TEST_ROOT_DIR}/test-results/monitoring-$(date +%Y%m%d_%H%M%S)"

# Test files and categories
declare -A TEST_CATEGORIES=(
    ["unit"]="Unit Tests"
    ["integration"]="Integration Tests"
    ["performance"]="Performance Tests"
    ["scenarios"]="Scenario Tests"
)

declare -A TEST_FILES=(
    # Unit tests
    ["unit_system_analysis"]="test-monitoring-system-analysis.sh"
    ["unit_performance_monitor"]="test-monitoring-performance-monitor.sh"
    ["unit_history_tracking"]="test-monitoring-history-tracking.sh"
    ["unit_monitoring_ui"]="test-monitoring-ui.sh"
    ["unit_btop_integration"]="test-monitoring-btop-integration.sh"
    ["unit_alert_system"]="test-monitoring-alert-system.sh"

    # Integration tests
    ["integration_safety"]="test-monitoring-integration.sh"

    # Performance tests
    ["performance_impact"]="test-monitoring-performance-impact.sh"

    # Scenario tests
    ["scenarios_alerts"]="test-monitoring-alert-scenarios.sh"
)

# Global test statistics
declare -A CATEGORY_STATS=(
    ["unit_total"]=0 ["unit_passed"]=0 ["unit_failed"]=0 ["unit_skipped"]=0
    ["integration_total"]=0 ["integration_passed"]=0 ["integration_failed"]=0 ["integration_skipped"]=0
    ["performance_total"]=0 ["performance_passed"]=0 ["performance_failed"]=0 ["performance_skipped"]=0
    ["scenarios_total"]=0 ["scenarios_passed"]=0 ["scenarios_failed"]=0 ["scenarios_skipped"]=0
)

# Colors for output
if [[ -t 1 ]]; then
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_PURPLE='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[1;37m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_RED="" COLOR_GREEN="" COLOR_YELLOW="" COLOR_BLUE=""
    readonly COLOR_PURPLE="" COLOR_CYAN="" COLOR_WHITE="" COLOR_BOLD=""
    readonly COLOR_RESET=""
fi

# =============================================================================
# COMPREHENSIVE TEST FRAMEWORK FUNCTIONS
# =============================================================================

# Print comprehensive test header
print_comprehensive_header() {
    echo ""
    echo "${COLOR_BOLD}${COLOR_BLUE}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}║                                                              ║${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}║  $TEST_SUITE_NAME${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}║  Version: $TEST_SUITE_VERSION${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}║                                                              ║${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo "${COLOR_BLUE}Test Results Directory:${COLOR_RESET} $TEST_RESULTS_DIR"
    echo "${COLOR_BLUE}Test Categories:${COLOR_RESET}"
    for category in "${!TEST_CATEGORIES[@]}"; do
        echo "  - $category: ${TEST_CATEGORIES[$category]}"
    done
    echo ""
}

# Print category header
print_category_header() {
    local category="$1"
    local description="${TEST_CATEGORIES[$category]}"

    echo ""
    echo "${COLOR_BOLD}${COLOR_PURPLE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_PURPLE}  $description${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_PURPLE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# Print test file header
print_test_file_header() {
    local test_name="$1"
    local test_file="$2"

    echo "${COLOR_CYAN}Running: $test_name${COLOR_RESET}"
    echo "${COLOR_DIM}File: $test_file${COLOR_RESET}"
    echo "${COLOR_CYAN}$(printf '─%.0s' $(seq 1 ${#test_name} + 8))${COLOR_RESET}"
    echo ""
}

# Run individual test file
run_test_file() {
    local test_key="$1"
    local test_file="${TEST_FILES[$test_key]}"
    local category="${test_key%_*}"
    local test_name="${test_key#*_}"
    local test_name_formatted="${test_name//_/ }"

    print_test_file_header "$test_name_formatted" "$test_file"

    # Create category results directory
    local category_results_dir="$TEST_RESULTS_DIR/$category"
    mkdir -p "$category_results_dir"

    # Initialize test framework for this test file
    local test_output_file="$category_results_dir/${test_file%.sh}.out"
    local test_log_file="$category_results_dir/${test_file%.sh}.log"

    # Run the test file and capture output
    local test_start_time
    test_start_time=$(date +%s)

    if bash "${TEST_ROOT_DIR}/tests/$test_file" > "$test_output_file" 2>&1; then
        local test_end_time
        test_end_time=$(date +%s)
        local test_duration=$((test_end_time - test_start_time))

        # Parse test results from output
        local total_tests
        local passed_tests
        local failed_tests
        local skipped_tests

        total_tests=$(grep -c "Tests Run:" "$test_output_file" 2>/dev/null || echo "0")
        passed_tests=$(grep -c "Tests Passed:" "$test_output_file" 2>/dev/null || echo "0")
        failed_tests=$(grep -c "Tests Failed:" "$test_output_file" 2>/dev/null || echo "0")
        skipped_tests=$(grep -c "Tests Skipped:" "$test_output_file" 2>/dev/null || echo "0")

        # Update category statistics
        CATEGORY_STATS["${category}_total"]=$((CATEGORY_STATS["${category}_total"] + total_tests))
        CATEGORY_STATS["${category}_passed"]=$((CATEGORY_STATS["${category}_passed"] + passed_tests))
        CATEGORY_STATS["${category}_failed"]=$((CATEGORY_STATS["${category}_failed"] + failed_tests))
        CATEGORY_STATS["${category}_skipped"]=$((CATEGORY_STATS["${category}_skipped"] + skipped_tests))

        # Print results summary
        echo "${COLOR_GREEN}✓ PASSED${COLOR_RESET} $test_name_formatted"
        echo "  ${COLOR_DIM}Duration: ${test_duration}s${COLOR_RESET}"
        echo "  ${COLOR_DIM}Results: $passed_tests/$total_tests passed${COLOR_RESET}"

        if [[ $failed_tests -gt 0 ]]; then
            echo "  ${COLOR_RED}Failed: $failed_tests${COLOR_RESET}"
            echo "  ${COLOR_DIM}See $test_output_file for details${COLOR_RESET}"
        fi

        if [[ $skipped_tests -gt 0 ]]; then
            echo "  ${COLOR_YELLOW}Skipped: $skipped_tests${COLOR_RESET}"
        fi

    else
        local test_end_time
        test_end_time=$(date +%s)
        local test_duration=$((test_end_time - test_start_time))

        CATEGORY_STATS["${category}_failed"]=$((CATEGORY_STATS["${category}_failed"] + 1))

        echo "${COLOR_RED}✗ FAILED${COLOR_RESET} $test_name_formatted"
        echo "  ${COLOR_DIM}Duration: ${test_duration}s${COLOR_RESET}"
        echo "  ${COLOR_RED}Test execution failed${COLOR_RESET}"
        echo "  ${COLOR_DIM}See $test_output_file for error details${COLOR_RESET}"
    fi

    echo ""
}

# Print category summary
print_category_summary() {
    local category="$1"
    local description="${TEST_CATEGORIES[$category]}"

    local total=${CATEGORY_STATS["${category}_total"]}
    local passed=${CATEGORY_STATS["${category}_passed"]}
    local failed=${CATEGORY_STATS["${category}_failed"]}
    local skipped=${CATEGORY_STATS["${category}_skipped"]}

    local success_rate=0
    if [[ $total -gt 0 ]]; then
        success_rate=$((passed * 100 / total))
    fi

    echo ""
    echo "${COLOR_BOLD}${description} Summary:${COLOR_RESET}"
    echo "  Total Tests: $total"
    echo "  ${COLOR_GREEN}Passed: $passed${COLOR_RESET}"
    echo "  ${COLOR_RED}Failed: $failed${COLOR_RESET}"
    echo "  ${COLOR_YELLOW}Skipped: $skipped${COLOR_RESET}"
    echo "  Success Rate: ${success_rate}%"

    if [[ $failed -eq 0 ]]; then
        echo "  ${COLOR_GREEN}✓ All $description passed!${COLOR_RESET}"
    else
        echo "  ${COLOR_RED}✗ Some $description failed!${COLOR_RESET}"
    fi
    echo ""
}

# Print comprehensive test summary
print_comprehensive_summary() {
    echo ""
    echo "${COLOR_BOLD}${COLOR_BLUE}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}║                    COMPREHENSIVE TEST SUMMARY                   ║${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BLUE}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""

    # Calculate overall statistics
    local total_total=0
    local total_passed=0
    local total_failed=0
    local total_skipped=0

    for category in "${!TEST_CATEGORIES[@]}"; do
        total_total=$((total_total + CATEGORY_STATS["${category}_total"]))
        total_passed=$((total_passed + CATEGORY_STATS["${category}_passed"]))
        total_failed=$((total_failed + CATEGORY_STATS["${category}_failed"]))
        total_skipped=$((total_skipped + CATEGORY_STATS["${category}_skipped"]))
    done

    # Print per-category results
    for category in "${!TEST_CATEGORIES[@]}"; do
        local description="${TEST_CATEGORIES[$category]}"
        local total=${CATEGORY_STATS["${category}_total"]}
        local passed=${CATEGORY_STATS["${category}_passed"]}
        local failed=${CATEGORY_STATS["${category}_failed"]}

        if [[ $total -gt 0 ]]; then
            local success_rate=$((passed * 100 / total))
            printf "${COLOR_BLUE}%-20s:${COLOR_RESET} %3d total, %3d passed, %3d failed (%d%% success)\n" \
                "$description" "$total" "$passed" "$failed" "$success_rate"
        else
            printf "${COLOR_DIM}%-20s:${COLOR_RESET} No tests run\n" "$description"
        fi
    done

    echo ""
    echo "${COLOR_BOLD}OVERALL RESULTS:${COLOR_RESET}"
    echo "  Total Tests: $total_total"
    echo "  ${COLOR_GREEN}Passed: $total_passed${COLOR_RESET}"
    echo "  ${COLOR_RED}Failed: $total_failed${COLOR_RESET}"
    echo "  ${COLOR_YELLOW}Skipped: $total_skipped${COLOR_RESET}"

    local overall_success_rate=0
    if [[ $total_total -gt 0 ]]; then
        overall_success_rate=$((total_passed * 100 / total_total))
    fi

    echo "  Overall Success Rate: ${overall_success_rate}%"
    echo ""

    if [[ $total_failed -eq 0 ]]; then
        echo "${COLOR_BOLD}${COLOR_GREEN}🎉 ALL TESTS PASSED! 🎉${COLOR_RESET}"
        echo "${COLOR_GREEN}The monitoring system is functioning correctly.${COLOR_RESET}"
    else
        echo "${COLOR_BOLD}${COLOR_RED}❌ SOME TESTS FAILED ❌${COLOR_RESET}"
        echo "${COLOR_RED}Please review the failed tests and fix any issues.${COLOR_RESET}"
        echo ""
        echo "${COLOR_BLUE}Detailed logs available in: $TEST_RESULTS_DIR${COLOR_RESET}"
    fi

    echo ""
}

# Generate HTML report
generate_html_report() {
    local report_file="$TEST_RESULTS_DIR/comprehensive-report.html"

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FUB Monitoring System Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007acc; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 30px; }
        .category { margin-bottom: 30px; }
        .category h2 { color: #007acc; border-bottom: 1px solid #ddd; padding-bottom: 10px; }
        .test-file { margin: 10px 0; padding: 10px; background-color: #fff; border-left: 4px solid #007acc; }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .skipped { color: #ffc107; }
        .stats { display: flex; justify-content: space-between; margin: 20px 0; }
        .stat-box { text-align: center; padding: 15px; background-color: #e9ecef; border-radius: 5px; min-width: 100px; }
        .timestamp { color: #666; font-size: 0.9em; text-align: center; margin-top: 30px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>FUB Monitoring System Test Report</h1>
            <p>Generated on $(date)</p>
        </div>

        <div class="summary">
            <h2>Overall Summary</h2>
            <div class="stats">
EOF

    # Calculate overall statistics
    local total_total=0 total_passed=0 total_failed=0 total_skipped=0
    for category in "${!TEST_CATEGORIES[@]}"; do
        total_total=$((total_total + CATEGORY_STATS["${category}_total"]))
        total_passed=$((total_passed + CATEGORY_STATS["${category}_passed"]))
        total_failed=$((total_failed + CATEGORY_STATS["${category}_failed"]))
        total_skipped=$((total_skipped + CATEGORY_STATS["${category}_skipped"]))
    done

    local overall_success_rate=0
    if [[ $total_total -gt 0 ]]; then
        overall_success_rate=$((total_passed * 100 / total_total))
    fi

    cat >> "$report_file" << EOF
                <div class="stat-box">
                    <h3>$total_total</h3>
                    <p>Total Tests</p>
                </div>
                <div class="stat-box passed">
                    <h3>$total_passed</h3>
                    <p>Passed</p>
                </div>
                <div class="stat-box failed">
                    <h3>$total_failed</h3>
                    <p>Failed</p>
                </div>
                <div class="stat-box skipped">
                    <h3>$total_skipped</h3>
                    <p>Skipped</p>
                </div>
                <div class="stat-box">
                    <h3>${overall_success_rate}%</h3>
                    <p>Success Rate</p>
                </div>
            </div>
        </div>
EOF

    # Add category details
    for category in "${!TEST_CATEGORIES[@]}"; do
        local description="${TEST_CATEGORIES[$category]}"
        local total=${CATEGORY_STATS["${category}_total"]}
        local passed=${CATEGORY_STATS["${category}_passed"]}
        local failed=${CATEGORY_STATS["${category}_failed"]}
        local skipped=${CATEGORY_STATS["${category}_skipped"]}

        cat >> "$report_file" << EOF
        <div class="category">
            <h2>$description</h2>
            <div class="stats">
                <div class="stat-box">
                    <h3>$total</h3>
                    <p>Total</p>
                </div>
                <div class="stat-box passed">
                    <h3>$passed</h3>
                    <p>Passed</p>
                </div>
                <div class="stat-box failed">
                    <h3>$failed</h3>
                    <p>Failed</p>
                </div>
                <div class="stat-box skipped">
                    <h3>$skipped</h3>
                    <p>Skipped</p>
                </div>
            </div>
EOF

        # Add test file details
        for test_key in "${!TEST_FILES[@]}"; do
            if [[ "$test_key" == "${category}_*" ]]; then
                local test_file="${TEST_FILES[$test_key]}"
                local test_name="${test_key#*_}"
                local test_name_formatted="${test_name//_/ }"

                cat >> "$report_file" << EOF
            <div class="test-file">
                <h4>$test_name_formatted</h4>
                <p>File: <code>$test_file</code></p>
            </div>
EOF
            fi
        done

        cat >> "$report_file" << EOF
        </div>
EOF
    done

    cat >> "$report_file" << EOF
        <div class="timestamp">
            <p>Report generated at $(date)</p>
            <p>Test results directory: $TEST_RESULTS_DIR</p>
        </div>
    </div>
</body>
</html>
EOF

    echo "${COLOR_BLUE}HTML report generated: $report_file${COLOR_RESET}"
}

# Check system requirements
check_system_requirements() {
    echo "${COLOR_CYAN}Checking system requirements...${COLOR_RESET}"

    local requirements_met=true

    # Check for required commands
    local required_commands=("bash" "grep" "awk" "sed" "date" "ps" "free")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ✓ $cmd"
        else
            echo "  ✗ $cmd (missing)"
            requirements_met=false
        fi
    done

    # Check for optional commands
    local optional_commands=("bc" "jq")
    echo ""
    echo "Optional commands:"
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ✓ $cmd"
        else
            echo "  ⚠ $cmd (not available - some tests may be skipped)"
        fi
    done

    if [[ "$requirements_met" == "true" ]]; then
        echo ""
        echo "${COLOR_GREEN}✓ All system requirements met${COLOR_RESET}"
        return 0
    else
        echo ""
        echo "${COLOR_RED}✗ Some system requirements missing${COLOR_RESET}"
        return 1
    fi
}

# Run specific category tests
run_category_tests() {
    local category="$1"

    print_category_header "$category"

    local category_tests_run=0
    for test_key in "${!TEST_FILES[@]}"; do
        if [[ "$test_key" == "${category}_*" ]]; then
            run_test_file "$test_key"
            category_tests_run=$((category_tests_run + 1))
        fi
    done

    if [[ $category_tests_run -eq 0 ]]; then
        echo "${COLOR_YELLOW}No tests found for category: $category${COLOR_RESET}"
    fi

    print_category_summary "$category"
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main_test() {
    # Parse command line arguments
    local run_category=""
    local run_specific=""
    local generate_html=true
    local check_requirements=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --category)
                run_category="$2"
                shift 2
                ;;
            --test)
                run_specific="$2"
                shift 2
                ;;
            --no-html)
                generate_html=false
                shift
                ;;
            --no-requirements-check)
                check_requirements=false
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --category CATEGORY     Run only tests from specific category"
                echo "                          Categories: unit, integration, performance, scenarios"
                echo "  --test TEST_NAME        Run only specific test"
                echo "  --no-html              Don't generate HTML report"
                echo "  --no-requirements-check Skip system requirements check"
                echo "  --help, -h             Show this help message"
                echo ""
                echo "Available test categories:"
                for category in "${!TEST_CATEGORIES[@]}"; do
                    echo "  - $category: ${TEST_CATEGORIES[$category]}"
                done
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check system requirements
    if [[ "$check_requirements" == "true" ]]; then
        if ! check_system_requirements; then
            echo "${COLOR_RED}System requirements check failed. Use --no-requirements-check to bypass.${COLOR_RESET}"
            exit 1
        fi
        echo ""
    fi

    # Create results directory
    mkdir -p "$TEST_RESULTS_DIR"

    # Print header
    print_comprehensive_header

    # Record test suite start time
    local suite_start_time
    suite_start_time=$(date +%s)

    # Run tests based on arguments
    if [[ -n "$run_specific" ]]; then
        # Run specific test
        if [[ -n "${TEST_FILES[$run_specific]:-}" ]]; then
            print_category_header "custom"
            run_test_file "$run_specific"
            print_category_summary "custom"
        else
            echo "${COLOR_RED}Unknown test: $run_specific${COLOR_RESET}"
            echo "Available tests:"
            for test_key in "${!TEST_FILES[@]}"; do
                echo "  - $test_key"
            done
            exit 1
        fi
    elif [[ -n "$run_category" ]]; then
        # Run specific category
        if [[ -n "${TEST_CATEGORIES[$run_category]:-}" ]]; then
            run_category_tests "$run_category"
        else
            echo "${COLOR_RED}Unknown category: $run_category${COLOR_RESET}"
            echo "Available categories:"
            for category in "${!TEST_CATEGORIES[@]}"; do
                echo "  - $category: ${TEST_CATEGORIES[$category]}"
            done
            exit 1
        fi
    else
        # Run all tests by category
        for category in "${!TEST_CATEGORIES[@]}"; do
            run_category_tests "$category"
        done
    fi

    # Calculate total suite duration
    local suite_end_time
    suite_end_time=$(date +%s)
    local suite_duration=$((suite_end_time - suite_start_time))

    # Print comprehensive summary
    print_comprehensive_summary

    echo "${COLOR_BLUE}Total test suite duration: ${suite_duration}s${COLOR_RESET}"
    echo "${COLOR_BLUE}Test results saved to: $TEST_RESULTS_DIR${COLOR_RESET}"

    # Generate HTML report
    if [[ "$generate_html" == "true" ]]; then
        generate_html_report
    fi

    # Exit with appropriate code
    local total_failed=0
    for category in "${!TEST_CATEGORIES[@]}"; do
        total_failed=$((total_failed + CATEGORY_STATS["${category}_failed"]))
    done

    if [[ $total_failed -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_test "$@"
fi