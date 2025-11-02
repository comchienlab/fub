#!/usr/bin/env bash

# FUB UI Library Tests
# Test the user interface library functions

set -euo pipefail

# Source test framework
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_DIR}/test-framework.sh"

# Source the libraries being tested
readonly FUB_ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/theme.sh"
source "${FUB_ROOT_DIR}/lib/ui.sh"

# Test setup
setup_ui_tests() {
    # Set up test environment
    FUB_TEST_DIR=$(setup_test_env)

    # Initialize theme system
    init_theme "minimal"

    # Initialize UI system
    init_ui false true false  # non-interactive, quiet, no verbose
}

# Test teardown
teardown_ui_tests() {
    cleanup_test_env "$FUB_TEST_DIR"
}

# Test UI initialization
test_ui_initialization() {
    # Test that UI system initializes correctly
    local interactive=true
    local quiet=false
    local verbose=false

    init_ui "$interactive" "$quiet" "$verbose"

    assert_equals "$interactive" "$FUB_INTERACTIVE_MODE" "UI interactive mode set correctly"
    assert_equals "$quiet" "$FUB_QUIET_MODE" "UI quiet mode set correctly"
    assert_equals "$verbose" "$FUB_VERBOSE_MODE" "UI verbose mode set correctly"

    print_test_result "UI initialization" "PASS"
}

# Test printing functions
test_printing_functions() {
    # Test that printing functions don't crash
    # We can't easily test output without complex redirection,
    # so we just verify the functions run without error

    if init_ui false false false >/dev/null 2>&1; then
        print_test_result "UI initialization for printing tests" "PASS"
    else
        print_test_result "UI initialization for printing tests" "FAIL"
        return 1
    fi

    # Test print functions (redirect output to avoid cluttering test output)
    local output_file="${FUB_TEST_DIR}/output.txt"

    # Test basic printing functions
    print_success "Test success message" > "$output_file" 2>&1
    if [[ $? -eq 0 ]] && [[ -f "$output_file" ]]; then
        print_test_result "print_success function" "PASS"
    else
        print_test_result "print_success function" "FAIL"
    fi

    print_error "Test error message" > "$output_file" 2>&1
    if [[ $? -eq 0 ]] && [[ -f "$output_file" ]]; then
        print_test_result "print_error function" "PASS"
    else
        print_test_result "print_error function" "FAIL"
    fi

    print_warning "Test warning message" > "$output_file" 2>&1
    if [[ $? -eq 0 ]] && [[ -f "$output_file" ]]; then
        print_test_result "print_warning function" "PASS"
    else
        print_test_result "print_warning function" "FAIL"
    fi

    print_info "Test info message" > "$output_file" 2>&1
    if [[ $? -eq 0 ]] && [[ -f "$output_file" ]]; then
        print_test_result "print_info function" "PASS"
    else
        print_test_result "print_info function" "FAIL"
    fi

    print_debug "Test debug message" > "$output_file" 2>&1
    if [[ $? -eq 0 ]] && [[ -f "$output_file" ]]; then
        print_test_result "print_debug function" "PASS"
    else
        print_test_result "print_debug function" "FAIL"
    fi
}

# Test input validation functions
test_input_validation() {
    # Test validate_input function
    assert_true "validate_input \"test@example.com\" \"email\"" "validate_input with valid email"
    assert_false "validate_input \"invalid-email\" \"email\"" "validate_input with invalid email"

    assert_true "validate_input \"https://example.com\" \"url\"" "validate_input with valid URL"
    assert_false "validate_input \"not-a-url\" \"url\"" "validate_input with invalid URL"

    assert_true "validate_input \"123\" \"number\"" "validate_input with valid number"
    assert_false "validate_input \"not-a-number\" \"number\"" "validate_input with invalid number"

    assert_true "validate_input \"80\" \"port\"" "validate_input with valid port"
    assert_false "validate_input \"70000\" \"port\"" "validate_input with invalid port"

    assert_true "validate_input \"test\" \"pattern\" \"^test$\"" "validate_input with valid pattern"
    assert_false "validate_input \"not-test\" \"pattern\" \"^test$\"" "validate_input with invalid pattern"
}

# Test table printing
test_table_printing() {
    local output_file="${FUB_TEST_DIR}/table_output.txt"

    # Test data for table
    local -a test_data=(
        "Name Age City"
        "Alice 25 NewYork"
        "Bob 30 LosAngeles"
        "Charlie 35 Chicago"
    )

    # Test that table printing doesn't crash
    if print_table test_data "Name Age City" "|" > "$output_file" 2>&1; then
        print_test_result "print_table function" "PASS"
    else
        print_test_result "print_table function" "FAIL"
    fi

    # Check that output file was created and has content
    if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
        print_test_result "table output file created" "PASS"
    else
        print_test_result "table output file created" "FAIL"
    fi

    # Test with empty data
    local -a empty_data=()
    if print_table empty_data "Header1 Header2" "|" > "$output_file" 2>&1; then
        print_test_result "print_table with empty data" "PASS"
    else
        print_test_result "print_table with empty data" "FAIL"
    fi
}

# Test progress bar
test_progress_bar() {
    local output_file="${FUB_TEST_DIR}/progress_output.txt"

    # Test progress bar with different values
    if show_progress 0 100 "Testing..." > "$output_file" 2>&1; then
        print_test_result "show_progress function (0%)" "PASS"
    else
        print_test_result "show_progress function (0%)" "FAIL"
    fi

    if show_progress 50 100 "Testing..." > "$output_file" 2>&1; then
        print_test_result "show_progress function (50%)" "PASS"
    else
        print_test_result "show_progress function (50%)" "FAIL"
    fi

    if show_progress 100 100 "Complete" > "$output_file" 2>&1; then
        print_test_result "show_progress function (100%)" "PASS"
    else
        print_test_result "show_progress function (100%)" "FAIL"
    fi
}

# Test status formatting
test_status_formatting() {
    local output_file="${FUB_TEST_DIR}/status_output.txt"

    # Test different status types
    local status_types=("success" "error" "warning" "info" "loading" "unknown")

    for status in "${status_types[@]}"; do
        if format_status "$status" "Test message" > "$output_file" 2>&1; then
            print_test_result "format_status with $status" "PASS"
        else
            print_test_result "format_status with $status" "FAIL"
        fi
    done
}

# Test box printing
test_box_printing() {
    local output_file="${FUB_TEST_DIR}/box_output.txt"

    # Test box printing
    if print_box "Test Title" "Test content inside the box" 40 > "$output_file" 2>&1; then
        print_test_result "print_box function" "PASS"
    else
        print_test_result "print_box function" "FAIL"
    fi

    # Check that output contains box elements
    if [[ -f "$output_file" ]]; then
        local content
        content=$(cat "$output_file")
        if [[ "$content" =~ "Test Title" ]] && [[ "$content" =~ "Test content" ]]; then
            print_test_result "box content verification" "PASS"
        else
            print_test_result "box content verification" "FAIL"
        fi
    fi
}

# Test system status display
test_system_status() {
    local output_file="${FUB_TEST_DIR}/status_display_output.txt"

    # Test system status display
    local -a status_items=(
        "SSH:running"
        "UFW:active"
        "Service:stopped"
    )

    if display_system_status "${status_items[@]}" > "$output_file" 2>&1; then
        print_test_result "display_system_status function" "PASS"
    else
        print_test_result "display_system_status function" "FAIL"
    fi

    # Check output contains status items
    if [[ -f "$output_file" ]]; then
        local content
        content=$(cat "$output_file")
        if [[ "$content" =~ "SSH" ]] && [[ "$content" =~ "UFW" ]]; then
            print_test_result "system status content verification" "PASS"
        else
            print_test_result "system status content verification" "FAIL"
        fi
    fi
}

# Test color support detection
test_color_support() {
    # Test supports_colors function
    if supports_colors; then
        print_test_result "supports_colors function" "PASS" "Colors supported"
    else
        print_test_result "supports_colors function" "PASS" "Colors not supported"
    fi
}

# Test interactive mode functions
test_interactive_functions() {
    # Test that interactive functions exist
    local interactive_functions=(
        "ask_question"
        "ask_confirmation"
        "ask_password"
        "select_menu"
        "select_multiple"
    )

    for func in "${interactive_functions[@]}"; do
        if declare -F "$func" >/dev/null; then
            print_test_result "$func function exists" "PASS"
        else
            print_test_result "$func function exists" "FAIL"
        fi
    done

    # Test that get_validated_input exists
    if declare -F get_validated_input >/dev/null; then
        print_test_result "get_validated_input function exists" "PASS"
    else
        print_test_result "get_validated_input function exists" "FAIL"
    fi
}

# Test UI state management
test_ui_state() {
    # Test UI mode settings
    init_ui true false true  # interactive, not quiet, verbose
    assert_true "$FUB_INTERACTIVE_MODE" "interactive mode enabled"
    assert_false "$FUB_QUIET_MODE" "quiet mode disabled"
    assert_true "$FUB_VERBOSE_MODE" "verbose mode enabled"

    init_ui false true false  # not interactive, quiet, not verbose
    assert_false "$FUB_INTERACTIVE_MODE" "interactive mode disabled"
    assert_true "$FUB_QUIET_MODE" "quiet mode enabled"
    assert_false "$FUB_VERBOSE_MODE" "verbose mode disabled"

    print_test_result "UI state management" "PASS"
}

# Main test function
main_test() {
    setup_ui_tests

    print_test_header "FUB UI Library Tests"

    run_test "test_ui_initialization"
    run_test "test_printing_functions"
    run_test "test_input_validation"
    run_test "test_table_printing"
    run_test "test_progress_bar"
    run_test "test_status_formatting"
    run_test "test_box_printing"
    run_test "test_system_status"
    run_test "test_color_support"
    run_test "test_interactive_functions"
    run_test "test_ui_state"

    teardown_ui_tests
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    main_test
    print_test_summary
fi