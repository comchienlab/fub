#!/usr/bin/env bash

# FUB Comprehensive Test Suite
# Master test execution script for all FUB testing components

set -euo pipefail

# Comprehensive test suite metadata
readonly COMPREHENSIVE_TEST_VERSION="2.0.0"
readonly COMPREHENSIVE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly COMPREHENSIVE_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test framework
source "${COMPREHENSIVE_TEST_DIR}/test-framework.sh"

# Comprehensive test configuration
declare -A COMPREHENSIVE_CONFIG=(
    ["execution_mode"]="comprehensive"
    ["run_unit_tests"]="true"
    ["run_integration_tests"]="true"
    ["run_performance_tests"]="true"
    ["run_ubuntu_tests"]="true"
    ["run_safety_tests"]="true"
    ["run_user_acceptance_tests"]="true"
    ["parallel_execution"]="false"
    ["generate_reports"]="true"
    ["fail_fast"]="false"
    ["test_timeout"]="3600"
    ["results_dir"]="${COMPREHENSIVE_ROOT_DIR}/test-results"
)

# Test suite results tracking
declare -A SUITE_RESULTS=(
    ["unit_tests_passed"]=0
    ["unit_tests_failed"]=0
    ["unit_tests_total"]=0
    ["integration_tests_passed"]=0
    ["integration_tests_failed"]=0
    ["integration_tests_total"]=0
    ["performance_tests_passed"]=0
    ["performance_tests_failed"]=0
    ["performance_tests_total"]=0
    ["ubuntu_tests_passed"]=0
    ["ubuntu_tests_failed"]=0
    ["ubuntu_tests_total"]=0
    ["safety_tests_passed"]=0
    ["safety_tests_failed"]=0
    ["safety_tests_total"]=0
    ["user_acceptance_passed"]=0
    ["user_acceptance_failed"]=0
    ["user_acceptance_total"]=0
    ["total_execution_time"]=0
)

# Test suite definitions
declare -a TEST_SUITES=(
    "unit_tests:test-interactive-ui.sh:test-dependencies-system.sh:test-common.sh"
    "integration_tests:test-system-integration.sh:test-integration-suite.sh"
    "performance_tests:test-performance-enhanced.sh:test-performance-regression.sh"
    "ubuntu_tests:test-ubuntu-integration.sh"
    "safety_tests:test-safety-validation.sh:test-safety-framework.sh"
    "user_acceptance_tests:test-user-acceptance.sh"
)

# Test setup
setup_comprehensive_tests() {
    # Set up test environment
    FUB_TEST_DIR=$(setup_test_env)

    # Create comprehensive results directory
    mkdir -p "${COMPREHENSIVE_CONFIG[results_dir]}"
    export FUB_COMPREHENSIVE_RESULTS_DIR="${COMPREHENSIVE_CONFIG[results_dir]}"

    # Configure comprehensive test mode
    export FUB_COMPREHENSIVE_TEST="true"
    export FUB_TEST_MODE="true"

    # Initialize results tracking
    init_comprehensive_results

    # Create test execution log
    create_execution_log
}

# Initialize comprehensive results tracking
init_comprehensive_results() {
    # Reset all counters
    for key in "${!SUITE_RESULTS[@]}"; do
        SUITE_RESULTS["$key"]=0
    done

    # Create results file
    local results_file="${FUB_COMPREHENSIVE_RESULTS_DIR}/comprehensive_results_$(date +%Y%m%d_%H%M%S).json"
    cat > "$results_file" << EOF
{
  "test_timestamp": "$(date -Iseconds)",
  "test_version": "$COMPREHENSIVE_TEST_VERSION",
  "test_configuration": $(declare -p COMPREHENSIVE_CONFIG | sed 's/declare -A COMPREHENSIVE_CONFIG=/\n  /'),
  "suite_results": {},
  "execution_summary": {},
  "recommendations": []
}
EOF
    export FUB_COMPREHENSIVE_RESULTS_FILE="$results_file"
}

# Create test execution log
create_execution_log() {
    local log_file="${FUB_COMPREHENSIVE_RESULTS_DIR}/comprehensive_execution_$(date +%Y%m%d_%H%M%S).log"

    cat > "$log_file" << EOF
# FUB Comprehensive Test Suite Execution Log
# Started: $(date)
# Version: $COMPREHENSIVE_TEST_VERSION
# Root Directory: $COMPREHENSIVE_ROOT_DIR

EOF

    export FUB_EXECUTION_LOG="$log_file"
}

# Log execution message
log_execution() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$FUB_EXECUTION_LOG"
}

# Test teardown
teardown_comprehensive_tests() {
    # Generate final comprehensive report
    generate_comprehensive_report

    # Cleanup test environment
    cleanup_test_env "$FUB_TEST_DIR"

    # Unset environment variables
    unset FUB_COMPREHENSIVE_TEST FUB_COMPREHENSIVE_RESULTS_DIR
    unset FUB_COMPREHENSIVE_RESULTS_FILE FUB_EXECUTION_LOG
}

# =============================================================================
# TEST SUITE EXECUTION FUNCTIONS
# =============================================================================

# Execute unit tests
execute_unit_tests() {
    if [[ "${COMPREHENSIVE_CONFIG[run_unit_tests]}" != "true" ]]; then
        log_execution "⏭️  Skipping unit tests (disabled in configuration)"
        return 0
    fi

    log_execution "🔬 Starting Unit Tests Suite"
    local suite_start=$(date +%s)

    local unit_test_files=(
        "test-interactive-ui.sh"
        "test-dependencies-system.sh"
        "test-common.sh"
        "test-config.sh"
        "test-ui.sh"
        "test-scheduler.sh"
    )

    local suite_passed=0
    local suite_failed=0
    local suite_total=0

    for test_file in "${unit_test_files[@]}"; do
        local test_path="${COMPREHENSIVE_TEST_DIR}/$test_file"
        if [[ -f "$test_path" ]]; then
            log_execution "  📝 Running: $test_file"

            # Run the test file and capture results
            if bash "$test_path" >/dev/null 2>&1; then
                ((suite_passed++))
                log_execution "    ✅ PASSED: $test_file"
            else
                ((suite_failed++))
                log_execution "    ❌ FAILED: $test_file"
            fi
            ((suite_total++))
        else
            log_execution "    ⚠️  NOT FOUND: $test_file"
        fi
    done

    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))

    SUITE_RESULTS["unit_tests_passed"]=$suite_passed
    SUITE_RESULTS["unit_tests_failed"]=$suite_failed
    SUITE_RESULTS["unit_tests_total"]=$suite_total

    log_execution "🔬 Unit Tests Completed: $suite_passed/$suite_total passed (${suite_duration}s)"
}

# Execute integration tests
execute_integration_tests() {
    if [[ "${COMPREHENSIVE_CONFIG[run_integration_tests]}" != "true" ]]; then
        log_execution "⏭️  Skipping integration tests (disabled in configuration)"
        return 0
    fi

    log_execution "🔧 Starting Integration Tests Suite"
    local suite_start=$(date +%s)

    local integration_test_files=(
        "test-system-integration.sh"
        "test-integration-suite.sh"
    )

    local suite_passed=0
    local suite_failed=0
    local suite_total=0

    for test_file in "${integration_test_files[@]}"; do
        local test_path="${COMPREHENSIVE_TEST_DIR}/$test_file"
        if [[ -f "$test_path" ]]; then
            log_execution "  📝 Running: $test_file"

            if timeout "${COMPREHENSIVE_CONFIG[test_timeout]}" bash "$test_path" >/dev/null 2>&1; then
                ((suite_passed++))
                log_execution "    ✅ PASSED: $test_file"
            else
                ((suite_failed++))
                log_execution "    ❌ FAILED: $test_file (timeout or error)"
            fi
            ((suite_total++))
        else
            log_execution "    ⚠️  NOT FOUND: $test_file"
        fi
    done

    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))

    SUITE_RESULTS["integration_tests_passed"]=$suite_passed
    SUITE_RESULTS["integration_tests_failed"]=$suite_failed
    SUITE_RESULTS["integration_tests_total"]=$suite_total

    log_execution "🔧 Integration Tests Completed: $suite_passed/$suite_total passed (${suite_duration}s)"
}

# Execute performance tests
execute_performance_tests() {
    if [[ "${COMPREHENSIVE_CONFIG[run_performance_tests]}" != "true" ]]; then
        log_execution "⏭️  Skipping performance tests (disabled in configuration)"
        return 0
    fi

    log_execution "⚡ Starting Performance Tests Suite"
    local suite_start=$(date +%s)

    local performance_test_files=(
        "test-performance-enhanced.sh"
        "test-performance-regression.sh"
    )

    local suite_passed=0
    local suite_failed=0
    local suite_total=0

    for test_file in "${performance_test_files[@]}"; do
        local test_path="${COMPREHENSIVE_TEST_DIR}/$test_file"
        if [[ -f "$test_path" ]]; then
            log_execution "  📝 Running: $test_file"

            if timeout "${COMPREHENSIVE_CONFIG[test_timeout]}" bash "$test_path" >/dev/null 2>&1; then
                ((suite_passed++))
                log_execution "    ✅ PASSED: $test_file"
            else
                ((suite_failed++))
                log_execution "    ❌ FAILED: $test_file (timeout or error)"
            fi
            ((suite_total++))
        else
            log_execution "    ⚠️  NOT FOUND: $test_file"
        fi
    done

    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))

    SUITE_RESULTS["performance_tests_passed"]=$suite_passed
    SUITE_RESULTS["performance_tests_failed"]=$suite_failed
    SUITE_RESULTS["performance_tests_total"]=$suite_total

    log_execution "⚡ Performance Tests Completed: $suite_passed/$suite_total passed (${suite_duration}s)"
}

# Execute Ubuntu integration tests
execute_ubuntu_tests() {
    if [[ "${COMPREHENSIVE_CONFIG[run_ubuntu_tests]}" != "true" ]]; then
        log_execution "⏭️  Skipping Ubuntu tests (disabled in configuration)"
        return 0
    fi

    log_execution "🐧 Starting Ubuntu Integration Tests Suite"
    local suite_start=$(date +%s)

    local ubuntu_test_files=(
        "test-ubuntu-integration.sh"
    )

    local suite_passed=0
    local suite_failed=0
    local suite_total=0

    for test_file in "${ubuntu_test_files[@]}"; do
        local test_path="${COMPREHENSIVE_TEST_DIR}/$test_file"
        if [[ -f "$test_path" ]]; then
            log_execution "  📝 Running: $test_file"

            if timeout "${COMPREHENSIVE_CONFIG[test_timeout]}" bash "$test_path" >/dev/null 2>&1; then
                ((suite_passed++))
                log_execution "    ✅ PASSED: $test_file"
            else
                ((suite_failed++))
                log_execution "    ❌ FAILED: $test_file (timeout or error)"
            fi
            ((suite_total++))
        else
            log_execution "    ⚠️  NOT FOUND: $test_file"
        fi
    done

    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))

    SUITE_RESULTS["ubuntu_tests_passed"]=$suite_passed
    SUITE_RESULTS["ubuntu_tests_failed"]=$suite_failed
    SUITE_RESULTS["ubuntu_tests_total"]=$suite_total

    log_execution "🐧 Ubuntu Tests Completed: $suite_passed/$suite_total passed (${suite_duration}s)"
}

# Execute safety tests
execute_safety_tests() {
    if [[ "${COMPREHENSIVE_CONFIG[run_safety_tests]}" != "true" ]]; then
        log_execution "⏭️  Skipping safety tests (disabled in configuration)"
        return 0
    fi

    log_execution "🛡️  Starting Safety Tests Suite"
    local suite_start=$(date +%s)

    local safety_test_files=(
        "test-safety-validation.sh"
        "test-safety-framework.sh"
    )

    local suite_passed=0
    local suite_failed=0
    local suite_total=0

    for test_file in "${safety_test_files[@]}"; do
        local test_path="${COMPREHENSIVE_TEST_DIR}/$test_file"
        if [[ -f "$test_path" ]]; then
            log_execution "  📝 Running: $test_file"

            if timeout "${COMPREHENSIVE_CONFIG[test_timeout]}" bash "$test_path" >/dev/null 2>&1; then
                ((suite_passed++))
                log_execution "    ✅ PASSED: $test_file"
            else
                ((suite_failed++))
                log_execution "    ❌ FAILED: $test_file (timeout or error)"
            fi
            ((suite_total++))
        else
            log_execution "    ⚠️  NOT FOUND: $test_file"
        fi
    done

    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))

    SUITE_RESULTS["safety_tests_passed"]=$suite_passed
    SUITE_RESULTS["safety_tests_failed"]=$suite_failed
    SUITE_RESULTS["safety_tests_total"]=$suite_total

    log_execution "🛡️  Safety Tests Completed: $suite_passed/$suite_total passed (${suite_duration}s)"
}

