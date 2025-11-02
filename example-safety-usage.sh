#!/usr/bin/env bash

# FUB Safety System Usage Examples
# Demonstrates practical usage of the safety mechanisms

set -euo pipefail

# Source the safety system
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/safety/safety-integration.sh"

# Example 1: Basic File Cleanup with Safety
example_file_cleanup() {
    echo "=== Example 1: Safe File Cleanup ==="
    echo

    # Create test environment
    local test_dir="/tmp/fub_example_files_$$"
    mkdir -p "$test_dir"/{temp,cache,logs,important}

    # Create test files
    echo "temporary data" > "$test_dir/temp/temp1.tmp"
    echo "cache data" > "$test_dir/cache/cache1.cache"
    echo "log data" > "$test_dir/logs/app.log"
    echo "important config" > "$test_dir/important/config.conf"

    echo "Created test files in: $test_dir"
    ls -la "$test_dir"/*/
    echo

    # Safe cleanup with conservative safety level
    echo "Running safe file cleanup with conservative safety level..."
    echo "This will only clean temporary and cache files, preserving important files."
    echo

    export SAFETY_LEVEL="conservative"
    export SAFETY_VERBOSE="true"

    # Define cleanup targets (only temp and cache files)
    local cleanup_files=(
        "$test_dir/temp/temp1.tmp"
        "$test_dir/cache/cache1.cache"
        # Intentionally not including important files
    )

    if run_safety_workflow "file_delete" "Clean temporary and cache files" "${cleanup_files[@]}"; then
        echo "✓ File cleanup completed successfully"
    else
        echo "✗ File cleanup failed or was cancelled"
    fi

    echo "Remaining files:"
    ls -la "$test_dir"/*/ 2>/dev/null || true
    echo

    # Cleanup test directory
    rm -rf "$test_dir"
}

# Example 2: Development Environment Protection
example_dev_protection() {
    echo "=== Example 2: Development Environment Protection ==="
    echo

    # Create mock development directory
    local dev_dir="/tmp/fub_example_dev_$$"
    mkdir -p "$dev_dir"/{frontend,backend,docs}

    # Create development files
    cat > "$dev_dir/package.json" << EOF
{
    "name": "example-project",
    "version": "1.0.0",
    "dependencies": {
        "express": "^4.18.0",
        "react": "^18.2.0"
    }
}
EOF

    cat > "$dev_dir/.env" << EOF
DATABASE_URL=postgresql://localhost/mydb
API_KEY=secret-api-key
NODE_ENV=development
EOF

    echo "# Example Project" > "$dev_dir/README.md"
    echo "console.log('Hello World');" > "$dev_dir/frontend/app.js"
    echo "app.listen(3000);" > "$dev_dir/backend/server.js"

    echo "Created mock development environment in: $dev_dir"
    ls -la "$dev_dir"
    echo

    # Run development protection
    echo "Running development environment protection..."
    export FUB_DEV_DIRS="$dev_dir"

    if perform_dev_protection; then
        echo "✓ Development environment protection completed"
        echo "Important files like .env and package.json should be protected"
    else
        echo "✗ Development protection failed"
    fi

    echo

    # Attempt to clean development directory (should be blocked)
    echo "Attempting to clean development directory (should be blocked)..."
    export SAFETY_LEVEL="conservative"

    if ! run_safety_workflow "file_delete" "Clean dev directory" "$dev_dir" 2>/dev/null; then
        echo "✓ Development directory properly protected from cleanup"
    else
        echo "✗ Development directory was not protected (unexpected)"
    fi

    echo

    # Cleanup test directory
    rm -rf "$dev_dir"
}

# Example 3: Service Safety
example_service_safety() {
    echo "=== Example 3: Service Safety ==="
    echo

    echo "Checking running services and their safety implications..."
    echo

    # Run service monitoring
    if perform_service_monitoring; then
        echo "✓ Service monitoring completed"
        echo "Critical services are protected from accidental stoppage"
    else
        echo "✗ Service monitoring failed"
    fi

    echo

    # Show how services would be protected
    echo "Example: Attempting to stop a critical service (should be blocked)..."
    export SAFETY_LEVEL="conservative"

    # This should fail validation for critical services
    if ! run_safety_workflow "service_stop" "Stop SSH service" "ssh" 2>/dev/null; then
        echo "✓ Critical SSH service properly protected"
    else
        echo "✗ SSH service protection failed (unexpected)"
    fi

    echo
}

# Example 4: Backup Creation and Restoration
example_backup_system() {
    echo "=== Example 4: Backup System ==="
    echo

    echo "Creating configuration backup..."
    echo

    # Create backup
    export SAFETY_BACKUP_IMPORTANT="true"

    if perform_backup "config"; then
        echo "✓ Configuration backup created successfully"

        # List available backups
        echo "Available backups:"
        list_backups
    else
        echo "✗ Backup creation failed"
    fi

    echo
}

# Example 5: Protection Rules Management
example_protection_rules() {
    echo "=== Example 5: Protection Rules Management ==="
    echo

    echo "Creating and managing protection rules..."
    echo

    # Create default rules
    if perform_rule_management "create-default" "all" "local"; then
        echo "✓ Default protection rules created"
    else
        echo "✗ Failed to create default rules"
    fi

    echo

    # Show current rules
    echo "Current protection rules (sample):"
    show_rules "protect" "local" | head -20

    echo

    # Validate rules
    if perform_rule_management "validate" "all" "local"; then
        echo "✓ Protection rules validation passed"
    else
        echo "✗ Protection rules validation failed"
    fi

    echo
}

# Example 6: Undo Operations
example_undo_operations() {
    echo "=== Example 6: Undo Operations ==="
    echo

    # Create a test file
    local test_file="/tmp/fub_undo_test_$$"
    echo "Important data that should be backed up" > "$test_file"

    echo "Created test file: $test_file"
    echo "Content: $(cat "$test_file")"
    echo

    # Record operation before deletion
    echo "Recording file deletion operation..."
    local operation_id
    operation_id=$(record_file_deletion "$test_file" "Test file deletion example")

    echo "Operation ID: $operation_id"
    echo

    # Simulate deletion
    rm -f "$test_file"
    echo "File deleted (simulated)"
    echo

    # List available undo operations
    echo "Available undo operations:"
    list_undo_operations 3

    echo

    # Perform undo
    if [[ -n "$operation_id" ]]; then
        echo "Performing undo operation: $operation_id"

        if perform_undo "$operation_id"; then
            echo "✓ Undo operation completed successfully"

            # Check if file was restored
            if [[ -f "$test_file" ]]; then
                echo "✓ File restored successfully"
                echo "Content: $(cat "$test_file")"
            else
                echo "✗ File restoration failed"
            fi
        else
            echo "✗ Undo operation failed"
        fi
    fi

    echo

    # Cleanup
    rm -f "$test_file"
}

# Example 7: Safety Levels Demonstration
example_safety_levels() {
    echo "=== Example 7: Safety Levels Demonstration ==="
    echo

    local test_dir="/tmp/fub_safety_levels_$$"
    mkdir -p "$test_dir"
    echo "test content" > "$test_dir/test.txt"

    echo "Created test file: $test_dir/test.txt"
    echo

    # Test different safety levels
    local levels=("conservative" "standard" "aggressive")

    for level in "${levels[@]}"; do
        echo "Testing safety level: $level"
        echo "----------------------------------------"

        export SAFETY_LEVEL="$level"
        export SAFETY_DRY_RUN="true"  # Don't actually delete
        export SAFETY_VERBOSE="false"

        case "$level" in
            "conservative")
                echo "- Maximum safety checks enabled"
                echo "- User confirmations required"
                echo "- Automatic backup creation"
                echo "- Comprehensive validation"
                ;;
            "standard")
                echo "- Balanced safety approach"
                echo "- Essential confirmations"
                echo "- Important operation backup"
                echo "- Standard validation"
                ;;
            "aggressive")
                echo "- Basic safety checks only"
                echo "- Minimal confirmations"
                echo "- Optional backup creation"
                echo "- Streamlined validation"
                ;;
        esac

        if run_safety_workflow "file_delete" "Test deletion at $level level" "$test_dir/test.txt"; then
            echo "✓ Safety workflow completed (DRY RUN - no actual changes)"
        else
            echo "✗ Safety workflow failed"
        fi

        echo
    done

    # Cleanup
    rm -rf "$test_dir"
}

# Main function to run all examples
main() {
    echo "FUB Safety System - Usage Examples"
    echo "=================================="
    echo

    # Initialize safety system
    if ! init_safety_system; then
        echo "Failed to initialize safety system"
        exit 1
    fi

    echo "Safety system initialized successfully"
    echo

    # Run examples
    example_file_cleanup
    example_dev_protection
    example_service_safety
    example_backup_system
    example_protection_rules
    example_undo_operations
    example_safety_levels

    echo "All examples completed!"
    echo
    echo "Key takeaways:"
    echo "- Always use appropriate safety levels for your use case"
    echo "- Create backups before important operations"
    echo "- Validate protection rules regularly"
    echo "- Use undo functionality for emergency recovery"
    echo "- Test safety system in non-production environments"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi