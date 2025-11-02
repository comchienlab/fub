#!/usr/bin/env bash

# FUB Safety System Test Script
# Comprehensive testing of safety mechanisms

set -euo pipefail

# Source the safety system
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/safety/safety-integration.sh"

# Test configuration
readonly TEST_DIR="/tmp/fub_safety_test_$$"
readonly TEST_RESULTS_FILE="/tmp/fub_safety_test_results_$(date +%Y%m%d_%H%M%S).log"

# Initialize test environment
init_test_environment() {
    echo "Initializing FUB Safety System Test Environment" | tee -a "$TEST_RESULTS_FILE"
    echo "Test directory: $TEST_DIR" | tee -a "$TEST_RESULTS_FILE"
    echo "Results file: $TEST_RESULTS_FILE" | tee -a "$TEST_RESULTS_FILE"
    echo "" | tee -a "$TEST_RESULTS_FILE"

    # Create test directory structure
    mkdir -p "$TEST_DIR"/{test_files,test_projects,temp_files}

    # Create test files
    echo "test content" > "$TEST_DIR/test_files/test.txt"
    echo "config data" > "$TEST_DIR/test_files/config.conf"
    mkdir -p "$TEST_DIR/test_projects/sample_project"
    echo '{"name": "test"}' > "$TEST_DIR/test_projects/sample_project/package.json"
    echo "*.tmp" > "$TEST_DIR/test_projects/sample_project/.gitignore"

    # Create temporary files
    touch "$TEST_DIR/temp_files/temp1.tmp"
    touch "$TEST_DIR/temp_files/temp2.log"
    touch "$TEST_DIR/temp_files/cache.cache"

    echo "Test environment created" | tee -a "$TEST_RESULTS_FILE"
    echo "" | tee -a "$TEST_RESULTS_FILE"
}

# Cleanup test environment
cleanup_test_environment() {
    echo "Cleaning up test environment" | tee -a "$TEST_RESULTS_FILE"
    rm -rf "$TEST_DIR" 2>/dev/null || true
    echo "Test environment cleaned up" | tee -a "$TEST_RESULTS_FILE"
}

# Run individual test
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo "Running test: $test_name" | tee -a "$TEST_RESULTS_FILE"
    echo "----------------------------------------" | tee -a "$TEST_RESULTS_FILE"

    local start_time=$(date +%s)

    if $test_function; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✓ PASSED: $test_name (${duration}s)" | tee -a "$TEST_RESULTS_FILE"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✗ FAILED: $test_name (${duration}s)" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Test 1: Safety System Initialization
