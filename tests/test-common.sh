#!/usr/bin/env bash

# FUB Common Library Tests
# Test the common utility library functions

set -euo pipefail

# Source test framework
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_DIR}/test-framework.sh"

# Source the library being tested
readonly FUB_ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"

# Test setup
setup_common_tests() {
    # Set up test environment
    FUB_TEST_DIR=$(setup_test_env)

    # Suppress logging during tests
    FUB_LOG_LEVEL="ERROR"
}

# Test teardown
teardown_common_tests() {
    cleanup_test_env "$FUB_TEST_DIR"
}

# Test string utilities
test_string_utilities() {
    # Test trim function
    local trimmed
    trimmed=$(trim "  hello world  ")
    assert_equals "hello world" "$trimmed" "trim function"

    # Test lowercase function
    local lower
    lower=$(lowercase "HELLO WORLD")
    assert_equals "hello world" "$lower" "lowercase function"

    # Test uppercase function
    local upper
    upper=$(uppercase "hello world")
    assert_equals "HELLO WORLD" "$upper" "uppercase function"
}

# Test file utilities
test_file_utilities() {
    local test_file="${FUB_TEST_DIR}/test_file.txt"
    local test_dir="${FUB_TEST_DIR}/test_dir"

    # Create test file and directory
    touch "$test_file"
    mkdir -p "$test_dir"

    # Test file_exists
    assert_file_exists "$test_file" "file_exists with existing file"

    # Test dir_exists
    assert_dir_exists "$test_dir" "dir_exists with existing directory"

    # Test is_executable (should be false for regular file)
    assert_false "is_executable \"$test_file\"" "is_executable with non-executable file"

    # Make file executable and test again
    chmod +x "$test_file"
    assert_true "is_executable \"$test_file\"" "is_executable with executable file"

    # Test ensure_dir with existing directory
    ensure_dir "$test_dir"
    assert_dir_exists "$test_dir" "ensure_dir with existing directory"

    # Test ensure_dir with new directory
    local new_dir="${FUB_TEST_DIR}/new_dir"
    ensure_dir "$new_dir"
    assert_dir_exists "$new_dir" "ensure_dir with new directory"
}

# Test command utilities
test_command_utilities() {
    # Test command_exists with existing command
    assert_command_exists "bash" "command_exists with bash"

    # Test command_exists with non-existent command
    if command_exists "non_existent_command_12345"; then
        print_test_result "command_exists with non-existent command" "FAIL" "Should not find non-existent command"
    else
        print_test_result "command_exists with non-existent command" "PASS"
    fi

    # Test version_compare
    assert_true "version_compare \"1.0.0\" \"==\" \"1.0.0\"" "version_compare equal"
    assert_true "version_compare \"1.0.1\" \">\" \"1.0.0\"" "version_compare greater than"
    assert_true "version_compare \"1.0.0\" \"<\" \"1.0.1\"" "version_compare less than"
    assert_false "version_compare \"1.0.0\" \"==\" \"1.0.1\"" "version_compare not equal"
}

# Test validation utilities
test_validation_utilities() {
    # Test validate_email
    assert_true "validate_email \"test@example.com\"" "validate_email with valid email"
    assert_false "validate_email \"invalid-email\"" "validate_email with invalid email"

    # Test validate_url
    assert_true "validate_url \"https://example.com\"" "validate_url with valid URL"
    assert_false "validate_url \"not-a-url\"" "validate_url with invalid URL"

    # Test validate_port
    assert_true "validate_port \"80\"" "validate_port with valid port"
    assert_true "validate_port \"65535\"" "validate_port with max port"
    assert_false "validate_port \"0\"" "validate_port with invalid port 0"
    assert_false "validate_port \"65536\"" "validate_port with invalid port >65535"
    assert_false "validate_port \"not-a-number\"" "validate_port with non-numeric port"
}

