#!/usr/bin/env bash

# FUB Migration and Backward Compatibility Test Suite
# Tests migration utilities, legacy mode, and rollback procedures

set -euo pipefail

# Test configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FUB_ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
readonly TEST_WORK_DIR="${TEST_DIR}/workdir"
readonly TEST_LEGACY_CONFIG="${TEST_WORK_DIR}/.fubrc"
readonly TEST_NEW_CONFIG="${TEST_WORK_DIR}/config.yaml"
readonly TEST_SCRIPT="${TEST_WORK_DIR}/test-script.sh"

# Test colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_environment() {
    echo -e "${CYAN}Setting up test environment...${NC}"

    # Create test work directory
    rm -rf "$TEST_WORK_DIR"
    mkdir -p "$TEST_WORK_DIR"

    # Create legacy configuration file
    cat > "$TEST_LEGACY_CONFIG" << 'EOF'
# Test legacy FUB configuration
CLEANUP_RETENTION_DAYS=7
CLEANUP_VERBOSE=true
CLEANUP_DRY_RUN=false
FUB_THEME=tokyo-night
FUB_LOG_LEVEL=INFO
FUB_COLORS=true
EOF

    # Create test script with legacy commands
    cat > "$TEST_SCRIPT" << 'EOF'
#!/bin/bash

# Test script with legacy FUB commands
echo "Running legacy cleanup operations..."

fub --clean --dry-run
fub --temp --force
fub --cache --verbose
fub --logs
fub --all

echo "Legacy cleanup completed"
EOF

    chmod +x "$TEST_SCRIPT"

    echo -e "${GREEN}✓ Test environment setup complete${NC}"
}

# Cleanup test environment
cleanup_test_environment() {
    echo -e "${CYAN}Cleaning up test environment...${NC}"
    rm -rf "$TEST_WORK_DIR"
    echo -e "${GREEN}✓ Test environment cleaned up${NC}"
}

# Test utility functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    echo -e "\n${BLUE}Running test: ${test_name}${NC}"
    ((TESTS_RUN++))

    if eval "$test_command" >/dev/null 2>&1; then
        local actual_exit_code=$?
        if [[ $actual_exit_code -eq $expected_exit_code ]]; then
            echo -e "${GREEN}✓ PASS: ${test_name}${NC}"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "${RED}✗ FAIL: ${test_name} (exit code: $actual_exit_code, expected: $expected_exit_code)${NC}"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL: ${test_name} (command failed)${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Legacy compatibility module loading
test_legacy_compatibility_module() {
    run_test "Legacy compatibility module loading" \
        "source '${FUB_ROOT_DIR}/lib/legacy/compatibility.sh' && command -v parse_legacy_args"
}

# Test 2: Legacy mode initialization
test_legacy_mode_init() {
    run_test "Legacy mode initialization" \
        "FUB_LEGACY_MODE=true source '${FUB_ROOT_DIR}/lib/legacy/legacy-mode.sh' && [[ \"\$FUB_LEGACY_ACTIVE\" == \"true\" ]]"
}

# Test 3: Legacy command mapping
test_legacy_command_mapping() {
    run_test "Legacy command mapping" \
        "source '${FUB_ROOT_DIR}/lib/legacy/compatibility.sh' && [[ \"\$(map_legacy_command 'clean')\" == \"cleanup\" ]]"
}

# Test 4: Legacy configuration detection
test_legacy_config_detection() {
    run_test "Legacy configuration detection" \
        "cd '$TEST_WORK_DIR' && source '${FUB_ROOT_DIR}/lib/legacy/config-migration.sh' && init_migration_system && detect_legacy_configs | grep -q '.fubrc'"
}

# Test 5: Configuration migration
test_config_migration() {
    run_test "Configuration migration" \
        "cd '$TEST_WORK_DIR' && source '${FUB_ROOT_DIR}/lib/legacy/config-migration.sh' && init_migration_system && migrate_configuration '$TEST_LEGACY_CONFIG' '$TEST_NEW_CONFIG' && [[ -f '$TEST_NEW_CONFIG' ]]"
}

# Test 6: Script validation
test_script_validation() {
    run_test "Script validation" \
        "source '${FUB_ROOT_DIR}/lib/legacy/compatibility.sh' && validate_legacy_script '$TEST_SCRIPT' 2>&1 | grep -q 'deprecated pattern'"
}

# Test 7: Rollback system initialization
test_rollback_system_init() {
    run_test "Rollback system initialization" \
        "source '${FUB_ROOT_DIR}/lib/legacy/rollback.sh' && init_rollback_system && [[ -d \"\$FUB_ROLLBACK_DIR\" ]]"
}

# Test 8: Rollback point creation
test_rollback_point_creation() {
    run_test "Rollback point creation" \
        "source '${FUB_ROOT_DIR}/lib/legacy/rollback.sh' && init_rollback_system && create_rollback_point 'test-rollback' 'Test rollback point' && [[ -d \"${FUB_ROLLBACK_DIR}/test-rollback\" ]]"
}

# Test 9: FUB main executable legacy mode
test_fub_legacy_mode() {
    run_test "FUB main executable legacy mode" \
        "cd '$TEST_WORK_DIR' && FUB_LEGACY_MODE=true '${FUB_ROOT_DIR}/bin/fub' --help | grep -q 'FUB - Fast Ubuntu Utility Toolkit'"
}

# Test 10: FUB migration commands
test_fub_migration_commands() {
    run_test "FUB migration commands" \
        "cd '$TEST_WORK_DIR' && '${FUB_ROOT_DIR}/bin/fub' migration detect-legacy | grep -q 'Found legacy configuration files'"
}

# Test 11: FUB rollback commands
test_fub_rollback_commands() {
    run_test "FUB rollback commands" \
        "cd '$TEST_WORK_DIR' && '${FUB_ROOT_DIR}/bin/fub' rollback list-points"
}

# Test 12: Legacy argument parsing
test_legacy_argument_parsing() {
    run_test "Legacy argument parsing" \
        "source '${FUB_ROOT_DIR}/lib/legacy/compatibility.sh' && [[ \"\$(parse_legacy_args '--clean' '--verbose')\" =~ cleanup.*verbose ]]"
}

# Test 13: Configuration migration validation
test_config_migration_validation() {
    run_test "Configuration migration validation" \
        "cd '$TEST_WORK_DIR' && source '${FUB_ROOT_DIR}/lib/legacy/config-migration.sh' && init_migration_system && migrate_configuration '$TEST_LEGACY_CONFIG' '$TEST_NEW_CONFIG' && grep -q 'cleanup_retention: 7' '$TEST_NEW_CONFIG'"
}

# Test 14: Legacy output formatting
test_legacy_output_formatting() {
    run_test "Legacy output formatting" \
        "source '${FUB_ROOT_DIR}/lib/legacy/compatibility.sh' && [[ \"\$(format_legacy_output 'cleanup_summary' 'files_removed:10,space_freed:1024')\" =~ 'Files removed:' ]]"
}

# Test 15: Rollback metadata creation
test_rollback_metadata() {
    run_test "Rollback metadata creation" \
        "source '${FUB_ROOT_DIR}/lib/legacy/rollback.sh' && init_rollback_system && create_rollback_point 'test-metadata' 'Test metadata' && [[ -f \"${FUB_ROLLBACK_DIR}/test-metadata/rollback-metadata.yaml\" ]]"
}

# Integration tests
test_integration_scenario_1() {
    echo -e "\n${BLUE}Integration Test: Complete migration scenario${NC}"
    ((TESTS_RUN++))

    # Set up scenario
    cd "$TEST_WORK_DIR"

    # 1. Detect legacy configurations
    if ! "${FUB_ROOT_DIR}/bin/fub" migration detect-legacy >/dev/null 2>&1; then
        echo -e "${RED}✗ FAIL: Could not detect legacy configurations${NC}"
        ((TESTS_FAILED++))
        return 1
    fi

    # 2. Migrate configuration
    if ! "${FUB_ROOT_DIR}/bin/fub" migration migrate-config >/dev/null 2>&1; then
        echo -e "${RED}✗ FAIL: Could not migrate configuration${NC}"
        ((TESTS_FAILED++))
        return 1
    fi

    # 3. Validate script
    if ! "${FUB_ROOT_DIR}/bin/fub" migration validate-script "$TEST_SCRIPT" >/dev/null 2>&1; then
        echo -e "${RED}✗ FAIL: Could not validate script${NC}"
        ((TESTS_FAILED++))
        return 1
    fi

    # 4. Create rollback point
    if ! "${FUB_ROOT_DIR}/bin/fub" rollback create-point >/dev/null 2>&1; then
        echo -e "${RED}✗ FAIL: Could not create rollback point${NC}"
        ((TESTS_FAILED++))
        return 1
    fi

    echo -e "${GREEN}✓ PASS: Complete migration scenario${NC}"
    ((TESTS_PASSED++))
    return 0
}

test_integration_scenario_2() {
    echo -e "\n${BLUE}Integration Test: Legacy mode compatibility${NC}"
    ((TESTS_RUN++))

    # Set up scenario
    cd "$TEST_WORK_DIR"

    # Test legacy mode with various commands
    local legacy_commands=(
        "fub --help"
        "fub --version"
        "fub --clean --dry-run"
        "fub --temp --force"
        "fub --cache --verbose"
    )

    for cmd in "${legacy_commands[@]}"; do
        if ! FUB_LEGACY_MODE=true "${FUB_ROOT_DIR}/bin/fub" $cmd >/dev/null 2>&1; then
            echo -e "${RED}✗ FAIL: Legacy command failed: $cmd${NC}"
            ((TESTS_FAILED++))
            return 1
        fi
    done

    echo -e "${GREEN}✓ PASS: Legacy mode compatibility${NC}"
    ((TESTS_PASSED++))
    return 0
}

# Performance tests
test_migration_performance() {
    echo -e "\n${BLUE}Performance Test: Migration speed${NC}"
    ((TESTS_RUN++))

    local start_time
    start_time=$(date +%s.%N)

    # Run configuration migration
    cd "$TEST_WORK_DIR"
    "${FUB_ROOT_DIR}/bin/fub" migration migrate-config >/dev/null 2>&1

    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    # Migration should complete within 5 seconds
    if (( $(echo "$duration < 5" | bc -l 2>/dev/null || echo "1") )); then
        echo -e "${GREEN}✓ PASS: Migration completed in ${duration}s${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL: Migration took too long: ${duration}s${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Main test runner
run_all_tests() {
    echo -e "${CYAN}=== FUB Migration and Backward Compatibility Test Suite ===${NC}\n"

    # Setup
    setup_test_environment

    # Unit tests
    test_legacy_compatibility_module
    test_legacy_mode_init
    test_legacy_command_mapping
    test_legacy_config_detection
    test_config_migration
    test_script_validation
    test_rollback_system_init
    test_rollback_point_creation
    test_fub_legacy_mode
    test_fub_migration_commands
    test_fub_rollback_commands
    test_legacy_argument_parsing
    test_config_migration_validation
    test_legacy_output_formatting
    test_rollback_metadata

    # Integration tests
    test_integration_scenario_1
    test_integration_scenario_2

    # Performance tests
    test_migration_performance

    # Cleanup
    cleanup_test_environment

    # Results
    echo -e "\n${CYAN}=== Test Results ===${NC}"
    echo -e "Tests run: ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please review the output above.${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests "$@"
fi