# Execute user acceptance tests
execute_user_acceptance_tests() {
    if [[ "${COMPREHENSIVE_CONFIG[run_user_acceptance_tests]}" != "true" ]]; then
        log_execution "⏭️  Skipping user acceptance tests (disabled in configuration)"
        return 0
    fi

    log_execution "👥 Starting User Acceptance Tests Suite"
    local suite_start=$(date +%s)

    local ua_test_files=(
        "test-user-acceptance.sh"
    )

    local suite_passed=0
    local suite_failed=0
    local suite_total=0

    for test_file in "${ua_test_files[@]}"; do
        local test_path="${COMPREHENSIVE_TEST_DIR}/$test_file"
        if [[ -f "$test_path" ]]; then
            log_execution "  📝 Running: $test_file"

            if timeout "${COMPREHENSIVE_CONFIG[test_timeout]}" bash "$test_path" >/dev/null 2>&1; then
                ((suite_passed++))
                log_execution "    ✅ PASSED: $test_file"
            else
                ((suite_failed++))
                log_execution "    ❌ FAILED: $test_file (timeout or error)"
            fi
            ((suite_total++))
        else
            log_execution "    ⚠️  NOT FOUND: $test_file"
        fi
    done

    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))

    SUITE_RESULTS["user_acceptance_passed"]=$suite_passed
    SUITE_RESULTS["user_acceptance_failed"]=$suite_failed
    SUITE_RESULTS["user_acceptance_total"]=$suite_total

    log_execution "👥 User Acceptance Tests Completed: $suite_passed/$suite_total passed (${suite_duration}s)"
}

# =============================================================================
# REPORTING FUNCTIONS
# =============================================================================

# Generate comprehensive test report
generate_comprehensive_report() {
    log_execution "📊 Generating Comprehensive Test Report"

    local total_passed=0
    local total_failed=0
    local total_tests=0

    # Calculate totals
    for key in "${!SUITE_RESULTS[@]}"; do
        if [[ "$key" =~ _passed$ ]]; then
            total_passed=$((total_passed + SUITE_RESULTS[$key]))
        elif [[ "$key" =~ _failed$ ]]; then
            total_failed=$((total_failed + SUITE_RESULTS[$key]))
        elif [[ "$key" =~ _total$ ]]; then
            total_tests=$((total_tests + SUITE_RESULTS[$key]))
        fi
    done

    # Calculate success rate
    local success_rate=0
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( total_passed * 100 / total_tests ))
    fi

    # Update results file
    if [[ -n "${FUB_COMPREHENSIVE_RESULTS_FILE:-}" ]] && [[ -f "$FUB_COMPREHENSIVE_RESULTS_FILE" ]]; then
        jq ".suite_results = $(declare -p SUITE_RESULTS | sed 's/declare -A SUITE_RESULTS=/\n  /' | sed 's/^\([[:space:]]*\)\([^=]*\)=\(.*\)/\1"\2": \3/' | tr -d '()' | sed 's/ /, /g' | sed 's/,//g') | \
        .execution_summary = {
            \"total_passed\": $total_passed,
            \"total_failed\": $total_failed,
            \"total_tests\": $total_tests,
            \"success_rate\": $success_rate,
            \"execution_time_seconds\": ${SUITE_RESULTS[total_execution_time]}
        }" "$FUB_COMPREHENSIVE_RESULTS_FILE" > "${FUB_COMPREHENSIVE_RESULTS_FILE}.tmp" && \
        mv "${FUB_COMPREHENSIVE_RESULTS_FILE}.tmp" "$FUB_COMPREHENSIVE_RESULTS_FILE"
    fi

    # Print summary to console and log
    print_comprehensive_summary "$total_passed" "$total_failed" "$total_tests" "$success_rate"
}

