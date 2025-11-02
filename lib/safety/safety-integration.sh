#!/usr/bin/env bash

# FUB Safety Integration Module
# Comprehensive safety system integration point

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Source all safety modules
source "${FUB_SCRIPT_DIR}/lib/safety/preflight-checks.sh"
source "${FUB_SCRIPT_DIR}/lib/safety/dev-protection.sh"
source "${FUB_SCRIPT_DIR}/lib/safety/service-monitor.sh"
source "${FUB_SCRIPT_DIR}/lib/safety/backup-system.sh"
source "${FUB_SCRIPT_DIR}/lib/safety/protection-rules.sh"
source "${FUB_SCRIPT_DIR}/lib/safety/undo-system.sh"

# Safety integration constants
readonly SAFETY_INTEGRATION_VERSION="1.0.0"
readonly SAFETY_INTEGRATION_DESCRIPTION="Comprehensive safety system integration"

# Safety configuration
SAFETY_LEVEL="${SAFETY_LEVEL:-standard}"  # Options: conservative, standard, aggressive
SAFETY_SKIP_BACKUP="${SAFETY_SKIP_BACKUP:-false}"
SAFETY_SKIP_CONFIRMATIONS="${SAFETY_SKIP_CONFIRMATIONS:-false}"
SAFETY_DRY_RUN="${SAFETY_DRY_RUN:-false}"
SAFETY_VERBOSE="${SAFETY_VERBOSE:-false}"

# Initialize all safety modules
init_safety_system() {
    log_info "Initializing FUB Safety System v$SAFETY_INTEGRATION_VERSION"
    log_debug "Safety level: $SAFETY_LEVEL"
    log_debug "Skip backup: $SAFETY_SKIP_BACKUP"
    log_debug "Skip confirmations: $SAFETY_SKIP_CONFIRMATIONS"
    log_debug "Dry run: $SAFETY_DRY_RUN"

    # Initialize all safety modules
    init_preflight_checks
    init_dev_protection
    init_service_monitor
    init_backup_system
    init_protection_rules
    init_undo_system

    # Set safety confirmation based on configuration
    if [[ "$SAFETY_SKIP_CONFIRMATIONS" == "true" ]]; then
        export SAFETY_CONFIRM_DESTRUCTIVE="false"
    else
        export SAFETY_CONFIRM_DESTRUCTIVE="true"
    fi

    # Set backup configuration
    if [[ "$SAFETY_SKIP_BACKUP" == "false" ]]; then
        export SAFETY_BACKUP_IMPORTANT="true"
    else
        export SAFETY_BACKUP_IMPORTANT="false"
    fi

    # Set verbose mode
    export SAFETY_VERBOSE="$SAFETY_VERBOSE"

    print_success "Safety system initialized"
    return 0
}

# Configure safety level
configure_safety_level() {
    local level="$1"

    print_section "Configuring Safety Level: $level"

    case "$level" in
        "conservative")
            export SAFETY_CONFIRM_DESTRUCTIVE="true"
            export SAFETY_BACKUP_IMPORTANT="true"
            export SAFETY_SKIP_BASIC_CHECKS="false"
            export SAFETY_SKIP_ADVANCED_CHECKS="false"
            export SAFETY_ALLOW_AGGRESSIVE="false"
            print_info "Conservative mode: Maximum safety, confirmations required"
            ;;
        "standard")
            export SAFETY_CONFIRM_DESTRUCTIVE="true"
            export SAFETY_BACKUP_IMPORTANT="true"
            export SAFETY_SKIP_BASIC_CHECKS="false"
            export SAFETY_SKIP_ADVANCED_CHECKS="false"
            export SAFETY_ALLOW_AGGRESSIVE="false"
            print_info "Standard mode: Balanced safety and efficiency"
            ;;
        "aggressive")
            export SAFETY_CONFIRM_DESTRUCTIVE="false"
            export SAFETY_BACKUP_IMPORTANT="false"
            export SAFETY_SKIP_BASIC_CHECKS="false"
            export SAFETY_SKIP_ADVANCED_CHECKS="true"
            export SAFETY_ALLOW_AGGRESSIVE="true"
            print_warning "Aggressive mode: Reduced safety, faster cleanup"
            ;;
        *)
            print_error "Unknown safety level: $level"
            print_info "Available levels: conservative, standard, aggressive"
            return 1
            ;;
    esac

    export SAFETY_LEVEL="$level"
    return 0
}

# Run comprehensive safety checks
run_safety_checks() {
    local check_type="${1:-all}"
    local -a paths=("${@:2}")

    print_header "Comprehensive Safety Checks"
    print_info "Safety level: $SAFETY_LEVEL"
    print_info "Check type: $check_type"

    local checks_passed=true
    local failed_checks=()

    # Pre-flight system checks
    if [[ "$check_type" == "all" ]] || [[ "$check_type" == "preflight" ]]; then
        print_info "Running pre-flight system checks..."
        if ! perform_preflight_checks; then
            checks_passed=false
            failed_checks+=("preflight")
        fi
    fi

    # Development environment protection
    if [[ "$check_type" == "all" ]] || [[ "$check_type" == "development" ]]; then
        print_info "Running development environment protection..."
        if ! perform_dev_protection; then
            checks_passed=false
            failed_checks+=("development")
        fi
    fi

    # Service monitoring
    if [[ "$check_type" == "all" ]] || [[ "$check_type" == "services" ]]; then
        print_info "Running service and container monitoring..."
        if ! perform_service_monitoring; then
            checks_passed=false
            failed_checks+=("services")
        fi
    fi

    # Protection rules validation
    if [[ "$check_type" == "all" ]] || [[ "$check_type" == "rules" ]]; then
        print_info "Validating protection rules..."
        if ! perform_rule_management "validate" "protect" "user"; then
            checks_passed=false
            failed_checks+=("rules")
        fi
    fi

    # Path validation (if paths provided)
    if [[ ${#paths[@]} -gt 0 ]]; then
        print_info "Validating cleanup paths..."
        if ! validate_cleanup_paths "${paths[@]}"; then
            checks_passed=false
            failed_checks+=("paths")
        fi
    fi

    # Report results
    if [[ "$checks_passed" == "true" ]]; then
        print_success "All safety checks passed"
        return 0
    else
        print_error "Safety checks failed: ${failed_checks[*]}"
        print_info "Failed checks must be resolved before proceeding"
        return 1
    fi
}

# Create safety backup
create_safety_backup() {
    local backup_type="${1:-config}"

    if [[ "$SAFETY_BACKUP_IMPORTANT" != "true" ]]; then
        print_info "Backup creation skipped (SAFETY_SKIP_BACKUP=true)"
        return 0
    fi

    print_section "Creating Safety Backup"

    if [[ "$SAFETY_DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would create backup of type: $backup_type"
        return 0
    fi

    if ! perform_backup "$backup_type"; then
        print_error "Failed to create safety backup"
        return 1
    fi

    return 0
}

# Validate cleanup operation
validate_cleanup_operation() {
    local operation_type="$1"
    shift
    local -a targets=("$@")

    print_section "Validating Cleanup Operation: $operation_type"

    local validation_passed=true
    local protected_items=()
    local blocked_items=()

    # Load protection rules
    local -a protect_rules
    read -ra protect_rules <<< "$(get_all_rules "protect")"

    # Check each target against protection rules
    for target in "${targets[@]}"; do
        local is_protected=false

        # Check file/directory protection
        if [[ -e "$target" ]]; then
            for rule in "${protect_rules[@]}"; do
                if [[ "$rule" == "files:"* ]] || [[ "$rule" == "directories:"* ]]; then
                    local pattern="${rule#*:}"
                    if [[ "$target" == $pattern ]]; then
                        is_protected=true
                        break
                    fi
                fi
            done
        fi

        if [[ "$is_protected" == "true" ]]; then
            protected_items+=("$target")
        else
            # Additional validation based on operation type
            case "$operation_type" in
                "file_delete")
                    if ! validate_file_deletion "$target"; then
                        validation_passed=false
                        blocked_items+=("$target")
                    fi
                    ;;
                "package_remove")
                    if ! validate_package_removal "$target"; then
                        validation_passed=false
                        blocked_items+=("$target")
                    fi
                    ;;
                "service_stop")
                    if ! validate_service_stop "$target"; then
                        validation_passed=false
                        blocked_items+=("$target")
                    fi
                    ;;
            esac
        fi
    done

    # Report validation results
    if [[ ${#protected_items[@]} -gt 0 ]]; then
        print_warning "Protected items detected:"
        for item in "${protected_items[@]}"; do
            print_indented 2 "$(format_status "warning" "$item")"
        done
    fi

    if [[ ${#blocked_items[@]} -gt 0 ]]; then
        print_error "Blocked items detected:"
        for item in "${blocked_items[@]}"; do
            print_indented 2 "$(format_status "error" "$item")"
        done
        validation_passed=false
    fi

    if [[ "$validation_passed" == "true" ]]; then
        print_success "Operation validation passed"
        return 0
    else
        print_error "Operation validation failed"
        return 1
    fi
}

# Validate file deletion
validate_file_deletion() {
    local file_path="$1"

    # Check if file exists
    if [[ ! -e "$file_path" ]]; then
        print_warning "File does not exist: $file_path"
        return 0  # Not an error, file is already gone
    fi

    # Check file size (warn for large files)
    if [[ -f "$file_path" ]]; then
        local file_size
        file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "0")
        local file_size_mb=$((file_size / 1024 / 1024))

        if [[ $file_size_mb -gt 100 ]]; then
            print_warning "Large file detected: $file_path (${file_size_mb}MB)"
            if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
                if ! confirm_with_warning "Delete large file?" "File size: ${file_size_mb}MB"; then
                    return 1
                fi
            fi
        fi
    fi

    # Check if file is in use
    if command_exists lsof; then
        local open_handles
        open_handles=$(lsof "$file_path" 2>/dev/null | wc -l || echo "0")
        if [[ $open_handles -gt 0 ]]; then
            print_warning "File is currently in use: $file_path ($open_handles handles)"
            if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
                if ! confirm_with_warning "Delete file in use?" "File has $open_handles open handles"; then
                    return 1
                fi
            fi
        fi
    fi

    return 0
}

# Validate package removal
validate_package_removal() {
    local package_name="$1"

    # Check if package is installed
    if ! command_exists dpkg || ! dpkg -l | grep -q "^ii.*$package_name"; then
        print_warning "Package not installed: $package_name"
        return 0  # Not an error, package is already removed
    fi

    # Check critical packages
    local critical_packages=(
        "ubuntu-minimal" "ubuntu-standard" "coreutils" "bash" "systemd"
        "libc6" "sudo" "apt" "dpkg" "gnupg" "ca-certificates"
    )

    for critical in "${critical_packages[@]}"; do
        if [[ "$package_name" == "$critical" ]]; then
            print_error "Critical package: $package_name"
            return 1
        fi
    done

    # Check package dependencies
    if command_exists apt; then
        local dependents_count
        dependents_count=$(apt-cache rdepends --installed "$package_name" 2>/dev/null | grep -c "Reverse Depends:" || echo "0")
        if [[ $dependents_count -gt 5 ]]; then
            print_warning "Package has many dependents: $package_name ($dependents_count)"
            if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
                if ! confirm_with_warning "Remove package with many dependents?" "This may affect $dependents_count other packages"; then
                    return 1
                fi
            fi
        fi
    fi

    return 0
}

# Validate service stop
validate_service_stop() {
    local service_name="$1"

    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^$service_name.service"; then
        print_warning "Service not found: $service_name"
        return 0  # Not an error, service doesn't exist
    fi

    # Check if service is running
    if ! systemctl is-active --quiet "$service_name"; then
        print_info "Service not running: $service_name"
        return 0  # Not an error, service is already stopped
    fi

    # Check critical services
    local critical_services=(
        "systemd" "cron" "sshd" "networking" "dbus" "udev"
    )

    for critical in "${critical_services[@]}"; do
        if [[ "$service_name" == "$critical" ]]; then
            print_error "Critical service: $service_name"
            return 1
        fi
    done

    return 0
}

# Execute cleanup operation with safety
execute_cleanup_operation() {
    local operation_type="$1"
    local operation_description="$2"
    shift 2
    local -a targets=("$@")

    print_header "Executing Cleanup Operation"
    print_info "Operation: $operation_type - $operation_description"
    print_info "Targets: ${#targets[@]} items"

    local operation_ids=()
    local execution_failed=false

    for target in "${targets[@]}"; do
        print_info "Processing: $target"

        local operation_id=""
        local operation_success=false

        # Record operation before execution
        case "$operation_type" in
            "file_delete")
                if [[ -e "$target" ]]; then
                    operation_id=$(record_file_deletion "$target" "Delete file: $target")
                fi
                ;;
            "package_remove")
                operation_id=$(record_package_removal "$target" "apt" "Remove package: $target")
                ;;
            "service_stop")
                operation_id=$(record_service_stop "$target" "Stop service: $target")
                ;;
        esac

        # Execute operation (unless dry run)
        if [[ "$SAFETY_DRY_RUN" != "true" ]]; then
            case "$operation_type" in
                "file_delete")
                    if rm -rf "$target" 2>/dev/null; then
                        operation_success=true
                        print_indented 2 "$(format_status "success" "Deleted: $target")"
                    else
                        print_indented 2 "$(format_status "error" "Failed to delete: $target")"
                        execution_failed=true
                    fi
                    ;;
                "package_remove")
                    if sudo apt-get remove -y "$target" 2>/dev/null; then
                        operation_success=true
                        print_indented 2 "$(format_status "success" "Removed: $target")"
                    else
                        print_indented 2 "$(format_status "error" "Failed to remove: $target")"
                        execution_failed=true
                    fi
                    ;;
                "service_stop")
                    if sudo systemctl stop "$target" 2>/dev/null; then
                        operation_success=true
                        print_indented 2 "$(format_status "success" "Stopped: $target")"
                    else
                        print_indented 2 "$(format_status "error" "Failed to stop: $target")"
                        execution_failed=true
                    fi
                    ;;
            esac
        else
            print_indented 2 "$(format_status "info" "DRY RUN: Would process $target")"
            operation_success=true
        fi

        # Update operation status
        if [[ -n "$operation_id" ]]; then
            if [[ "$operation_success" == "true" ]]; then
                update_operation_status "$operation_id" "completed"
            else
                update_operation_status "$operation_id" "failed"
            fi
            operation_ids+=("$operation_id")
        fi
    done

    # Report operation summary
    if [[ "$execution_failed" == "false" ]]; then
        print_success "Operation completed successfully"
        print_info "Operation IDs: ${operation_ids[*]}"
        print_info "Use 'perform_undo <operation_id>' to undo if needed"
        return 0
    else
        print_error "Operation completed with errors"
        print_info "Some operations may have failed"
        print_info "Operation IDs: ${operation_ids[*]}"
        print_info "Use 'perform_undo <operation_id>' to undo successful operations"
        return 1
    fi
}

# Main safety workflow function
run_safety_workflow() {
    local operation_type="$1"
    local operation_description="$2"
    shift 2
    local -a targets=("$@")

    print_header "FUB Safety Workflow"
    print_info "Operation: $operation_type"
    print_info "Description: $operation_description"
    print_info "Safety level: $SAFETY_LEVEL"

    # Step 1: Initialize safety system
    if ! init_safety_system; then
        print_error "Failed to initialize safety system"
        return 1
    fi

    # Step 2: Configure safety level
    if ! configure_safety_level "$SAFETY_LEVEL"; then
        print_error "Failed to configure safety level"
        return 1
    fi

    # Step 3: Run safety checks
    if ! run_safety_checks "all" "${targets[@]}"; then
        print_error "Safety checks failed"
        return 1
    fi

    # Step 4: Create backup
    if ! create_safety_backup "config"; then
        print_warning "Backup creation failed, proceeding anyway"
    fi

    # Step 5: Validate operation
    if ! validate_cleanup_operation "$operation_type" "${targets[@]}"; then
        print_error "Operation validation failed"
        return 1
    fi

    # Step 6: Final confirmation (if required)
    if [[ "$SAFETY_CONFIRM_DESTRUCTIVE" == "true" ]]; then
        print_section "Final Confirmation"
        print_info "Operation: $operation_type"
        print_info "Targets: ${#targets[@]} items"
        print_warning "This action may be destructive"

        if ! confirm_with_warning "Execute operation?" "This will perform: $operation_description"; then
            print_info "Operation cancelled by user"
            return 1
        fi
    fi

    # Step 7: Execute operation
    if ! execute_cleanup_operation "$operation_type" "$operation_description" "${targets[@]}"; then
        print_error "Operation execution failed"
        return 1
    fi

    print_success "Safety workflow completed successfully"
    return 0
}

# Show safety integration help
show_safety_integration_help() {
    cat << EOF
${BOLD}${CYAN}FUB Safety Integration${RESET}
${ITALIC}Comprehensive safety system integration point${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source safety-integration.sh${RESET}
    ${GREEN}run_safety_workflow${RESET} [${YELLOW}TYPE${RESET}] [${YELLOW}DESCRIPTION${RESET}] [${YELLOW}TARGETS...${RESET}]

${BOLD}Environment Variables:${RESET}
    ${YELLOW}SAFETY_LEVEL${RESET}         Safety level (conservative, standard, aggressive)
    ${YELLOW}SAFETY_SKIP_BACKUP${RESET}   Skip backup creation (true/false)
    ${YELLOW}SAFETY_SKIP_CONFIRMATIONS${RESET}  Skip user confirmations (true/false)
    ${YELLOW}SAFETY_DRY_RUN${RESET}       Dry run mode (true/false)
    ${YELLOW}SAFETY_VERBOSE${RESET}       Verbose output (true/false)

${BOLD}Functions:${RESET}
    ${YELLOW}init_safety_system${RESET}              Initialize all safety modules
    ${YELLOW}configure_safety_level${RESET}          Set safety configuration
    ${YELLOW}run_safety_checks${RESET}               Run comprehensive safety checks
    ${YELLOW}create_safety_backup${RESET}            Create safety backup
    ${YELLOW}validate_cleanup_operation${RESET}      Validate cleanup targets
    ${YELLOW}execute_cleanup_operation${RESET}       Execute with undo support
    ${YELLOW}run_safety_workflow${RESET}             Complete safety workflow

${BOLD}Safety Levels:${RESET}
    ${YELLOW}conservative${RESET}    Maximum safety, all checks and confirmations
    ${YELLOW}standard${RESET}        Balanced safety and efficiency (default)
    ${YELLOW}aggressive${RESET}      Reduced safety for automated cleanup

${BOLD}Operation Types:${RESET}
    ${YELLOW}file_delete${RESET}     File/directory deletion operations
    ${YELLOW}package_remove${RESET}  Package removal operations
    ${YELLOW}service_stop${RESET}    Service stop operations

${BOLD}Workflow Steps:${RESET}
    1. Initialize safety system
    2. Configure safety level
    3. Run comprehensive safety checks
    4. Create safety backup
    5. Validate operation targets
    6. Request final confirmation
    7. Execute with undo support

${BOLD}Examples:${RESET}
    # Conservative file deletion
    SAFETY_LEVEL=conservative run_safety_workflow file_delete "Remove temp files" /tmp/*.tmp

    # Standard package removal with verbose output
    SAFETY_LEVEL=standard SAFETY_VERBOSE=true run_safety_workflow package_remove "Remove unused package" old-package

    # Aggressive dry run
    SAFETY_LEVEL=aggressive SAFETY_DRY_RUN=true run_safety_workflow service_stop "Stop development service" my-dev-service

${BOLD}Integration:${RESET}
    The safety integration module provides:
    • Centralized safety workflow management
    • Comprehensive pre-operation validation
    • Automatic backup creation
    • Operation logging and undo support
    • Multiple safety levels
    • User confirmation and warnings

EOF
}

# Export functions for use in other scripts
export -f init_safety_system configure_safety_level run_safety_checks
export -f create_safety_backup validate_cleanup_operation execute_cleanup_operation
export -f run_safety_workflow show_safety_integration_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_safety_integration_help
fi