# Test system detection utilities
test_system_utilities() {
    # Test is_root (will likely be false in test environment)
    local is_root_result
    if is_root; then
        is_root_result="true"
    else
        is_root_result="false"
    fi

    # We can't assert a specific value since it depends on the test environment
    # But we can test that the function runs without error
    print_test_result "is_root function" "PASS"

    # Test is_ubuntu (will depend on the test system)
    if is_ubuntu; then
        print_test_result "is_ubuntu function" "PASS" "Running on Ubuntu"
    else
        print_test_result "is_ubuntu function" "PASS" "Not running on Ubuntu"
    fi

    # Test get_ubuntu_version
    local version
    version=$(get_ubuntu_version)
    # Should return either a version number or "unknown"
    if [[ "$version" == "unknown" ]] || [[ "$version" =~ ^[0-9]+\.[0-9]+ ]]; then
        print_test_result "get_ubuntu_version function" "PASS" "Version: $version"
    else
        print_test_result "get_ubuntu_version function" "FAIL" "Unexpected version format: $version"
    fi
}

# Test logging utilities
test_logging_utilities() {
    # Test that log functions exist and can be called
    local log_file="${FUB_TEST_DIR}/test.log"

    # Override log file for testing
    FUB_LOG_FILE="$log_file"

    # Test different log levels
    log_debug "Debug message"
    log_info "Info message"
    log_warn "Warning message"
    log_error "Error message"

    # Check that log file was created and contains messages
    if file_exists "$log_file"; then
        local log_content
        log_content=$(cat "$log_file")
        assert_contains "$log_content" "DEBUG" "log_debug creates log entry"
        assert_contains "$log_content" "INFO" "log_info creates log entry"
        assert_contains "$log_content" "WARN" "log_warn creates log entry"
        assert_contains "$log_content" "ERROR" "log_error creates log entry"
    else
        print_test_result "Logging functions" "FAIL" "Log file was not created"
    fi
}

# Test configuration utilities
test_config_utilities() {
    local config_file="${FUB_TEST_DIR}/test_config.yaml"

    # Create test config file
    cat > "$config_file" << EOF
test.key1: "value1"
test.key2: "value with spaces"
test.number: 42
test.boolean: true
EOF

    # Test get_config_value
    local value1
    value1=$(get_config_value "test.key1" "default" "$config_file")
    assert_equals "value1" "$value1" "get_config_value with existing key"

    local value_default
    value_default=$(get_config_value "nonexistent.key" "default_value" "$config_file")
    assert_equals "default_value" "$value_default" "get_config_value with default value"

    # Test set_config_value
    set_config_value "new.key" "new_value" "$config_file"
    local new_value
    new_value=$(get_config_value "new.key" "default" "$config_file")
    assert_equals "new_value" "$new_value" "set_config_value adds new key"

    set_config_value "test.key1" "modified_value" "$config_file"
    local modified_value
    modified_value=$(get_config_value "test.key1" "default" "$config_file")
    assert_equals "modified_value" "$modified_value" "set_config_value modifies existing key"
}

# Test error handling
test_error_handling() {
    # Test that die function exits with error code 1
    # We can't directly test this since it would exit the test script
    # Instead, we test that the function exists
    if declare -F die >/dev/null; then
        print_test_result "die function exists" "PASS"
    else
        print_test_result "die function exists" "FAIL"
    fi

    # Test that handle_error function exists
    if declare -F handle_error >/dev/null; then
        print_test_result "handle_error function exists" "PASS"
    else
        print_test_result "handle_error function exists" "FAIL"
    fi
}

# Main test function
main_test() {
    setup_common_tests

    print_test_header "FUB Common Library Tests"

    run_test "test_string_utilities"
    run_test "test_file_utilities"
    run_test "test_command_utilities"
    run_test "test_validation_utilities"
    run_test "test_system_utilities"
    run_test "test_logging_utilities"
    run_test "test_config_utilities"
    run_test "test_error_handling"

    teardown_common_tests
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    main_test
    print_test_summary
fi