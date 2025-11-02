#!/usr/bin/env bash

# FUB Test Framework
# Simple but effective testing framework for FUB modules

set -euo pipefail

# Test framework metadata
readonly TEST_VERSION="1.0.0"
readonly TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test statistics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test configuration
TEST_VERBOSE=false
TEST_STOP_ON_FAILURE=false
TEST_OUTPUT_DIR=""
TEST_LOG_FILE=""

# Simple color support check
supports_colors() {
    [[ -t 1 && -n "${TERM:-}" ]] || return 1
}

# Colors for test output (if available)
if supports_colors; then
    readonly TEST_GREEN="\033[32m"
    readonly TEST_RED="\033[31m"
    readonly TEST_YELLOW="\033[33m"
    readonly TEST_BLUE="\033[34m"
    readonly TEST_BOLD="\033[1m"
    readonly TEST_RESET="\033[0m"
else
    readonly TEST_GREEN=""
    readonly TEST_RED=""
    readonly TEST_YELLOW=""
    readonly TEST_BLUE=""
    readonly TEST_BOLD=""
    readonly TEST_RESET=""
fi

# Initialize test framework
init_test_framework() {
    local output_dir="${1:-${TEST_ROOT_DIR}/test-results}"
    local verbose="${2:-false}"
    local stop_on_failure="${3:-false}"

    TEST_VERBOSE="$verbose"
    TEST_STOP_ON_FAILURE="$stop_on_failure"
    TEST_OUTPUT_DIR="$output_dir"
    TEST_LOG_FILE="${output_dir}/test-$(date '+%Y%m%d_%H%M%S').log"

    # Create output directory
    ensure_dir "$output_dir"

    # Initialize log file
    > "$TEST_LOG_FILE" cat << EOF
# FUB Test Run - $(date)
# Test Framework v$TEST_VERSION
# Test Output Directory: $output_dir

EOF

    echo ""
    echo "${TEST_BOLD}${TEST_BLUE}FUB Test Framework${TEST_RESET}"
    echo "===================="
    echo ""
    echo "${TEST_BLUE}Test Output:${TEST_RESET} $TEST_LOG_FILE"
    echo "${TEST_BLUE}Verbose Mode:${TEST_RESET} $TEST_VERBOSE"
    echo "${TEST_BLUE}Stop on Failure:${TEST_RESET} $TEST_STOP_ON_FAILURE"
    echo ""
}

# Print test header
print_test_header() {
    local suite_name="$1"

    echo ""
    echo "${TEST_BOLD}${TEST_BLUE}Running Test Suite: $suite_name${TEST_RESET}"
    echo "${TEST_BLUE}$(printf '=%.0s' $(seq 1 ${#suite_name} + 20))${TEST_RESET}"
    echo ""
}

# Print test footer
print_test_footer() {
    local suite_name="$1"

    echo ""
    echo "${TEST_BLUE}$(printf '=%.0s' $(seq 1 ${#suite_name} + 20))${TEST_RESET}"
    echo "${TEST_BLUE}Test Suite Completed: $suite_name${TEST_RESET}"
    echo ""
}

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"

    case "$result" in
        PASS)
            ((TESTS_PASSED++))
            echo "  ${TEST_GREEN}✓ PASS${TEST_RESET} $test_name"
            ;;
        FAIL)
            ((TESTS_FAILED++))
            echo "  ${TEST_RED}✗ FAIL${TEST_RESET} $test_name"
            [[ -n "$message" ]] && echo "    ${TEST_RED}$message${TEST_RESET}"
            ;;
        SKIP)
            ((TESTS_SKIPPED++))
            echo "  ${TEST_YELLOW}- SKIP${TEST_RESET} $test_name"
            [[ -n "$message" ]] && echo "    ${TEST_YELLOW}$message${TEST_RESET}"
            ;;
    esac

    ((TESTS_RUN++))

    # Log to file
    echo "[$result] $test_name${message:+: $message}" >> "$TEST_LOG_FILE"

    # Stop on failure if requested
    if [[ "$result" == "FAIL" ]] && [[ "$TEST_STOP_ON_FAILURE" == "true" ]]; then
        echo ""
        echo "${TEST_RED}Test failed. Stopping as requested.${TEST_RESET}"
        exit 1
    fi
}

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [[ "$expected" == "$actual" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected '$expected', got '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local test_name="$3"

    if [[ "$not_expected" != "$actual" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected not '$not_expected', but got '$actual'"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"

    if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected true, got '$condition'"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local test_name="$2"

    if [[ "$condition" == "false" ]] || [[ "$condition" == "1" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected false, got '$condition'"
        return 1
    fi
}

assert_command_exists() {
    local command="$1"
    local test_name="${2:-Command exists: $command}"

    if command_exists "$command"; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Command '$command' not found"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="${2:-File exists: $file}"

    if file_exists "$file"; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "File '$file' not found"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local test_name="${2:-File not exists: $file}"

    if ! file_exists "$file"; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "File '$file' exists but shouldn't"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local test_name="${2:-Directory exists: $dir}"

    if dir_exists "$dir"; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Directory '$dir' not found"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="${3:-String contains: $needle}"

    if [[ "$haystack" == *"$needle"* ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "String '$haystack' does not contain '$needle'"
        return 1
    fi
}

assert_regex_match() {
    local string="$1"
    local regex="$2"
    local test_name="${3:-Regex match: $regex}"

    if [[ "$string" =~ $regex ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "String '$string' does not match regex '$regex'"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local command="$2"
    local test_name="${3:-Exit code: $expected_code}"

    # Run command and capture exit code
    if eval "$command" >/dev/null 2>&1; then
        local actual_code=0
    else
        local actual_code=$?
    fi

    if [[ "$expected_code" == "$actual_code" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected exit code $expected_code, got $actual_code"
        return 1
    fi
}

assert_success() {
    local command="$1"
    local test_name="${2:-Command succeeds: $command}"

    if eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Command failed: $command"
        return 1
    fi
}

assert_failure() {
    local command="$1"
    local test_name="${2:-Command fails: $command}"

    if eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "FAIL" "Command succeeded but should have failed: $command"
        return 1
    else
        print_test_result "$test_name" "PASS"
        return 0
    fi
}

# Skip test
skip_test() {
    local test_name="$1"
    local reason="${2:-}"

    print_test_result "$test_name" "SKIP" "$reason"
}

# Run test function
run_test() {
    local test_function="$1"
    local test_description="${2:-$test_function}"

    if declare -F "$test_function" >/dev/null; then
        if [[ "$TEST_VERBOSE" == "true" ]]; then
            echo "  Running: $test_function"
        fi

        # Capture output and errors
        local output
        local exit_code=0

        if output=$("$test_function" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi

        if [[ $exit_code -eq 0 ]]; then
            print_test_result "$test_description" "PASS"
            [[ "$TEST_VERBOSE" == "true" && -n "$output" ]] && echo "    Output: $output"
        else
            print_test_result "$test_description" "FAIL" "$output"
        fi
    else
        print_test_result "$test_description" "FAIL" "Test function not found: $test_function"
    fi
}

# Run test suite
run_test_suite() {
    local suite_name="$1"
    local test_functions=("${@:2}")

    print_test_header "$suite_name"

    for test_function in "${test_functions[@]}"; do
        run_test "$test_function"
    done

    print_test_footer "$suite_name"
}

# Print final test summary
print_test_summary() {
    echo ""
    echo "${TEST_BOLD}${TEST_BLUE}Test Summary${TEST_RESET}"
    echo "============"
    echo ""
    echo "${TEST_BLUE}Total Tests Run:${TEST_RESET} $TESTS_RUN"
    echo "${TEST_GREEN}Tests Passed:${TEST_RESET} $TESTS_PASSED"
    echo "${TEST_RED}Tests Failed:${TEST_RESET} $TESTS_FAILED"
    echo "${TEST_YELLOW}Tests Skipped:${TEST_RESET} $TESTS_SKIPPED"
    echo ""

    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$(( TESTS_PASSED * 100 / TESTS_RUN ))
    fi

    echo "${TEST_BLUE}Success Rate:${TEST_RESET} $success_rate%"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "${TEST_BOLD}${TEST_GREEN}✓ All tests passed!${TEST_RESET}"
        return 0
    else
        echo "${TEST_BOLD}${TEST_RED}✗ Some tests failed!${TEST_RESET}"
        echo "${TEST_BLUE}Check the log file for details: $TEST_LOG_FILE${TEST_RESET}"
        return 1
    fi
}

# Discover and run all test files
run_all_tests() {
    local test_pattern="${1:-test-*.sh}"
    local test_dir="${2:-$(dirname "${BASH_SOURCE[0]}")}"

    echo "${TEST_BLUE}Discovering test files in: $test_dir${TEST_RESET}"
    echo "${TEST_BLUE}Test pattern: $test_pattern${TEST_RESET}"
    echo ""

    local test_files=()
    while IFS= read -r -d '' file; do
        # Skip the test framework itself
        [[ "$(basename "$file")" == "test-framework.sh" ]] && continue
        test_files+=("$file")
    done < <(find "$test_dir" -name "$test_pattern" -type f -print0 | sort -z)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "${TEST_YELLOW}No test files found matching pattern: $test_pattern${TEST_RESET}"
        return 1
    fi

    echo "${TEST_BLUE}Found ${#test_files[@]} test file(s)${TEST_RESET}"
    echo ""

    for test_file in "${test_files[@]}"; do
        echo "${TEST_BLUE}Running: $(basename "$test_file")${TEST_RESET}"

        # Source and run the test file
        if source "$test_file"; then
            # Look for a main test function
            if declare -F "main_test" >/dev/null; then
                main_test
            else
                echo "${TEST_YELLOW}No main_test function found in $test_file${TEST_RESET}"
            fi
        else
            echo "${TEST_RED}Failed to source test file: $test_file${TEST_RESET}"
        fi

        echo ""
    done

    print_test_summary
}

# Mock functions for testing
mock_command() {
    local command="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"

    # Create a mock function
    eval "mock_$command() {
        echo '$mock_output'
        return $mock_exit_code
    }"

    # Override PATH to use mock
    export PATH="$(mktemp -d):$PATH"
    ln -s "$(command -v bash)" "$(dirname "$PATH")/$command"
}

# Restore mocked commands
restore_mock() {
    # Restore original PATH
    local original_path
    original_path=$(echo "$PATH" | sed 's|^[^:]*:||')
    export PATH="$original_path"
}

# Create test environment
setup_test_env() {
    local test_dir="${1:-/tmp/fub-test-$$}"

    # Create test directory
    mkdir -p "$test_dir"

    # Set test environment variables
    export FUB_TEST_MODE="true"
    export FUB_TEST_DIR="$test_dir"
    export FUB_CONFIG_DIR="$test_dir/config"
    export FUB_CACHE_DIR="$test_dir/cache"

    echo "$test_dir"
}

# Cleanup test environment
cleanup_test_env() {
    local test_dir="${1:-$FUB_TEST_DIR}"

    if [[ -n "$test_dir" ]] && [[ -d "$test_dir" ]]; then
        rm -rf "$test_dir"
    fi

    # Unset test environment variables
    unset FUB_TEST_MODE FUB_TEST_DIR FUB_CONFIG_DIR FUB_CACHE_DIR
}

# Export functions for use in test files
export -f init_test_framework print_test_header print_test_footer print_test_result
export -f assert_equals assert_not_equals assert_true assert_false
export -f assert_command_exists assert_file_exists assert_file_not_exists assert_dir_exists
export -f assert_contains assert_regex_match assert_exit_code assert_success assert_failure
export -f skip_test run_test run_test_suite print_test_summary run_all_tests
export -f mock_command restore_mock setup_test_env cleanup_test_env

# Source common utilities if needed
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    source "${TEST_ROOT_DIR}/lib/common.sh"
fi