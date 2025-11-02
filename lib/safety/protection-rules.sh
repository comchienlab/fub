#!/usr/bin/env bash

# FUB Protection Rules Module
# Whitelist/blacklist configuration system for safety protection

set -euo pipefail

# Source dependencies
readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${FUB_SCRIPT_DIR}/lib/common.sh"
source "${FUB_SCRIPT_DIR}/lib/ui.sh"
source "${FUB_SCRIPT_DIR}/lib/theme.sh"

# Protection rules constants
readonly PROTECTION_RULES_VERSION="1.0.0"
readonly PROTECTION_RULES_DESCRIPTION="Whitelist/blacklist configuration system"

# Configuration paths
readonly GLOBAL_CONFIG_DIR="/etc/fub"
readonly USER_CONFIG_DIR="/home/$USER/.config/fub"
readonly LOCAL_CONFIG_DIR="$FUB_SCRIPT_DIR/.fub"

# Rule types
declare -a RULE_TYPES=("whitelist" "blacklist" "protect" "ignore" "priority")
declare -a RULE_CATEGORIES=("files" "directories" "processes" "services" "packages" "patterns")

# Default protection rules
declare -A DEFAULT_PROTECTION_RULES=(
    # Critical system paths
    ["whitelist_directories"]="/bin /sbin /usr/bin /usr/sbin /etc /lib /lib64 /boot /sys /proc /dev"
    # User configuration files
    ["whitelist_files"]="/home/$USER/.ssh /home/$USER/.gnupg /home/$USER/.bashrc /home/$USER/.profile /home/$USER/.zshrc"
    # Development environments
    ["protect_directories"]="/home/$USER/projects /home/$USER/dev /home/$USER/src /home/$USER/workspace /home/$USER/code"
    # Important processes
    ["protect_processes"]="sshd systemd cron mysqld postgresql nginx docker"
    # Package protection
    ["protect_packages"]="ubuntu-minimal ubuntu-standard systemd coreutils"
    # Temporary files to clean
    ["blacklist_patterns"]="*.tmp *.log *.cache *~ .#* #*# *.swp *.swo"
)

# Initialize protection rules module
init_protection_rules() {
    log_info "Initializing protection rules module v$PROTECTION_RULES_VERSION"
    log_debug "Protection rules module initialized"

    # Ensure configuration directories exist
    mkdir -p "$GLOBAL_CONFIG_DIR" "$USER_CONFIG_DIR" "$LOCAL_CONFIG_DIR"
}

# Get configuration file path for a rule type
get_config_file() {
    local rule_type="$1"
    local config_level="${2:-user}"  # Can be: global, user, local

    case "$config_level" in
        "global")
            echo "$GLOBAL_CONFIG_DIR/${rule_type}.rules"
            ;;
        "user")
            echo "$USER_CONFIG_DIR/${rule_type}.rules"
            ;;
        "local")
            echo "$LOCAL_CONFIG_DIR/${rule_type}.rules"
            ;;
        *)
            echo "$USER_CONFIG_DIR/${rule_type}.rules"
            ;;
    esac
}

# Load rules from configuration file
load_rules() {
    local rule_type="$1"
    local config_level="${2:-user}"
    local config_file
    config_file=$(get_config_file "$rule_type" "$config_level")

    local -a loaded_rules

    if [[ -f "$config_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue

            # Clean up the line
            rule=$(echo "$line" | xargs)

            if [[ -n "$rule" ]]; then
                loaded_rules+=("$rule")
            fi
        done < "$config_file"
    fi

    # Return rules as space-separated string
    echo "${loaded_rules[*]}"
}

# Save rules to configuration file
save_rules() {
    local rule_type="$1"
    shift
    local -a rules=("$@")
    local config_level="${2:-user}"
    local config_file
    config_file=$(get_config_file "$rule_type" "$config_level")

    # Create backup of existing config
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi

    # Write rules to file
    {
        echo "# FUB Protection Rules: $rule_type"
        echo "# Generated on $(date)"
        echo "#"
        echo "# Rules format: one rule per line"
        echo "# Comments start with #"
        echo "#"

        for rule in "${rules[@]}"; do
            echo "$rule"
        done
    } > "$config_file"

    print_success "Rules saved to: $config_file"
}

# Get all rules for a type (merge from all levels)
get_all_rules() {
    local rule_type="$1"
    local -a all_rules

    # Load in priority order: global -> user -> local
    local global_rules
    global_rules=$(load_rules "$rule_type" "global")
    if [[ -n "$global_rules" ]]; then
        all_rules+=($global_rules)
    fi

    local user_rules
    user_rules=$(load_rules "$rule_type" "user")
    if [[ -n "$user_rules" ]]; then
        all_rules+=($user_rules)
    fi

    local local_rules
    local_rules=$(load_rules "$rule_type" "local")
    if [[ -n "$local_rules" ]]; then
        all_rules+=($local_rules)
    fi

    # Return rules as space-separated string
    echo "${all_rules[*]}"
}

# Check if path matches any rule
check_path_rules() {
    local path="$1"
    local -a rules=("${@:2}")

    # Normalize path
    local real_path
    real_path=$(realpath "$path" 2>/dev/null || echo "$path")

    for rule in "${rules[@]}"; do
        # Handle different rule patterns
        if [[ "$rule" == "/"* ]]; then
            # Absolute path rule
            if [[ "$real_path" == "$rule"* ]]; then
                return 0  # Match found
            fi
        elif [[ "$rule" == *"*"* ]]; then
            # Wildcard pattern
            if [[ "$real_path" == $rule ]]; then
                return 0  # Match found
            fi
        elif [[ "$rule" == "."* ]]; then
            # Relative path rule (check basename and dirname)
            local basename_rule
            basename_rule="${rule##./}"
            if [[ "$(basename "$real_path")" == "$basename_rule" ]]; then
                return 0  # Match found
            fi
        fi
    done

    return 1  # No match found
}

# Check if process is protected
check_process_protection() {
    local process_name="$1"
    local -a protect_rules
    read -ra protect_rules <<< "$(get_all_rules "protect")"

    for rule in "${protect_rules[@]}"; do
        if [[ "$rule" == "processes:"* ]]; then
            local process_rule="${rule#processes:}"
            if [[ "$process_name" == "$process_rule" ]] || [[ "$process_name" == *"$process_rule"* ]]; then
                return 0  # Process is protected
            fi
        fi
    done

    return 1  # Process not protected
}

# Check if service is protected
check_service_protection() {
    local service_name="$1"
    local -a protect_rules
    read -ra protect_rules <<< "$(get_all_rules "protect")"

    for rule in "${protect_rules[@]}"; do
        if [[ "$rule" == "services:"* ]]; then
            local service_rule="${rule#services:}"
            if [[ "$service_name" == "$service_rule" ]] || [[ "$service_name" == *"$service_rule"* ]]; then
                return 0  # Service is protected
            fi
        fi
    done

    return 1  # Service not protected
}

# Check if package is protected
check_package_protection() {
    local package_name="$1"
    local -a protect_rules
    read -ra protect_rules <<< "$(get_all_rules "protect")"

    for rule in "${protect_rules[@]}"; do
        if [[ "$rule" == "packages:"* ]]; then
            local package_rule="${rule#packages:}"
            if [[ "$package_name" == "$package_rule" ]] || [[ "$package_name" == *"$package_rule"* ]]; then
                return 0  # Package is protected
            fi
        fi
    done

    return 1  # Package not protected
}

# Apply protection rules to a list of items
apply_protection_rules() {
    local rule_category="$1"
    shift
    local -a items=("$@")
    local -a protected_items=()
    local -a allowed_items=()

    # Load relevant rules
    local -a whitelist_rules
    read -ra whitelist_rules <<< "$(get_all_rules "whitelist")"

    local -a protect_rules
    read -ra protect_rules <<< "$(get_all_rules "protect")"

    local -a blacklist_rules
    read -ra blacklist_rules <<< "$(get_all_rules "blacklist")"

    print_section "Applying Protection Rules: $rule_category"

    for item in "${items[@]}"; do
        local is_protected=false
        local is_blacklisted=false

        # Check whitelist (whitelist overrides protection)
        for rule in "${whitelist_rules[@]}"; do
            if [[ "$rule" == "${rule_category}:"* ]]; then
                local pattern="${rule#${rule_category}:}"
                if [[ "$item" == $pattern ]]; then
                    is_protected=false
                    break
                fi
            fi
        done

        # Check protection rules
        if [[ "$is_protected" == "false" ]]; then
            for rule in "${protect_rules[@]}"; do
                if [[ "$rule" == "${rule_category}:"* ]]; then
                    local pattern="${rule#${rule_category}:}"
                    if [[ "$item" == $pattern ]]; then
                        is_protected=true
                        break
                    fi
                fi
            done
        fi

        # Check blacklist
        for rule in "${blacklist_rules[@]}"; do
            if [[ "$rule" == "${rule_category}:"* ]]; then
                local pattern="${rule#${rule_category}:}"
                if [[ "$item" == $pattern ]]; then
                    is_blacklisted=true
                    break
                fi
            fi
        done

        # Categorize the item
        if [[ "$is_blacklisted" == "true" ]]; then
            allowed_items+=("$item")
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "warning" "Blacklisted: $item")"
            fi
        elif [[ "$is_protected" == "true" ]]; then
            protected_items+=("$item")
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "success" "Protected: $item")"
            fi
        else
            allowed_items+=("$item")
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Allowed: $item")"
            fi
        fi
    done

    # Export results for other modules
    export FUB_PROTECTED_ITEMS="${protected_items[*]}"
    export FUB_ALLOWED_ITEMS="${allowed_items[*]}"

    # Report summary
    print_info "Protection rules applied"
    print_info "Protected items: ${#protected_items[@]}"
    print_info "Allowed items: ${#allowed_items[@]}"

    return 0
}

# Create default protection rules
create_default_rules() {
    local config_level="${1:-user}"

    print_section "Creating Default Protection Rules"

    # Create default whitelist
    local -a default_whitelist=(
        "files:/etc/fstab"
        "files:/etc/passwd"
        "files:/etc/group"
        "files:/home/$USER/.ssh"
        "files:/home/$USER/.gnupg"
        "directories:/bin"
        "directories:/sbin"
        "directories:/usr/bin"
        "directories:/usr/sbin"
        "directories:/etc"
        "directories:/lib"
        "directories:/boot"
    )

    save_rules "whitelist" "${default_whitelist[@]}" "$config_level"

    # Create default protection rules
    local -a default_protect=(
        "files:/home/$USER/.bashrc"
        "files:/home/$USER/.profile"
        "files:/home/$USER/.zshrc"
        "files:/home/$USER/.env*"
        "directories:/home/$USER/projects"
        "directories:/home/$USER/dev"
        "directories:/home/$USER/src"
        "directories:/home/$USER/workspace"
        "processes:sshd"
        "processes:systemd"
        "processes:mysqld"
        "processes:postgresql"
        "services:ssh"
        "services:networking"
        "packages:ubuntu-minimal"
        "packages:ubuntu-standard"
        "packages:systemd"
    )

    save_rules "protect" "${default_protect[@]}" "$config_level"

    # Create default blacklist
    local -a default_blacklist=(
        "files:*.tmp"
        "files:*.log"
        "files:*.cache"
        "files:*~"
        "files:.#*"
        "files:#*#"
        "files:*.swp"
        "files:*.swo"
        "directories:/tmp"
        "directories:/var/tmp"
        "patterns:node_modules"
        "patterns:.git/objects"
        "patterns:__pycache__"
    )

    save_rules "blacklist" "${default_blacklist[@]}" "$config_level"

    print_success "Default protection rules created for: $config_level"
    return 0
}

# Import rules from file
import_rules() {
    local rule_file="$1"
    local rule_type="$2"
    local config_level="${3:-user}"

    if [[ ! -f "$rule_file" ]]; then
        print_error "Rule file not found: $rule_file"
        return 1
    fi

    print_section "Importing Rules: $rule_type"

    local -a imported_rules=()
    local line_number=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Clean up the line
        rule=$(echo "$line" | xargs)

        if [[ -n "$rule" ]]; then
            imported_rules+=("$rule")
            if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                print_indented 2 "$(format_status "info" "Imported: $rule")"
            fi
        fi
    done < "$rule_file"

    if [[ ${#imported_rules[@]} -gt 0 ]]; then
        save_rules "$rule_type" "${imported_rules[@]}" "$config_level"
        print_success "Imported ${#imported_rules[@]} rules for $rule_type"
    else
        print_warning "No rules found in file: $rule_file"
    fi

    return 0
}

# Export rules to file
export_rules() {
    local rule_type="$1"
    local export_file="$2"
    local config_level="${3:-user}"

    print_section "Exporting Rules: $rule_type"

    local -a rules
    read -ra rules <<< "$(load_rules "$rule_type" "$config_level")"

    if [[ ${#rules[@]} -eq 0 ]]; then
        print_warning "No rules found for $rule_type"
        return 1
    fi

    # Create export file
    {
        echo "# FUB Exported Rules: $rule_type"
        echo "# Exported on $(date) from $config_level configuration"
        echo "#"

        for rule in "${rules[@]}"; do
            echo "$rule"
        done
    } > "$export_file"

    print_success "Exported ${#rules[@]} rules to: $export_file"
    return 0
}

# Validate rule syntax
validate_rules() {
    local rule_type="$1"
    local config_level="${2:-user}"

    print_section "Validating Rules: $rule_type"

    local -a rules
    read -ra rules <<< "$(load_rules "$rule_type" "$config_level")"

    local valid_rules=0
    local invalid_rules=0

    for rule in "${rules[@]}"; do
        # Check rule format (should be category:pattern or just pattern)
        if [[ "$rule" == *":"* ]]; then
            local category="${rule%%:*}"
            local pattern="${rule#*:}"

            # Check if category is valid
            local valid_category=false
            for valid_cat in "${RULE_CATEGORIES[@]}"; do
                if [[ "$category" == "$valid_cat" ]]; then
                    valid_category=true
                    break
                fi
            done

            if [[ "$valid_category" == "true" ]] && [[ -n "$pattern" ]]; then
                ((valid_rules++))
                if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "success" "Valid: $rule")"
                fi
            else
                ((invalid_rules++))
                print_indented 2 "$(format_status "error" "Invalid category or empty pattern: $rule")"
            fi
        else
            # Simple pattern rule (assume it applies to all categories)
            if [[ -n "$rule" ]]; then
                ((valid_rules++))
                if [[ "$SAFETY_VERBOSE" == "true" ]]; then
                    print_indented 2 "$(format_status "success" "Valid: $rule")"
                fi
            else
                ((invalid_rules++))
                print_indented 2 "$(format_status "error" "Empty rule")"
            fi
        fi
    done

    print_success "Rule validation completed"
    print_info "Valid rules: $valid_rules"
    if [[ $invalid_rules -gt 0 ]]; then
        print_warning "Invalid rules: $invalid_rules"
        return 1
    else
        return 0
    fi
}

# Show current rules
show_rules() {
    local rule_type="${1:-all}"
    local config_level="${2:-user}"

    print_section "Protection Rules: $rule_type ($config_level)"

    if [[ "$rule_type" == "all" ]]; then
        for type in "${RULE_TYPES[@]}"; do
            show_rules "$type" "$config_level"
        done
        return 0
    fi

    local config_file
    config_file=$(get_config_file "$rule_type" "$config_level")

    if [[ -f "$config_file" ]]; then
        print_info "Rules from: $config_file"
        echo
        cat "$config_file"
    else
        print_info "No rules found for $rule_type at $config_level"
        print_info "Use 'create_default_rules' to create initial rules"
    fi

    return 0
}

# Perform comprehensive rule management
perform_rule_management() {
    local action="${1:-show}"
    local rule_type="${2:-all}"
    local config_level="${3:-user}"

    print_header "Protection Rules Management"
    print_info "Action: $action, Type: $rule_type, Level: $config_level"

    # Initialize module
    init_protection_rules

    case "$action" in
        "show")
            show_rules "$rule_type" "$config_level"
            ;;
        "create-default")
            create_default_rules "$config_level"
            ;;
        "validate")
            if [[ "$rule_type" == "all" ]]; then
                local validation_failed=false
                for type in "${RULE_TYPES[@]}"; do
                    if ! validate_rules "$type" "$config_level"; then
                        validation_failed=true
                    fi
                done

                if [[ "$validation_failed" == "true" ]]; then
                    return 1
                fi
            else
                validate_rules "$rule_type" "$config_level"
            fi
            ;;
        "import")
            if [[ $# -lt 4 ]]; then
                print_error "Import requires source file path"
                return 1
            fi
            import_rules "$4" "$rule_type" "$config_level"
            ;;
        "export")
            if [[ $# -lt 4 ]]; then
                print_error "Export requires destination file path"
                return 1
            fi
            export_rules "$rule_type" "$4" "$config_level"
            ;;
        *)
            print_error "Unknown action: $action"
            print_info "Available actions: show, create-default, validate, import, export"
            return 1
            ;;
    esac

    return 0
}

# Show protection rules help
show_protection_help() {
    cat << EOF
${BOLD}${CYAN}Protection Rules Module${RESET}
${ITALIC}Whitelist/blacklist configuration system for safety protection${RESET}

${BOLD}Usage:${RESET}
    ${GREEN}source protection-rules.sh${RESET}
    ${GREEN}perform_rule_management${RESET} [${YELLOW}ACTION${RESET}] [${YELLOW}TYPE${RESET}] [${YELLOW}LEVEL${RESET}]

${BOLD}Functions:${RESET}
    ${YELLOW}load_rules${RESET}                    Load rules from configuration file
    ${YELLOW}save_rules${RESET}                    Save rules to configuration file
    ${YELLOW}check_path_rules${RESET}              Check if path matches protection rules
    ${YELLOW}check_process_protection${RESET}      Check if process is protected
    ${YELLOW}check_service_protection${RESET}      Check if service is protected
    ${YELLOW}check_package_protection${RESET}      Check if package is protected
    ${YELLOW}apply_protection_rules${RESET}        Apply rules to item list
    ${YELLOW}create_default_rules${RESET}          Create default protection rules
    ${YELLOW}import_rules${RESET}                  Import rules from file
    ${YELLOW}export_rules${RESET}                  Export rules to file
    ${YELLOW}validate_rules${RESET}                Validate rule syntax
    ${YELLOW}show_rules${RESET}                    Display current rules
    ${YELLOW}perform_rule_management${RESET}       Comprehensive rule management

${BOLD}Rule Types:${RESET}
    ${YELLOW}whitelist${RESET}    Items that are explicitly allowed (overrides protection)
    ${YELLOW}blacklist${RESET}    Items that are explicitly disallowed for cleanup
    ${YELLOW}protect${RESET}      Items that are protected from modification/deletion
    ${YELLOW}ignore${RESET}       Items to ignore during scanning
    ${YELLOW}priority${RESET}     High-priority items for special handling

${BOLD}Rule Categories:${RESET}
    ${YELLOW}files${RESET}         Individual files
    ${YELLOW}directories${RESET}   Directory paths
    ${YELLOW}processes${RESET}     Running processes
    ${YELLOW}services${RESET}      System services
    ${YELLOW}packages${RESET}      Software packages
    ${YELLOW}patterns${RESET}      Pattern-based matches

${BOLD}Configuration Levels:${RESET}
    ${YELLOW}global${RESET}         System-wide rules (${GLOBAL_CONFIG_DIR})
    ${YELLOW}user${RESET}           User-specific rules (${USER_CONFIG_DIR})
    ${YELLOW}local${RESET}          Project-specific rules (${LOCAL_CONFIG_DIR})

${BOLD}Rule Format:${RESET}
    • Category-specific: files:/path/to/file
    • Pattern-based: directories:/home/*/projects
    • Process protection: processes:sshd
    • Service protection: services:mysql
    • Package protection: packages:ubuntu-minimal

${BOLD}Actions:${RESET}
    ${YELLOW}show${RESET}              Display current rules
    ${YELLOW}create-default${RESET}    Create default rule set
    ${YELLOW}validate${RESET}          Validate rule syntax
    ${YELLOW}import${RESET}            Import rules from file
    ${YELLOW}export${RESET}            Export rules to file

${BOLD}Examples:${RESET}
    perform_rule_management show all user
    perform_rule_management create-default all user
    perform_rule_management validate protect user
    perform_rule_management import whitelist user /path/to/rules.txt

EOF
}

# Export functions for use in other scripts
export -f init_protection_rules get_config_file load_rules save_rules
export -f get_all_rules check_path_rules check_process_protection
export -f check_service_protection check_package_protection apply_protection_rules
export -f create_default_rules import_rules export_rules validate_rules show_rules
export -f perform_rule_management show_protection_help

# Initialize module if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    perform_rule_management "$@"
fi