test_safety_system_initialization() {
    echo "Testing safety system initialization..." | tee -a "$TEST_RESULTS_FILE"

    if init_safety_system; then
        echo "✓ Safety system initialized successfully" | tee -a "$TEST_RESULTS_FILE"
        return 0
    else
        echo "✗ Safety system initialization failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Test 2: Safety Level Configuration
test_safety_level_configuration() {
    echo "Testing safety level configuration..." | tee -a "$TEST_RESULTS_FILE"

    local levels=("conservative" "standard" "aggressive")
    for level in "${levels[@]}"; do
        echo "Testing level: $level" | tee -a "$TEST_RESULTS_FILE"
        if configure_safety_level "$level"; then
            echo "✓ Level $level configured successfully" | tee -a "$TEST_RESULTS_FILE"
        else
            echo "✗ Failed to configure level $level" | tee -a "$TEST_RESULTS_FILE"
            return 1
        fi
    done

    # Test invalid level
    if ! configure_safety_level "invalid" 2>/dev/null; then
        echo "✓ Invalid level properly rejected" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Invalid level was accepted" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Test 3: Pre-flight Checks
test_preflight_checks() {
    echo "Testing pre-flight checks..." | tee -a "$TEST_RESULTS_FILE"

    # Test with valid paths
    local test_paths=("$TEST_DIR")
    if perform_preflight_checks; then
        echo "✓ Pre-flight checks passed" | tee -a "$TEST_RESULTS_FILE"
        return 0
    else
        echo "✗ Pre-flight checks failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Test 4: Development Environment Detection
test_development_detection() {
    echo "Testing development environment detection..." | tee -a "$TEST_RESULTS_FILE"

    # Set test development directories
    export FUB_DEV_DIRS="$TEST_DIR/test_projects"

    if detect_development_directories; then
        echo "✓ Development directories detected" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Development directory detection failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Test 5: Service Monitoring
test_service_monitoring() {
    echo "Testing service monitoring..." | tee -a "$TEST_RESULTS_FILE"

    if detect_system_services; then
        echo "✓ System services detected" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ System service detection failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Test 6: Backup System
test_backup_system() {
    echo "Testing backup system..." | tee -a "$TEST_RESULTS_FILE"

    # Test backup creation
    local backup_id="test_backup_$$"
    local backup_dir
    backup_dir=$(create_backup_structure "$backup_id" "$TEST_DIR/backups")

    if [[ -d "$backup_dir" ]] && [[ -f "$backup_dir/metadata.json" ]]; then
        echo "✓ Backup structure created successfully" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Backup structure creation failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    # Test backup creation (small test)
    export SAFETY_BACKUP_IMPORTANT="true"
    export SAFETY_SKIP_BACKUP="false"

    if perform_backup "config" "$TEST_DIR/backups"; then
        echo "✓ Backup creation successful" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Backup creation failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Test 7: Protection Rules
test_protection_rules() {
    echo "Testing protection rules..." | tee -a "$TEST_RESULTS_FILE"

    # Initialize protection rules
    if init_protection_rules; then
        echo "✓ Protection rules initialized" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Protection rules initialization failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    # Test default rules creation
    if create_default_rules "local"; then
        echo "✓ Default protection rules created" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Default protection rules creation failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    # Test rule validation
    if validate_rules "protect" "local"; then
        echo "✓ Protection rules validation passed" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Protection rules validation failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Test 8: Undo System
test_undo_system() {
    echo "Testing undo system..." | tee -a "$TEST_RESULTS_FILE"

    # Initialize undo system
    if init_undo_system; then
        echo "✓ Undo system initialized" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Undo system initialization failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    # Test file operation recording
    local test_file="$TEST_DIR/test_files/undo_test.txt"
    echo "test content" > "$test_file"

    local operation_id
    operation_id=$(record_file_deletion "$test_file" "Test file deletion")

    if [[ -n "$operation_id" ]] && [[ -f "/tmp/fub_undo_logs/${operation_id}.log" ]]; then
        echo "✓ File operation recorded successfully: $operation_id" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ File operation recording failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Test 9: Safety Workflow Integration
test_safety_workflow() {
    echo "Testing safety workflow integration..." | tee -a "$TEST_RESULTS_FILE"

    # Configure safety level for testing
    export SAFETY_LEVEL="conservative"
    export SAFETY_SKIP_CONFIRMATIONS="true"
    export SAFETY_DRY_RUN="true"

    local test_files=("$TEST_DIR/temp_files/temp1.tmp" "$TEST_DIR/temp_files/temp2.log")

    if run_safety_workflow "file_delete" "Test workflow" "${test_files[@]}"; then
        echo "✓ Safety workflow integration test passed" | tee -a "$TEST_RESULTS_FILE"
        return 0
    else
        echo "✗ Safety workflow integration test failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Test 10: Error Handling
test_error_handling() {
    echo "Testing error handling..." | tee -a "$TEST_RESULTS_FILE"

    # Test with invalid paths
    if ! run_safety_checks "all" "/nonexistent/path" 2>/dev/null; then
        echo "✓ Invalid path properly handled" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Invalid path was not properly handled" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    # Test with protected paths
    export SAFETY_CONFIRM_DESTRUCTIVE="false"
    if ! validate_cleanup_operation "file_delete" "/etc/passwd" 2>/dev/null; then
        echo "✓ Protected path validation working" | tee -a "$TEST_RESULTS_FILE"
    else
        echo "✗ Protected path validation failed" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi

    return 0
}

# Main test runner
main() {
    echo "FUB Safety System Test Suite" | tee "$TEST_RESULTS_FILE"
    echo "==============================" | tee -a "$TEST_RESULTS_FILE"
    echo "Started at: $(date)" | tee -a "$TEST_RESULTS_FILE"
    echo "" | tee -a "$TEST_RESULTS_FILE"

    # Initialize test environment
    init_test_environment

    # Set up cleanup trap
    trap cleanup_test_environment EXIT

    # Define tests
    local -a tests=(
        "Safety System Initialization:test_safety_system_initialization"
        "Safety Level Configuration:test_safety_level_configuration"
        "Pre-flight Checks:test_preflight_checks"
        "Development Environment Detection:test_development_detection"
        "Service Monitoring:test_service_monitoring"
        "Backup System:test_backup_system"
        "Protection Rules:test_protection_rules"
        "Undo System:test_undo_system"
        "Safety Workflow Integration:test_safety_workflow"
        "Error Handling:test_error_handling"
    )

    local total_tests=${#tests[@]}
    local passed_tests=0
    local failed_tests=0

    # Run tests
    echo "Running $total_tests tests..." | tee -a "$TEST_RESULTS_FILE"
    echo "" | tee -a "$TEST_RESULTS_FILE"

    for test_entry in "${tests[@]}"; do
        local test_name="${test_entry%%:*}"
        local test_function="${test_entry##*:}"

        if run_test "$test_name" "$test_function"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi

        echo "" | tee -a "$TEST_RESULTS_FILE"
    done

    # Print summary
    echo "Test Summary" | tee -a "$TEST_RESULTS_FILE"
    echo "============" | tee -a "$TEST_RESULTS_FILE"
    echo "Total tests: $total_tests" | tee -a "$TEST_RESULTS_FILE"
    echo "Passed: $passed_tests" | tee -a "$TEST_RESULTS_FILE"
    echo "Failed: $failed_tests" | tee -a "$TEST_RESULTS_FILE"
    echo "Success rate: $(( passed_tests * 100 / total_tests ))%" | tee -a "$TEST_RESULTS_FILE"
    echo "" | tee -a "$TEST_RESULTS_FILE"
    echo "Completed at: $(date)" | tee -a "$TEST_RESULTS_FILE"

    # Exit with appropriate code
    if [[ $failed_tests -eq 0 ]]; then
        echo "All tests passed! ✓" | tee -a "$TEST_RESULTS_FILE"
        return 0
    else
        echo "Some tests failed! ✗" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi