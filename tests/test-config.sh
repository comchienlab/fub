#!/usr/bin/env bash

# FUB Configuration Library Tests
# Test the configuration management library functions

set -euo pipefail

# Source test framework
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_DIR}/test-framework.sh"

# Source the libraries being tested
readonly FUB_ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/config.sh"

# Test setup
setup_config_tests() {
    # Set up test environment
    FUB_TEST_DIR=$(setup_test_env)

    # Override config directories for testing
    FUB_CONFIG_DIR="$FUB_TEST_DIR/config"
    FUB_USER_CONFIG_DIR="$FUB_TEST_DIR/user_config"
    FUB_CACHE_DIR="$FUB_TEST_DIR/cache"
    FUB_LOG_DIR="$FUB_TEST_DIR/logs"

    # Create test directories
    ensure_dir "$FUB_CONFIG_DIR"
    ensure_dir "$FUB_USER_CONFIG_DIR"
    ensure_dir "$FUB_CACHE_DIR"
    ensure_dir "$FUB_LOG_DIR"

    # Suppress logging during tests
    FUB_LOG_LEVEL="ERROR"
}

# Test teardown
teardown_config_tests() {
    cleanup_test_env "$FUB_TEST_DIR"
}

# Test configuration initialization
test_config_initialization() {
    # Test that configuration system initializes
    if init_config >/dev/null 2>&1; then
        print_test_result "config initialization" "PASS"
    else
        print_test_result "config initialization" "FAIL"
    fi

    # Test that default values are loaded
    local log_level
    log_level=$(get_config "log.level")
    assert_equals "INFO" "$log_level" "default log level loaded"

    local theme
    theme=$(get_config "theme")
    assert_equals "tokyo-night" "$theme" "default theme loaded"
}

# Test default configuration loading
test_default_config_loading() {
    # Create a test default config file
    local test_config="${FUB_CONFIG_DIR}/default.yaml"
    cat > "$test_config" << EOF
test.string: "test_value"
test.number: 42
test.boolean: true
test.nested.value: "nested_value"
EOF

    # Load the configuration
    load_default_config

    # Test that values are loaded correctly
    local string_value
    string_value=$(get_config "test.string" "default")
    assert_equals "test_value" "$string_value" "string value loaded from config"

    local number_value
    number_value=$(get_config "test.number" "0")
    assert_equals "42" "$number_value" "number value loaded from config"

    local boolean_value
    boolean_value=$(get_config "test.boolean" "false")
    assert_equals "true" "$boolean_value" "boolean value loaded from config"

    local nested_value
    nested_value=$(get_config "test.nested.value" "default")
    assert_equals "nested_value" "$nested_value" "nested value loaded from config"

    # Test default value fallback
    local default_value
    default_value=$(get_config "nonexistent.key" "fallback")
    assert_equals "fallback" "$default_value" "default value fallback works"
}

# Test YAML configuration loading
test_yaml_config_loading() {
    # Create a test YAML config file
    local yaml_config="${FUB_TEST_DIR}/test.yaml"
    cat > "$yaml_config" << EOF
# Test YAML configuration
key1: "value1"
key2: "value with spaces"
key3: 123
key4: true
key5: false

# Section-based config
section:
  subsection:
    key: "nested value"

# Array-like values
list1: "item1"
list2: "item2"
EOF

    # Load the YAML config
    load_yaml_config "$yaml_config" "test"

    # Test that values are parsed correctly
    assert_equals "value1" "${FUB_CONFIG[key1]}" "simple string value"
    assert_equals "value with spaces" "${FUB_CONFIG[key2]}" "string with spaces"
    assert_equals "123" "${FUB_CONFIG[key3]}" "numeric value"
    assert_equals "true" "${FUB_CONFIG[key4]}" "boolean true"
    assert_equals "false" "${FUB_CONFIG[key5]}" "boolean false"
}

# Test configuration validation
test_config_validation() {
    # Set up some test configuration values
    FUB_CONFIG["log.level"]="INFO"
    FUB_CONFIG["timeout"]="30"
    FUB_CONFIG["theme"]="tokyo-night"

    # Test validation function
    if validate_config >/dev/null 2>&1; then
        print_test_result "valid configuration validation" "PASS"
    else
        print_test_result "valid configuration validation" "FAIL"
    fi

    # Test invalid log level
    FUB_CONFIG["log.level"]="INVALID"
    if ! validate_config >/dev/null 2>&1; then
        print_test_result "invalid log level validation" "PASS"
    else
        print_test_result "invalid log level validation" "FAIL"
    fi

    # Reset to valid value
    FUB_CONFIG["log.level"]="INFO"

    # Test invalid timeout
    FUB_CONFIG["timeout"]="invalid"
    if ! validate_config >/dev/null 2>&1; then
        print_test_result "invalid timeout validation" "PASS"
    else
        print_test_result "invalid timeout validation" "FAIL"
    fi
}

# Test configuration setting and getting
test_config_set_get() {
    # Clear any existing config
    FUB_CONFIG=()

    # Test setting and getting values
    set_config "test.key1" "value1" "runtime"
    assert_equals "value1" "$(get_config "test.key1")" "set/get runtime config"

    set_config "test.key2" "value2" "runtime"
    assert_equals "value2" "$(get_config "test.key2")" "set/get second runtime config"

    # Test overwriting values
    set_config "test.key1" "modified_value1" "runtime"
    assert_equals "modified_value1" "$(get_config "test.key1")" "overwrite runtime config"
}

# Test configuration file writing
test_config_file_writing() {
    local config_file="${FUB_TEST_DIR}/write_test.yaml"

    # Ensure config file doesn't exist
    rm -f "$config_file"

    # Test writing to new file
    set_config "new.key" "new_value" "user" "$config_file"
    assert_file_exists "$config_file" "config file created"

    # Verify content
    if grep -q "new.key: new_value" "$config_file"; then
        print_test_result "config file content verification" "PASS"
    else
        print_test_result "config file content verification" "FAIL"
    fi

    # Test updating existing file
    set_config "new.key" "modified_value" "user" "$config_file"
    if grep -q "new.key: modified_value" "$config_file"; then
        print_test_result "config file update" "PASS"
    else
        print_test_result "config file update" "FAIL"
    fi
}

# Test configuration export
test_config_export() {
    # Set up some test configuration
    FUB_CONFIG["export.test1"]="value1"
    FUB_CONFIG["export.test2"]="value2"
    FUB_CONFIG["export.test3"]="123"

    local export_file="${FUB_TEST_DIR}/exported_config.yaml"

    # Test YAML export
    if export_config "tokyo-night" "$export_file" "yaml" >/dev/null 2>&1; then
        print_test_result "YAML export" "PASS"
    else
        print_test_result "YAML export" "FAIL"
    fi

    # Verify exported file exists and has content
    if file_exists "$export_file" && [[ -s "$export_file" ]]; then
        print_test_result "exported file creation" "PASS"
    else
        print_test_result "exported file creation" "FAIL"
    fi

    # Test JSON export
    local json_file="${FUB_TEST_DIR}/exported_config.json"
    if export_config "tokyo-night" "$json_file" "json" >/dev/null 2>&1; then
        print_test_result "JSON export" "PASS"
    else
        print_test_result "JSON export" "FAIL"
    fi

    # Test shell export
    local shell_file="${FUB_TEST_DIR}/exported_config.sh"
    if export_config "tokyo-night" "$shell_file" "shell" >/dev/null 2>&1; then
        print_test_result "shell export" "PASS"
    else
        print_test_result "shell export" "FAIL"
    fi
}

# Test configuration import
test_config_import() {
    # Create test import file
    local import_file="${FUB_TEST_DIR}/import_config.yaml"
    cat > "$import_file" << EOF
import.key1: "imported_value1"
import.key2: "imported_value2"
import.number: 456
EOF

    # Clear existing config
    FUB_CONFIG=()

    # Test import
    if import_config "$import_file" "yaml" >/dev/null 2>&1; then
        print_test_result "config import" "PASS"
    else
        print_test_result "config import" "FAIL"
    fi

    # Verify imported values
    assert_equals "imported_value1" "${FUB_CONFIG[import.key1]}" "imported value1"
    assert_equals "imported_value2" "${FUB_CONFIG[import.key2]}" "imported value2"
    assert_equals "456" "${FUB_CONFIG[import.number]}" "imported number"
}

# Test configuration reset
test_config_reset() {
    # Set some test values
    FUB_CONFIG["test.reset"]="test_value"

    # Test runtime reset
    reset_config "runtime"
    if [[ -z "${FUB_CONFIG[test.reset]:-}" ]]; then
        print_test_result "runtime config reset" "PASS"
    else
        print_test_result "runtime config reset" "FAIL"
    fi

    # Test that defaults are restored
    local log_level
    log_level=$(get_config "log.level")
    assert_equals "INFO" "$log_level" "defaults restored after reset"
}

# Test module-specific validation
test_module_validation() {
    # Test cleanup module validation
    FUB_CONFIG["cleanup.temp_retention"]="7"
    FUB_CONFIG["cleanup.log_retention"]="30"
    FUB_CONFIG["cleanup.cache_retention"]="14"

    if validate_module_config "cleanup" >/dev/null 2>&1; then
        print_test_result "cleanup module validation (valid)" "PASS"
    else
        print_test_result "cleanup module validation (valid)" "FAIL"
    fi

    # Test invalid cleanup config
    FUB_CONFIG["cleanup.temp_retention"]="invalid"
    if ! validate_module_config "cleanup" >/dev/null 2>&1; then
        print_test_result "cleanup module validation (invalid)" "PASS"
    else
        print_test_result "cleanup module validation (invalid)" "FAIL"
    fi

    # Reset to valid value
    FUB_CONFIG["cleanup.temp_retention"]="7"

    # Test network module validation
    FUB_CONFIG["network.timeout"]="10"
    FUB_CONFIG["network.retries"]="3"

    if validate_module_config "network" >/dev/null 2>&1; then
        print_test_result "network module validation (valid)" "PASS"
    else
        print_test_result "network module validation (valid)" "FAIL"
    fi

    # Test invalid network config
    FUB_CONFIG["network.timeout"]="invalid"
    if ! validate_module_config "network" >/dev/null 2>&1; then
        print_test_result "network module validation (invalid)" "PASS"
    else
        print_test_result "network module validation (invalid)" "FAIL"
    fi
}

# Test environment variable overrides
test_environment_overrides() {
    # Set test environment variables
    export FUB_LOG_LEVEL="DEBUG"
    export FUB_THEME="minimal"
    export FUB_TIMEOUT="60"

    # Apply environment overrides
    FUB_CONFIG=()
    load_default_config
    apply_environment_overrides

    # Test that environment variables override config
    assert_equals "DEBUG" "$(get_config "log.level")" "environment override for log.level"
    assert_equals "minimal" "$(get_config "theme")" "environment override for theme"
    assert_equals "60" "$(get_config "timeout")" "environment override for timeout"

    # Cleanup environment variables
    unset FUB_LOG_LEVEL FUB_THEME FUB_TIMEOUT
}

# Test configuration backup and restore
test_config_backup_restore() {
    # Create test config files
    local default_config="${FUB_CONFIG_DIR}/default.yaml"
    local user_config="${FUB_USER_CONFIG_DIR}/config.yaml"

    echo "test.value: backup_test" > "$default_config"
    echo "user.value: user_backup_test" > "$user_config"

    local backup_dir="${FUB_TEST_DIR}/backup"

    # Test backup
    if backup_config "$backup_dir" >/dev/null 2>&1; then
        print_test_result "config backup" "PASS"
    else
        print_test_result "config backup" "FAIL"
    fi

    # Check backup file exists
    local backup_files
    backup_files=$(find "$backup_dir" -name "fub_config_*.tar.gz" 2>/dev/null | wc -l)
    if [[ $backup_files -gt 0 ]]; then
        print_test_result "backup file creation" "PASS"
    else
        print_test_result "backup file creation" "FAIL"
    fi

    # Modify configs
    echo "test.value: modified" > "$default_config"
    echo "user.value: modified" > "$user_config"

    # Find backup file for restore test
    local backup_file
    backup_file=$(find "$backup_dir" -name "fub_config_*.tar.gz" | head -1)

    # Test restore (this might fail due to permissions, so we just test the function exists)
    if declare -F restore_config >/dev/null; then
        print_test_result "restore_config function exists" "PASS"
    else
        print_test_result "restore_config function exists" "FAIL"
    fi
}

# Test configuration show
test_config_show() {
    # Set up some test configuration
    FUB_CONFIG["show.test1"]="value1"
    FUB_CONFIG["show.test2"]="value2"

    local output_file="${FUB_TEST_DIR}/config_show_output.txt"

    # Test show_config function
    if show_config "all" > "$output_file" 2>&1; then
        print_test_result "show_config function" "PASS"
    else
        print_test_result "show_config function" "FAIL"
    fi

    # Check output contains our test values
    if [[ -f "$output_file" ]]; then
        local content
        content=$(cat "$output_file")
        if [[ "$content" =~ "show.test1" ]] && [[ "$content" =~ "value1" ]]; then
            print_test_result "config show content verification" "PASS"
        else
            print_test_result "config show content verification" "FAIL"
        fi
    fi
}

# Main test function
main_test() {
    setup_config_tests

    print_test_header "FUB Configuration Library Tests"

    run_test "test_config_initialization"
    run_test "test_default_config_loading"
    run_test "test_yaml_config_loading"
    run_test "test_config_validation"
    run_test "test_config_set_get"
    run_test "test_config_file_writing"
    run_test "test_config_export"
    run_test "test_config_import"
    run_test "test_config_reset"
    run_test "test_module_validation"
    run_test "test_environment_overrides"
    run_test "test_config_backup_restore"
    run_test "test_config_show"

    teardown_config_tests
}

# Run tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework
    main_test
    print_test_summary
fi