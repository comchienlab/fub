#!/usr/bin/env bash

# FUB Undo System Module
# Undo functionality for critical operations with comprehensive logging

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Undo system constants
readonly UNDO_VERSION="1.0.0"
readonly UNDO_DESCRIPTION="Undo functionality for critical operations"

# Undo configuration
readonly UNDO_LOG_DIR="/tmp/fub_undo_logs"
readonly UNDO_STACK_FILE="/tmp/fub_undo_stack"
readonly MAX_UNDO_OPERATIONS=100
readonly UNDO_RETENTION_DAYS=30

# Operation types
declare -a OPERATION_TYPES=("file_delete" "file_modify" "package_remove" "service_stop" "config_change" "directory_create")

# Initialize undo system
init_undo_system() {
    log_info "Initializing undo system module v$UNDO_VERSION"
    log_debug "Undo system module initialized"

    # Create undo log directory
    mkdir -p "$UNDO_LOG_DIR"

    # Initialize undo stack if it doesn't exist
    if [[ ! -f "$UNDO_STACK_FILE" ]]; then
        touch "$UNDO_STACK_FILE"
    fi
}

# Generate unique operation ID
generate_operation_id() {
    echo "op_$(date +%Y%m%d_%H%M%S)_$$"
}

# Record operation in undo log
record_operation() {
    local operation_id="$1"
    local operation_type="$2"
    local operation_data="$3"
    local description="$4"

    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    # Create operation log entry
    cat > "$log_file" << EOF
{
    "operation_id": "$operation_id",
    "operation_type": "$operation_type",
    "timestamp": "$(date -Iseconds)",
    "user": "$USER",
    "hostname": "$(hostname)",
    "working_directory": "$(pwd)",
    "description": "$description",
    "status": "pending",
    "data": $operation_data,
    "undo_available": true
}
EOF

    # Add to undo stack
    echo "$operation_id" >> "$UNDO_STACK_FILE"

    # Keep only recent operations in stack
    if [[ $(wc -l < "$UNDO_STACK_FILE") -gt $MAX_UNDO_OPERATIONS ]]; then
        tail -n $MAX_UNDO_OPERATIONS "$UNDO_STACK_FILE" > "${UNDO_STACK_FILE}.tmp"
        mv "${UNDO_STACK_FILE}.tmp" "$UNDO_STACK_FILE"
    fi

    log_info "Operation recorded: $operation_id ($operation_type)"
}

# Backup file before modification
backup_file() {
    local original_file="$1"
    local operation_id="$2"

    if [[ ! -f "$original_file" ]]; then
        return 0  # File doesn't exist, nothing to backup
    fi

    local backup_dir="$UNDO_LOG_DIR/${operation_id}_backup"
    mkdir -p "$backup_dir"

    local backup_file="$backup_dir/$(basename "$original_file")"

    # Create backup with metadata
    cp "$original_file" "$backup_file"

    # Record file metadata
    stat -c "size: %s, permissions: %a, modified: %y, owner: %U:%G" "$original_file" > "$backup_file.metadata" 2>/dev/null || \
        stat -f "size: %z, permissions: %Lp, modified: %Sm, owner: %u:%g" "$original_file" > "$backup_file.metadata" 2>/dev/null || true

    echo "$backup_file"
}

# Record file deletion
record_file_deletion() {
    local file_path="$1"
    local description="${2:-Delete file: $file_path}"

    local operation_id
    operation_id=$(generate_operation_id)

    # Backup file if it exists
    local backup_file
    backup_file=$(backup_file "$file_path" "$operation_id")

    local operation_data
    operation_data=$(cat << EOF
{
    "file_path": "$file_path",
    "backup_file": "$backup_file",
    "original_exists": $([[ -f "$file_path" ]] && echo true || echo false),
    "file_type": "$(file -b "$file_path" 2>/dev/null || echo "unknown")"
}
EOF
)

    record_operation "$operation_id" "file_delete" "$operation_data" "$description"
    echo "$operation_id"
}

# Record file modification
record_file_modification() {
    local file_path="$1"
    local description="${2:-Modify file: $file_path}"

    local operation_id
    operation_id=$(generate_operation_id)

    # Backup original file
    local backup_file
    backup_file=$(backup_file "$file_path" "$operation_id")

    local operation_data
    operation_data=$(cat << EOF
{
    "file_path": "$file_path",
    "backup_file": "$backup_file",
    "original_exists": $([[ -f "$file_path" ]] && echo true || echo false)
}
EOF
)

    record_operation "$operation_id" "file_modify" "$operation_data" "$description"
    echo "$operation_id"
}

# Record package removal
record_package_removal() {
    local package_name="$1"
    local package_manager="${2:-apt}"
    local description="${3:-Remove package: $package_name}"

    local operation_id
    operation_id=$(generate_operation_id)

    # Gather package information before removal
    local package_info=""
    case "$package_manager" in
        "apt")
            if command_exists apt; then
                apt show "$package_name" 2>/dev/null > "$UNDO_LOG_DIR/${operation_id}_package_info.txt" || true
            fi
            ;;
        "snap")
            if command_exists snap; then
                snap info "$package_name" > "$UNDO_LOG_DIR/${operation_id}_package_info.txt" 2>/dev/null || true
            fi
            ;;
        "flatpak")
            if command_exists flatpak; then
                flatpak info "$package_name" > "$UNDO_LOG_DIR/${operation_id}_package_info.txt" 2>/dev/null || true
            fi
            ;;
    esac

    local operation_data
    operation_data=$(cat << EOF
{
    "package_name": "$package_name",
    "package_manager": "$package_manager",
    "package_info_file": "$UNDO_LOG_DIR/${operation_id}_package_info.txt",
    "was_installed": true
}
EOF
)

    record_operation "$operation_id" "package_remove" "$operation_data" "$description"
    echo "$operation_id"
}

# Record service stop
record_service_stop() {
    local service_name="$1"
    local description="${2:-Stop service: $service_name}"

    local operation_id
    operation_id=$(generate_operation_id)

    # Record service status before stopping
    local service_status=""
    if command_exists systemctl; then
        systemctl status "$service_name" > "$UNDO_LOG_DIR/${operation_id}_service_status.txt" 2>/dev/null || true
        service_status=$(systemctl is-active "$service_name" 2>/dev/null || echo "unknown")
    fi

    local operation_data
    operation_data=$(cat << EOF
{
    "service_name": "$service_name",
    "original_status": "$service_status",
    "service_status_file": "$UNDO_LOG_DIR/${operation_id}_service_status.txt"
}
EOF
)

    record_operation "$operation_id" "service_stop" "$operation_data" "$description"
    echo "$operation_id"
}

# Record directory creation
record_directory_creation() {
    local dir_path="$1"
    local description="${2:-Create directory: $dir_path}"

    local operation_id
    operation_id=$(generate_operation_id)

    local operation_data
    operation_data=$(cat << EOF
{
    "directory_path": "$dir_path",
    "was_created": true
}
EOF
)

    record_operation "$operation_id" "directory_create" "$operation_data" "$description"
    echo "$operation_id"
}

# Get operation details
get_operation_details() {
    local operation_id="$1"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ ! -f "$log_file" ]]; then
        echo "Operation not found: $operation_id"
        return 1
    fi

    cat "$log_file"
}

# Undo file deletion
undo_file_deletion() {
    local operation_id="$1"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ ! -f "$log_file" ]]; then
        print_error "Operation log not found: $operation_id"
        return 1
    fi

    print_section "Undoing File Deletion: $operation_id"

    # Extract operation data
    if command_exists jq; then
        local file_path
        file_path=$(jq -r '.data.file_path' "$log_file")
        local backup_file
        backup_file=$(jq -r '.data.backup_file' "$log_file")
        local original_exists
        original_exists=$(jq -r '.data.original_exists' "$log_file")

        if [[ "$original_exists" == "true" ]] && [[ -f "$backup_file" ]]; then
            # Restore the file
            mkdir -p "$(dirname "$file_path")"
            cp "$backup_file" "$file_path"

            # Restore metadata if available
            if [[ -f "${backup_file}.metadata" ]]; then
                local metadata
                metadata=$(cat "${backup_file}.metadata")
                print_info "Restoring metadata: $metadata"
                # Note: Actual metadata restoration would require parsing and applying
            fi

            print_success "File restored: $file_path"
            update_operation_status "$operation_id" "completed"
            return 0
        else
            print_warning "File was not backed up or didn't originally exist"
            return 1
        fi
    else
        print_error "jq not available for processing undo operation"
        return 1
    fi
}

# Undo file modification
undo_file_modification() {
    local operation_id="$1"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ ! -f "$log_file" ]]; then
        print_error "Operation log not found: $operation_id"
        return 1
    fi

    print_section "Undoing File Modification: $operation_id"

    if command_exists jq; then
        local file_path
        file_path=$(jq -r '.data.file_path' "$log_file")
        local backup_file
        backup_file=$(jq -r '.data.backup_file' "$log_file")

        if [[ -f "$backup_file" ]]; then
            # Restore the original file
            cp "$backup_file" "$file_path"
            print_success "File restored to original state: $file_path"
            update_operation_status "$operation_id" "completed"
            return 0
        else
            print_error "Backup file not found: $backup_file"
            return 1
        fi
    else
        print_error "jq not available for processing undo operation"
        return 1
    fi
}

# Undo package removal
undo_package_removal() {
    local operation_id="$1"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ ! -f "$log_file" ]]; then
        print_error "Operation log not found: $operation_id"
        return 1
    fi

    print_section "Undoing Package Removal: $operation_id"

    if command_exists jq; then
        local package_name
        package_name=$(jq -r '.data.package_name' "$log_file")
        local package_manager
        package_manager=$(jq -r '.data.package_manager' "$log_file")

        print_warning "Attempting to reinstall package: $package_name"

        case "$package_manager" in
            "apt")
                if command_exists apt; then
                    if sudo apt update && sudo apt install -y "$package_name"; then
                        print_success "Package reinstalled: $package_name"
                        update_operation_status "$operation_id" "completed"
                        return 0
                    else
                        print_error "Failed to reinstall package: $package_name"
                        return 1
                    fi
                fi
                ;;
            "snap")
                if command_exists snap; then
                    if snap install "$package_name"; then
                        print_success "Snap reinstalled: $package_name"
                        update_operation_status "$operation_id" "completed"
                        return 0
                    else
                        print_error "Failed to reinstall snap: $package_name"
                        return 1
                    fi
                fi
                ;;
            "flatpak")
                if command_exists flatpak; then
                    if flatpak install -y "$package_name"; then
                        print_success "Flatpak reinstalled: $package_name"
                        update_operation_status "$operation_id" "completed"
                        return 0
                    else
                        print_error "Failed to reinstall flatpak: $package_name"
                        return 1
                    fi
                fi
                ;;
        esac

        print_error "Package manager not available: $package_manager"
        return 1
    else
        print_error "jq not available for processing undo operation"
        return 1
    fi
}

# Undo service stop
undo_service_stop() {
    local operation_id="$1"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ ! -f "$log_file" ]]; then
        print_error "Operation log not found: $operation_id"
        return 1
    fi

    print_section "Undoing Service Stop: $operation_id"

    if command_exists jq; then
        local service_name
        service_name=$(jq -r '.data.service_name' "$log_file")
        local original_status
        original_status=$(jq -r '.data.original_status' "$log_file")

        if [[ "$original_status" == "active" ]]; then
            if command_exists systemctl; then
                print_info "Starting service: $service_name"
                if sudo systemctl start "$service_name"; then
                    print_success "Service started: $service_name"
                    update_operation_status "$operation_id" "completed"
                    return 0
                else
                    print_error "Failed to start service: $service_name"
                    return 1
                fi
            else
                print_error "systemctl not available for service management"
                return 1
            fi
        else
            print_info "Service was not active before, no action needed"
            update_operation_status "$operation_id" "completed"
            return 0
        fi
    else
        print_error "jq not available for processing undo operation"
        return 1
    fi
}

# Undo directory creation
undo_directory_creation() {
    local operation_id="$1"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ ! -f "$log_file" ]]; then
        print_error "Operation log not found: $operation_id"
        return 1
    fi

    print_section "Undoing Directory Creation: $operation_id"

    if command_exists jq; then
        local dir_path
        dir_path=$(jq -r '.data.directory_path' "$log_file")

        if [[ -d "$dir_path" ]]; then
            # Check if directory is empty
            if [[ -z "$(ls -A "$dir_path" 2>/dev/null)" ]]; then
                if rmdir "$dir_path" 2>/dev/null; then
                    print_success "Directory removed: $dir_path"
                    update_operation_status "$operation_id" "completed"
                    return 0
                else
                    print_error "Failed to remove directory: $dir_path"
                    return 1
                fi
            else
                print_warning "Directory not empty, manual removal required: $dir_path"
                print_info "Directory contents:"
                ls -la "$dir_path" 2>/dev/null || true
                return 1
            fi
        else
            print_info "Directory does not exist: $dir_path"
            update_operation_status "$operation_id" "completed"
            return 0
        fi
    else
        print_error "jq not available for processing undo operation"
        return 1
    fi
}

# Update operation status
update_operation_status() {
    local operation_id="$1"
    local new_status="$2"
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"

    if [[ -f "$log_file" ]] && command_exists jq; then
        local temp_log
        temp_log=$(mktemp)
        jq --arg status "$new_status" '.status = $status' "$log_file" > "$temp_log"
        mv "$temp_log" "$log_file"
    fi
}

# Perform undo operation
perform_undo() {
    local operation_id="$1"

    print_header "Undo Operation: $operation_id"

    # Get operation details
    local log_file="$UNDO_LOG_DIR/${operation_id}.log"
    if [[ ! -f "$log_file" ]]; then
        print_error "Operation not found: $operation_id"
        return 1
    fi

    if command_exists jq; then
        local operation_type
        operation_type=$(jq -r '.operation_type' "$log_file")
        local current_status
        current_status=$(jq -r '.status' "$log_file")

        print_info "Operation type: $operation_type"
        print_info "Current status: $current_status"

        if [[ "$current_status" == "completed" ]]; then
            print_warning "Operation has already been undone"
            return 0
        fi

        # Perform undo based on operation type
        case "$operation_type" in
            "file_delete")
                undo_file_deletion "$operation_id"
                ;;
            "file_modify")
                undo_file_modification "$operation_id"
                ;;
            "package_remove")
                undo_package_removal "$operation_id"
                ;;
            "service_stop")
                undo_service_stop "$operation_id"
                ;;
            "directory_create")
                undo_directory_creation "$operation_id"
                ;;
            *)
                print_error "Unknown operation type: $operation_type"
                return 1
                ;;
        esac
    else
        print_error "jq not available for processing undo operation"
        return 1
    fi
}

# List available undo operations
list_undo_operations() {
    local limit="${1:-10}"

    print_section "Recent Undo Operations (Last $limit)"

    if [[ ! -f "$UNDO_STACK_FILE" ]]; then
        print_info "No undo operations recorded"
        return 0
    fi

    local operation_count=0

    # Read from end of file (most recent first)
    while IFS= read -r operation_id; do
        if [[ $operation_count -ge $limit ]]; then
            break
        fi

        local log_file="$UNDO_LOG_DIR/${operation_id}.log"
        if [[ -f "$log_file" ]]; then
            if command_exists jq; then
                local operation_type
                operation_type=$(jq -r '.operation_type' "$log_file")
                local timestamp
                timestamp=$(jq -r '.timestamp' "$log_file")
                local description
                description=$(jq -r '.description' "$log_file")
                local status
                status=$(jq -r '.status' "$log_file")

                local status_indicator="○"
                if [[ "$status" == "completed" ]]; then
                    status_indicator="✓"
                fi

                print_indented 2 "$(format_status "info" "$status_indicator $operation_id")"
                print_indented 4 "Type: $operation_type"
                print_indented 4 "Time: $timestamp"
                print_indented 4 "Description: $description"
                echo
            else
                print_indented 2 "$operation_id"
            fi

            ((operation_count++))
        fi
    done < <(tail -n "$limit" "$UNDO_STACK_FILE" | tac)

    if [[ $operation_count -eq 0 ]]; then
        print_info "No undo operations found"
    else
        print_info "Total operations: $operation_count"
    fi
}

# Clean up old undo operations
cleanup_undo_operations() {
    local retention_days="${1:-$UNDO_RETENTION_DAYS}"

    print_section "Cleaning Up Old Undo Operations"

    local removed_count=0

    # Remove old log files
    while IFS= read -r -d '' old_log; do
        local operation_id
        operation_id=$(basename "$old_log" .log)
        print_indented 2 "$(format_status "warning" "Removing old operation: $operation_id")"

        # Remove backup files
        rm -rf "${UNDO_LOG_DIR}/${operation_id}_backup" 2>/dev/null || true
        rm -f "${UNDO_LOG_DIR}/${operation_id}_package_info.txt" 2>/dev/null || true
        rm -f "${UNDO_LOG_DIR}/${operation_id}_service_status.txt" 2>/dev/null || true

        # Remove log file
        rm "$old_log"
        ((removed_count++))
    done < <(find "$UNDO_LOG_DIR" -name "op_*.log" -mtime +$retention_days -print0 2>/dev/null)

    # Clean up undo stack
    if [[ -f "$UNDO_STACK_FILE" ]]; then
        local temp_stack
        temp_stack=$(mktemp)
        while IFS= read -r operation_id; do
            local log_file="$UNDO_LOG_DIR/${operation_id}.log"
            if [[ -f "$log_file" ]]; then
                echo "$operation_id" >> "$temp_stack"
            fi
        done < "$UNDO_STACK_FILE"
        mv "$temp_stack" "$UNDO_STACK_FILE"
    fi

    if [[ $removed_count -gt 0 ]]; then
        print_success "Removed $removed_count old undo operations"
    else
        print_info "No old undo operations to remove"
    fi

    return 0
}

# Show undo system help
show_undo_help() {
    cat << EOF
${BOLD}${CYAN}Undo System Module${RESET}
${ITALIC}Undo functionality for critical operations with comprehensive logging${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source undo-system.sh${RESET}
    ${GREEN}perform_undo${RESET} [${YELLOW}OPERATION_ID${RESET}]

${BOLD}Functions:${RESET}
    ${YELLOW}record_file_deletion${RESET}          Record file before deletion
    ${YELLOW}record_file_modification${RESET}       Record file before modification
    ${YELLOW}record_package_removal${RESET}         Record package before removal
    ${YELLOW}record_service_stop${RESET}            Record service before stopping
    ${YELLOW}record_directory_creation${RESET}      Record directory creation
    ${YELLOW}perform_undo${RESET}                   Undo a recorded operation
    ${YELLOW}list_undo_operations${RESET}           List available undo operations
    ${YELLOW}cleanup_undo_operations${RESET}        Remove old undo operations

${BOLD}Operation Types:${RESET}
    ${YELLOW}file_delete${RESET}        File deletion operations
    ${YELLOW}file_modify${RESET}        File modification operations
    ${YELLOW}package_remove${RESET}     Package removal operations
    ${YELLOW}service_stop${RESET}       Service stop operations
    ${YELLOW}directory_create${RESET}   Directory creation operations

${BOLD}Undo Storage:${RESET}
    • Log directory: $UNDO_LOG_DIR
    • Stack file: $UNDO_STACK_FILE
    • Max operations: $MAX_UNDO_OPERATIONS
    • Retention period: $UNDO_RETENTION_DAYS days

${BOLD}Usage Examples:${RESET}
    # Record file deletion
    record_file_deletion "/path/to/file" "Remove temporary file"

    # Record package removal
    record_package_removal "package-name" "apt" "Remove unused package"

    # Undo an operation
    perform_undo "op_20231102_143022_12345"

    # List recent operations
    list_undo_operations 5

${BOLD}Integration:${RESET}
    The undo system integrates with FUB cleanup operations to provide:
    • Automatic backup creation before destructive actions
    • Comprehensive operation logging
    • One-click undo functionality
    • Operation history tracking

EOF
}

# Export functions for use in other scripts
export -f init_undo_system generate_operation_id record_operation backup_file
export -f record_file_deletion record_file_modification record_package_removal
export -f record_service_stop record_directory_creation get_operation_details
export -f undo_file_deletion undo_file_modification undo_package_removal
export -f undo_service_stop undo_directory_creation perform_undo
export -f list_undo_operations cleanup_undo_operations show_undo_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    case "${1:-help}" in
        "list")
            list_undo_operations "${2:-10}"
            ;;
        "undo")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 undo <operation_id>"
                exit 1
            fi
            perform_undo "$2"
            ;;
        "cleanup")
            cleanup_undo_operations "${2:-$UNDO_RETENTION_DAYS}"
            ;;
        "details")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 details <operation_id>"
                exit 1
            fi
            get_operation_details "$2"
            ;;
        *)
            show_undo_help
            ;;
    esac
fi