# Print comprehensive test summary
print_comprehensive_summary() {
    local total_passed="$1"
    local total_failed="$2"
    local total_tests="$3"
    local success_rate="$4"

    echo ""
    echo "🏁 FUB Comprehensive Test Suite - Final Results"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "📊 Test Suite Breakdown:"
    echo "   🔬 Unit Tests:        ${SUITE_RESULTS[unit_tests_passed]}/${SUITE_RESULTS[unit_tests_total]} passed"
    echo "   🔧 Integration Tests: ${SUITE_RESULTS[integration_tests_passed]}/${SUITE_RESULTS[integration_tests_total]} passed"
    echo "   ⚡ Performance Tests: ${SUITE_RESULTS[performance_tests_passed]}/${SUITE_RESULTS[performance_tests_total]} passed"
    echo "   🐧 Ubuntu Tests:      ${SUITE_RESULTS[ubuntu_tests_passed]}/${SUITE_RESULTS[ubuntu_tests_total]} passed"
    echo "   🛡️  Safety Tests:      ${SUITE_RESULTS[safety_tests_passed]}/${SUITE_RESULTS[safety_tests_total]} passed"
    echo "   👥 User Acceptance:    ${SUITE_RESULTS[user_acceptance_passed]}/${SUITE_RESULTS[user_acceptance_total]} passed"
    echo ""
    echo "📈 Overall Results:"
    echo "   Total Tests:   $total_tests"
    echo "   Passed:        $total_passed"
    echo "   Failed:        $total_failed"
    echo "   Success Rate:  ${success_rate}%"
    echo "   Execution Time: ${SUITE_RESULTS[total_execution_time]}s"
    echo ""

    # Log summary
    log_execution "🏁 Comprehensive Test Suite Completed: $total_passed/$total_tests passed (${success_rate}%)"

    # Generate recommendations
    generate_recommendations "$total_passed" "$total_failed" "$total_tests" "$success_rate"

    # Final status
    if [[ $total_failed -eq 0 ]]; then
        echo "🎉 ALL TESTS PASSED! System is ready for deployment."
        log_execution "🎉 SUCCESS: All comprehensive tests passed"
        return 0
    else
        echo "❌ SOME TESTS FAILED! Review issues before deployment."
        log_execution "❌ FAILURE: $total_failed tests failed"
        return 1
    fi
}

# Generate recommendations based on test results
generate_recommendations() {
    local total_passed="$1"
    local total_failed="$2"
    local total_tests="$3"
    local success_rate="$4"

    echo "💡 Recommendations:"
    local recommendations=()

    if [[ $total_failed -eq 0 ]]; then
        recommendations+=("✅ All tests passed - System is production ready")
        recommendations+=("📈 Consider setting up automated testing in CI/CD pipeline")
    else
        if [[ $success_rate -lt 80 ]]; then
            recommendations+=("🚨 Critical: Success rate below 80% - Major issues need attention")
        elif [[ $success_rate -lt 95 ]]; then
            recommendations+=("⚠️  Warning: Success rate below 95% - Review and fix failing tests")
        fi

        # Check specific failure patterns
        if [[ ${SUITE_RESULTS[unit_tests_failed]} -gt 0 ]]; then
            recommendations+=("🔬 Fix unit test failures - Core functionality may be affected")
        fi
        if [[ ${SUITE_RESULTS[integration_tests_failed]} -gt 0 ]]; then
            recommendations+=("🔧 Address integration test failures - Component interactions need review")
        fi
        if [[ ${SUITE_RESULTS[performance_tests_failed]} -gt 0 ]]; then
            recommendations+=("⚡ Optimize performance - System may not meet requirements")
        fi
        if [[ ${SUITE_RESULTS[ubuntu_tests_failed]} -gt 0 ]]; then
            recommendations+=("🐧 Resolve Ubuntu compatibility issues - System may not work on target platform")
        fi
        if [[ ${SUITE_RESULTS[safety_tests_failed]} -gt 0 ]]; then
            recommendations+=("🛡️  Fix safety test failures - System may not be safe for production")
        fi
        if [[ ${SUITE_RESULTS[user_acceptance_failed]} -gt 0 ]]; then
            recommendations+=("👥 Improve user experience - User acceptance criteria not met")
        fi
    fi

    for recommendation in "${recommendations[@]}"; do
        echo "   $recommendation"
        log_execution "💡 $recommendation"
    done
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Run all test suites
run_comprehensive_test_suite() {
    local overall_start=$(date +%s)
    log_execution "🚀 Starting FUB Comprehensive Test Suite"

    echo ""
    echo "🚀 FUB Comprehensive Test Suite v$COMPREHENSIVE_TEST_VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 Configuration:"
    echo "   Execution Mode: ${COMPREHENSIVE_CONFIG[execution_mode]}"
    echo "   Parallel Execution: ${COMPREHENSIVE_CONFIG[parallel_execution]}"
    echo "   Fail Fast: ${COMPREHENSIVE_CONFIG[fail_fast]}"
    echo "   Test Timeout: ${COMPREHENSIVE_CONFIG[test_timeout]}s"
    echo "   Results Directory: ${COMPREHENSIVE_CONFIG[results_dir]}"
    echo ""

    # Execute test suites in order
    execute_unit_tests
    if [[ "${COMPREHENSIVE_CONFIG[fail_fast]}" == "true" ]] && [[ ${SUITE_RESULTS[unit_tests_failed]} -gt 0 ]]; then
        log_execution "🛑 Stopping early due to unit test failures (fail_fast enabled)"
        return 1
    fi

    execute_integration_tests
    if [[ "${COMPREHENSIVE_CONFIG[fail_fast]}" == "true" ]] && [[ ${SUITE_RESULTS[integration_tests_failed]} -gt 0 ]]; then
        log_execution "🛑 Stopping early due to integration test failures (fail_fast enabled)"
        return 1
    fi

    execute_performance_tests
    if [[ "${COMPREHENSIVE_CONFIG[fail_fast]}" == "true" ]] && [[ ${SUITE_RESULTS[performance_tests_failed]} -gt 0 ]]; then
        log_execution "🛑 Stopping early due to performance test failures (fail_fast enabled)"
        return 1
    fi

    execute_ubuntu_tests
    if [[ "${COMPREHENSIVE_CONFIG[fail_fast]}" == "true" ]] && [[ ${SUITE_RESULTS[ubuntu_tests_failed]} -gt 0 ]]; then
        log_execution "🛑 Stopping early due to Ubuntu test failures (fail_fast enabled)"
        return 1
    fi

    execute_safety_tests
    if [[ "${COMPREHENSIVE_CONFIG[fail_fast]}" == "true" ]] && [[ ${SUITE_RESULTS[safety_tests_failed]} -gt 0 ]]; then
        log_execution "🛑 Stopping early due to safety test failures (fail_fast enabled)"
        return 1
    fi

    execute_user_acceptance_tests

    local overall_end=$(date +%s)
    SUITE_RESULTS["total_execution_time"]=$((overall_end - overall_start))

    log_execution "🏁 Comprehensive Test Suite Execution Completed"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit-only)
                COMPREHENSIVE_CONFIG[run_integration_tests]="false"
                COMPREHENSIVE_CONFIG[run_performance_tests]="false"
                COMPREHENSIVE_CONFIG[run_ubuntu_tests]="false"
                COMPREHENSIVE_CONFIG[run_safety_tests]="false"
                COMPREHENSIVE_CONFIG[run_user_acceptance_tests]="false"
                shift
                ;;
            --integration-only)
                COMPREHENSIVE_CONFIG[run_unit_tests]="false"
                COMPREHENSIVE_CONFIG[run_performance_tests]="false"
                COMPREHENSIVE_CONFIG[run_ubuntu_tests]="false"
                COMPREHENSIVE_CONFIG[run_safety_tests]="false"
                COMPREHENSIVE_CONFIG[run_user_acceptance_tests]="false"
                shift
                ;;
            --fail-fast)
                COMPREHENSIVE_CONFIG[fail_fast]="true"
                shift
                ;;
            --no-ubuntu)
                COMPREHENSIVE_CONFIG[run_ubuntu_tests]="false"
                shift
                ;;
            --timeout)
                COMPREHENSIVE_CONFIG[test_timeout]="$2"
                shift 2
                ;;
            --results-dir)
                COMPREHENSIVE_CONFIG[results_dir]="$2"
                shift 2
                ;;
            --help|-h)
                echo "FUB Comprehensive Test Suite"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --unit-only           Run only unit tests"
                echo "  --integration-only    Run only integration tests"
                echo "  --fail-fast           Stop on first test failure"
                echo "  --no-ubuntu          Skip Ubuntu integration tests"
                echo "  --timeout SECONDS    Set test timeout (default: 3600)"
                echo "  --results-dir DIR     Set results directory"
                echo "  --help, -h           Show this help message"
                echo ""
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Setup test environment
    setup_comprehensive_tests

    # Run comprehensive test suite
    run_comprehensive_test_suite
    local result=$?

    # Cleanup and exit
    teardown_comprehensive_tests
    exit $result
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi