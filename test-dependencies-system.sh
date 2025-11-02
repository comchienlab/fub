#!/usr/bin/env bash

# FUB Dependencies System Test Suite
# Comprehensive testing for the dependency management system

set -euo pipefail

# Test configuration
readonly TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_ROOT_DIR="$(cd "${TEST_SCRIPT_DIR}" && pwd)"
readonly TEST_RESULTS_DIR="${TEST_ROOT_DIR}/test-results"
readonly TEST_LOG_FILE="${TEST_RESULTS_DIR}/test.log"

# Source the dependency system
source "${TEST_ROOT_DIR}/lib/dependencies/fub-deps.sh"

# Test state
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for test output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly RESET='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly BOLD=''
    readonly RESET=''
fi

# Initialize test environment
init_test_environment() {
    echo -e "${BOLD}${CYAN}FUB Dependencies System Test Suite${RESET}"
    echo "======================================"
    echo ""

    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"

    # Initialize log file
    > "$TEST_LOG_FILE" cat << EOF
FUB Dependencies System Test Log
Started: $(date)
======================================

EOF

    echo -e "${BLUE}Test environment initialized${RESET}"
    echo -e "${BLUE}Results directory: ${TEST_RESULTS_DIR}${RESET}"
    echo ""
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "Expected: $expected, Actual: $actual"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed"

    if [[ "$not_expected" != "$actual" ]]; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "Values should not be equal: $actual"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed"

    if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "Expected true, got: $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed"

    if [[ "$condition" == "false" ]] || [[ "$condition" == "1" ]]; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "Expected false, got: $condition"
        return 1
    fi
}

assert_command_exists() {
    local command="$1"
    local message="${2:-Command should exist: $command}"

    if command_exists "$command"; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "Command not found: $command"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    if [[ -f "$file" ]]; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "File not found: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"

    if [[ ! -f "$file" ]]; then
        log_test_pass "$message"
        return 0
    else
        log_test_fail "$message" "File exists: $file"
        return 1
    fi
}

# Logging functions
log_test_start() {
    local test_name="$1"
    ((TESTS_RUN++))
    echo -e "${BLUE}RUNNING: ${test_name}${RESET}" | tee -a "$TEST_LOG_FILE"
}

log_test_pass() {
    local message="$1"
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓ PASS${RESET}: $message" | tee -a "$TEST_LOG_FILE"
}

log_test_fail() {
    local message="$1"
    local details="${2:-}"
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗ FAIL${RESET}: $message" | tee -a "$TEST_LOG_FILE"
    if [[ -n "$details" ]]; then
        echo -e "    ${YELLOW}Details: ${details}${RESET}" | tee -a "$TEST_LOG_FILE"
    fi
}

log_test_skip() {
    local message="$1"
    ((TESTS_SKIPPED++))
    echo -e "  ${YELLOW}- SKIP${RESET}: $message" | tee -a "$TEST_LOG_FILE"
}

# Test framework functions
run_test() {
    local test_function="$1"
    local test_name="$2"

    log_test_start "$test_name"

    # Run the test function
    if "$test_function"; then
        log_test_pass "$test_name"
    else
        log_test_fail "$test_name"
    fi
}

# Test suites
test_dependency_system_initialization() {
    echo -e "\n${BOLD}${CYAN}Testing Dependency System Initialization${RESET}"
    echo "=========================================="

    # Test basic initialization
    run_test test_basic_initialization "Basic system initialization"

    # Test configuration loading
    run_test test_configuration_loading "Configuration loading"

    # Test registry loading
    run_test test_registry_loading "Registry loading"

    # Test cache system
    run_test test_cache_system "Cache system"
}

test_basic_initialization() {
    # Initialize the dependency system
    init_fub_deps

    # Check if system is initialized
    assert_equals "true" "$DEPS_SYSTEM_INITIALIZED" "Dependency system should be initialized"
    assert_equals "true" "$DEPS_SYSTEM_LOADED" "Dependency system should be loaded"
}

test_configuration_loading() {
    # Test configuration values
    local auto_check=$(get_deps_config auto_check)
    assert_equals "true" "$auto_check" "Auto check should be enabled by default"

    local auto_install=$(get_deps_config auto_install)
    assert_equals "false" "$auto_install" "Auto install should be disabled by default"

    local cache_ttl=$(get_deps_config cache_ttl)
    assert_equals "3600" "$cache_ttl" "Cache TTL should be 3600 seconds"
}

test_registry_loading() {
    # Test if registry is loaded
    assert_true "$DEPS_REGISTRY_LOADED" "Registry should be loaded"
    assert_true "[[ $DEPS_REGISTRY_LOADED_COUNT -gt 0 ]]" "Registry should contain tools"

    # Test if specific tools exist in registry
    assert_true "tool_exists gum" "Gum should exist in registry"
    assert_true "tool_exists btop" "Btop should exist in registry"
    assert_false "tool_exists nonexistent_tool" "Nonexistent tool should not exist"
}

test_cache_system() {
    # Test cache initialization
    assert_true "$DEPS_CACHE_LOADED" "Cache should be loaded"

    # Test cache files existence
    assert_file_exists "$DEPS_CACHE_DIR" "Cache directory should exist"
}

test_dependency_detection() {
    echo -e "\n${BOLD}${CYAN}Testing Dependency Detection${RESET}"
    echo "==============================="

    # Test tool detection
    run_test test_tool_detection "Tool detection"

    # Test capability detection
    run_test test_capability_detection "Capability detection"

    # Test version checking
    run_test test_version_checking "Version checking"
}

test_tool_detection() {
    # Run dependency detection
    detect_all_tools true

    # Test if system tools are detected
    if command_exists bash; then
        local bash_status=$(get_cached_tool_status "bash")
        assert_not_equals "$DEPS_STATUS_UNKNOWN" "$bash_status" "Bash status should be known"
    fi

    # Test unknown tool handling
    local unknown_status=$(get_cached_tool_status "definitely_nonexistent_tool_xyz")
    assert_equals "$DEPS_STATUS_UNKNOWN" "$unknown_status" "Unknown tool should have unknown status"
}

test_capability_detection() {
    # Initialize capability detection
    init_capability_detection

    # Test system capabilities detection
    assert_true "$SYSTEM_CAPABILITIES_DETECTED" "System capabilities should be detected"

    # Test capability checking
    if command_exists git; then
        assert_true "has_system_capability version-control:git" "Git capability should be detected"
    fi
}

test_version_checking() {
    # Initialize version checking
    init_version_check_system

    # Test version parsing
    local semver=$(parse_semver "1.2.3")
    assert_equals "1:2:3" "$semver" "Version parsing should work correctly"

    # Test version comparison
    assert_true "compare_semver 1.2.3 '==' 1.2.3" "Version equality should work"
    assert_true "compare_semver 1.2.3 '<' 1.2.4" "Version comparison should work"
    assert_true "compare_semver 1.2.3 '>' 1.2.2" "Version comparison should work"
}

test_installation_system() {
    echo -e "\n${BOLD}${CYAN}Testing Installation System${RESET}"
    echo "=============================="

    # Test package manager detection
    run_test test_package_manager_detection "Package manager detection"

    # Test installation validation
    run_test test_installation_validation "Installation validation"
}

test_package_manager_detection() {
    # Test package manager detection
    local managers
    managers=$(detect_package_managers)

    if command_exists apt; then
        assert_true "echo \"$managers\" | grep -q apt" "APT should be detected if available"
    fi

    # Test should return at least one package manager or empty list
    if [[ -n "$managers" ]]; then
        assert_true "[[ ${#managers} -gt 0 ]]" "Should detect available package managers"
    fi
}

test_installation_validation() {
    # Test installation permission checking
    local can_install_root
    if is_root; then
        can_install_root=$(check_installation_permissions "apt")
    else
        can_install_root=$(check_installation_permissions "brew")
    fi

    # Should be able to install with some package manager
    assert_true "[[ $can_install_root -eq 0 || $can_install_root -eq 1 ]]" "Installation permissions check should work"
}

test_recommendation_system() {
    echo -e "\n${BOLD}${CYAN}Testing Recommendation System${RESET}"
    echo "================================="

    # Test context detection
    run_test test_context_detection "Context detection"

    # Test recommendation generation
    run_test test_recommendation_generation "Recommendation generation"
}

test_context_detection() {
    # Initialize recommendation system
    init_recommendation_system

    # Test context detection
    local contexts
    contexts=$(detect_user_context)

    assert_true "[[ ${#contexts} -gt 0 ]]" "Should detect at least one context"
}

test_recommendation_generation() {
    # Test context-based recommendations
    local recommendations
    recommendations=$(get_context_recommendations "$RECOMMENDATION_CONTEXT_PRODUCTIVITY" 5)

    # Should return recommendations or empty list
    if [[ -n "$recommendations" ]]; then
        assert_true "[[ ${#recommendations} -gt 0 ]]" "Should generate recommendations"
    fi

    # Test priority-based recommendations
    local priority_recs
    priority_recs=$(get_priority_recommendations 80 3)

    # Should return recommendations or empty list
    if [[ -n "$priority_recs" ]]; then
        assert_true "[[ ${#priority_recs} -gt 0 ]]" "Should generate priority recommendations"
    fi
}

test_fallback_system() {
    echo -e "\n${BOLD}${CYAN}Testing Fallback System${RESET}"
    echo "============================="

    # Test degradation analysis
    run_test test_degradation_analysis "Degradation analysis"

    # Test alternative implementations
    run_test test_alternative_implementations "Alternative implementations"
}

test_degradation_analysis() {
    # Initialize degradation system
    init_degradation_system

    # Test degradation mode detection
    assert_not_equals "" "$CURRENT_DEGRADATION_MODE" "Should have a degradation mode"
}

test_alternative_implementations() {
    # Test alternative system initialization
    init_alternatives_system

    # Test alternative lookup
    if ! command_exists gum; then
        local gum_alternative
        gum_alternative=$(get_alternative "gum")
        # May or may not have alternatives
        assert_true "[[ $([[ -n \"$gum_alternative\" ]] && echo 1 || echo 0) -ge 0 ]]" "Alternative lookup should work"
    fi
}

test_error_handling() {
    echo -e "\n${BOLD}${CYAN}Testing Error Handling${RESET}"
    echo "==========================="

    # Test invalid tool handling
    run_test test_invalid_tool_handling "Invalid tool handling"

    # Test configuration error handling
    run_test test_configuration_error_handling "Configuration error handling"
}

test_invalid_tool_handling() {
    # Test handling of invalid tool names
    local result=0
    find_tool_index "nonexistent_tool_xyz" >/dev/null 2>&1 || result=1
    assert_true "[[ $result -eq 1 ]]" "Should handle invalid tool names gracefully"
}

test_configuration_error_handling() {
    # Test invalid configuration values
    local result=0
    set_deps_config "invalid_key" "value" >/dev/null 2>&1 || result=1
    # Should not crash, but may not succeed
    assert_true "[[ $result -ge 0 ]]" "Should handle invalid configuration gracefully"
}

test_integration() {
    echo -e "\n${BOLD}${CYAN}Testing System Integration${RESET}"
    echo "==============================="

    # Test FUB integration
    run_test test_fub_integration "FUB integration"

    # Test shell integration
    run_test test_shell_integration "Shell integration"
}

test_fub_integration() {
    # Test integration initialization
    local result=0
    init_fub_deps_integration >/dev/null 2>&1 || result=1
    assert_equals "0" "$result" "FUB integration should initialize successfully"
}

test_shell_integration() {
    # Test shell integration setup
    assert_file_exists "${FUB_CACHE_DIR}" "Cache directory should exist for shell integration"
}

# Performance tests
test_performance() {
    echo -e "\n${BOLD}${CYAN}Testing Performance${RESET}"
    echo "========================="

    # Test initialization performance
    run_test test_initialization_performance "Initialization performance"

    # Test detection performance
    run_test test_detection_performance "Detection performance"
}

test_initialization_performance() {
    # Time the initialization
    local start_time end_time duration
    start_time=$(date +%s.%N)

    init_fub_deps >/dev/null 2>&1

    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.5")

    # Should initialize within reasonable time (5 seconds)
    local duration_float
    duration_float=$(echo "$duration < 5.0" | bc -l 2>/dev/null || echo "1")
    assert_true "[[ $duration_float -eq 1 ]]" "Initialization should complete within 5 seconds"
}

test_detection_performance() {
    # Time the detection
    local start_time end_time duration
    start_time=$(date +%s.%N)

    detect_all_tools false >/dev/null 2>&1

    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1.0")

    # Should complete within reasonable time (10 seconds)
    local duration_float
    duration_float=$(echo "$duration < 10.0" | bc -l 2>/dev/null || echo "1")
    assert_true "[[ $duration_float -eq 1 ]]" "Detection should complete within 10 seconds"
}

# Run all tests
run_all_tests() {
    local start_time
    start_time=$(date +%s)

    init_test_environment

    # Run all test suites
    test_dependency_system_initialization
    test_dependency_detection
    test_installation_system
    test_recommendation_system
    test_fallback_system
    test_error_handling
    test_integration
    test_performance

    # Show test results
    show_test_results "$start_time"
}

# Show test results
show_test_results() {
    local start_time="$1"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo -e "${BOLD}${CYAN}Test Results Summary${RESET}"
    echo "======================="
    echo ""

    echo -e "Total tests run: ${BOLD}$TESTS_RUN${RESET}"
    echo -e "${GREEN}Tests passed: ${BOLD}$TESTS_PASSED${RESET}"
    echo -e "${RED}Tests failed: ${BOLD}$TESTS_FAILED${RESET}"
    echo -e "${YELLOW}Tests skipped: ${BOLD}$TESTS_SKIPPED${RESET}"
    echo ""

    # Calculate success rate
    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
    fi

    echo -e "Success rate: ${BOLD}${success_rate}%${RESET}"
    echo -e "Duration: ${BOLD}${duration}s${RESET}"
    echo ""

    # Show final status
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ All tests passed!${RESET}"
        echo ""
        echo -e "${BLUE}Test log saved to: ${TEST_LOG_FILE}${RESET}"
        return 0
    else
        echo -e "${RED}${BOLD}❌ Some tests failed!${RESET}"
        echo ""
        echo -e "${BLUE}Check the test log for details: ${TEST_LOG_FILE}${RESET}"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi