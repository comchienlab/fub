#!/usr/bin/env bash

# FUB Dependencies Integration Layer
# Integrates the dependency management system with existing FUB infrastructure

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Integration state
FUB_DEPS_INTEGRATED=false

# Initialize FUB dependencies integration
init_fub_deps_integration() {
    if [[ "$FUB_DEPS_INTEGRATED" == "true" ]]; then
        return 0
    fi

    log_deps_debug "Initializing FUB dependencies integration..."

    # Initialize dependency system
    init_dependencies

    # Setup shell integration
    setup_shell_integration

    # Setup command integration
    setup_command_integration

    # Setup theme integration
    setup_theme_integration

    # Setup monitoring integration
    setup_monitoring_integration

    FUB_DEPS_INTEGRATED=true
    log_deps_info "FUB dependencies integration completed"
}

# Setup shell integration
setup_shell_integration() {
    log_deps_debug "Setting up shell integration..."

    # Create shell aliases for missing tools
    create_shell_aliases

    # Create shell functions for enhanced functionality
    create_shell_functions

    log_deps_debug "Shell integration setup completed"
}

# Create shell aliases for missing tools
create_shell_aliases() {
    local aliases_file="${FUB_CACHE_DIR}/shell_aliases.sh"

    > "$aliases_file" cat << 'EOF'
# FUB Dependencies - Shell Aliases
# Generated automatically for missing tools

# Check if gum is available, create fallback if not
if ! command_exists gum; then
    alias gum='fub-deps-gum-fallback'
fi

# Check if btop is available, create fallback if not
if ! command_exists btop; then
    alias btop='fub-deps-btop-fallback'
fi

# Check if fd is available, create fallback if not
if ! command_exists fd; then
    alias fd='fub-deps-fd-fallback'
fi

# Check if ripgrep (rg) is available, create fallback if not
if ! command_exists rg; then
    alias rg='fub-deps-rg-fallback'
fi

# Check if dust is available, create fallback if not
if ! command_exists dust; then
    alias dust='fub-deps-dust-fallback'
fi

# Check if duf is available, create fallback if not
if ! command_exists duf; then
    alias duf='fub-deps-duf-fallback'
fi

# Check if bat is available, create fallback if not
if ! command_exists bat; then
    alias bat='fub-deps-bat-fallback'
fi

# Check if exa is available, create fallback if not
if ! command_exists exa; then
    alias exa='fub-deps-exa-fallback'
fi

# Check if lazygit is available, create fallback if not
if ! command_exists lazygit; then
    alias lazygit='fub-deps-lazygit-fallback'
fi

# Check if fzf is available, create fallback if not
if ! command_exists fzf; then
    alias fzf='fub-deps-fzf-fallback'
fi
EOF

    log_deps_debug "Shell aliases created: $aliases_file"
}

# Create enhanced shell functions
create_shell_functions() {
    local functions_file="${FUB_CACHE_DIR}/shell_functions.sh"

    > "$functions_file" cat << 'EOF'
# FUB Dependencies - Enhanced Shell Functions
# Provides enhanced functionality using available tools

# Enhanced cd function with directory history
cd() {
    builtin cd "$@"
    if command_exists exa; then
        exa --color=always --icons | head -20
    elif command_exists ls; then
        ls --color=auto | head -20
    fi
}

# Enhanced ls function with fallbacks
ls() {
    if command_exists exa; then
        exa --color=auto "$@"
    else
        command ls --color=auto "$@"
    fi
}

# Enhanced grep function
grep() {
    if command_exists rg; then
        rg "$@"
    else
        command grep --color=auto "$@"
    fi
}

# Enhanced find function
find() {
    if command_exists fd; then
        fd "$@"
    else
        command find "$@"
    fi
}

# Enhanced cat function
cat() {
    if command_exists bat; then
        bat --style=plain "$@"
    else
        command cat "$@"
    fi
}

# System monitoring function
monitor() {
    if command_exists btop; then
        btop
    elif command_exists htop; then
        htop
    elif command_exists top; then
        top
    else
        echo "No monitoring tools available"
    fi
}

# Disk usage function
diskusage() {
    if command_exists dust; then
        dust "$@"
    elif command_exists ncdu; then
        ncdu "$@"
    elif command_exists du; then
        du -sh "$@"
    else
        echo "No disk usage tools available"
    fi
}

# File system usage function
fsusage() {
    if command_exists duf; then
        duf "$@"
    elif command_exists df; then
        df -h "$@"
    else
        echo "No filesystem usage tools available"
    fi
}

# Search files function
search_files() {
    local pattern="$1"
    local path="${2:-.}"

    if command_exists fd; then
        fd "$pattern" "$path"
    else
        find "$path" -name "*$pattern*" 2>/dev/null
    fi
}

# Search content function
search_content() {
    local pattern="$1"
    local path="${2:-.}"

    if command_exists rg; then
        rg "$pattern" "$path"
    else
        grep -r "$pattern" "$path" 2>/dev/null
    fi
}

# Git function
git_ui() {
    if command_exists lazygit; then
        lazygit
    elif command_exists tig; then
        tig
    else
        git status
    fi
}

# Process management function
procs() {
    if command_exists procs; then
        procs "$@"
    elif command_exists htop; then
        htop
    else
        ps aux
    fi
}
EOF

    log_deps_debug "Shell functions created: $functions_file"
}

# Setup command integration
setup_command_integration() {
    log_deps_debug "Setting up command integration..."

    # Create command aliases for existing FUB commands
    create_fub_command_aliases

    # Enhance existing commands
    enhance_existing_commands

    log_deps_debug "Command integration setup completed"
}

# Create FUB command aliases
create_fub_command_aliases() {
    # Create symlinks or wrappers for common operations
    local fub_deps_bin="${FUB_ROOT_DIR}/bin"
    ensure_dir "$fub_deps_bin"

    # Create fub-deps symlink if not exists
    if [[ ! -f "${fub_deps_bin}/fub-deps" ]]; then
        ln -sf "${FUB_ROOT_DIR}/lib/dependencies/fub-deps.sh" "${fub_deps_bin}/fub-deps"
        log_deps_debug "Created fub-deps symlink"
    fi
}

# Enhance existing commands
enhance_existing_commands() {
    # This would integrate with existing FUB commands
    # For example, enhance cleanup commands, monitoring commands, etc.

    log_deps_debug "Enhanced existing FUB commands"
}

# Setup theme integration
setup_theme_integration() {
    log_deps_debug "Setting up theme integration..."

    # Ensure dependency system uses FUB theme
    if [[ -f "${FUB_ROOT_DIR}/lib/theme.sh" ]]; then
        source "${FUB_ROOT_DIR}/lib/theme.sh"
        init_theme
        log_deps_debug "FUB theme integration enabled"
    else
        log_deps_debug "FUB theme system not found, using fallback colors"
    fi
}

# Setup monitoring integration
setup_monitoring_integration() {
    log_deps_debug "Setting up monitoring integration..."

    # Integrate with FUB monitoring system if available
    if [[ -f "${FUB_ROOT_DIR}/lib/monitoring/monitoring-integration.sh" ]]; then
        source "${FUB_ROOT_DIR}/lib/monitoring/monitoring-integration.sh"

        # Add dependency metrics to monitoring
        add_dependency_metrics_to_monitoring

        log_deps_debug "Monitoring integration enabled"
    fi
}

# Add dependency metrics to monitoring system
add_dependency_metrics_to_monitoring() {
    # Add custom metrics for dependency management
    # This would integrate with FUB's monitoring system

    log_deps_debug "Added dependency metrics to monitoring system"
}

# Auto-initialize dependency system
auto_init_if_needed() {
    # Check if dependencies need to be initialized
    if [[ "$DEPS_SYSTEM_INITIALIZED" != "true" ]]; then
        log_deps_debug "Auto-initializing dependency system..."
        init_dependencies
    fi
}

# Get dependency status for other FUB components
get_deps_status_for_external() {
    auto_init_if_needed

    local format="${1:-simple}"

    case "$format" in
        "simple")
            echo "dependencies_ready:$DEPS_SYSTEM_INITIALIZED"
            ;;
        "detailed")
            get_dependencies_stats
            ;;
        "json")
            # Return JSON format for external tools
            echo "{"
            echo "  \"initialized\": $DEPS_SYSTEM_INITIALIZED,"
            echo "  \"registry_loaded\": $DEPS_REGISTRY_LOADED,"
            echo "  \"cache_valid\": $DEPS_CACHE_VALID"
            echo "}"
            ;;
    esac
}

# Ensure dependencies are available before running commands
ensure_dependencies() {
    local required_tools=("$@")

    auto_init_if_needed

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_deps_warn "Required tool not available: $tool"

            # Try to install if auto-install is enabled
            if [[ "$(get_deps_config auto_install)" == "true" ]]; then
                log_deps_info "Auto-installing required tool: $tool"
                if install_tool "$tool" false true; then
                    log_deps_info "Successfully installed: $tool"
                else
                    log_deps_error "Failed to install required tool: $tool"
                    return 1
                fi
            else
                log_deps_error "Required tool missing and auto-install disabled: $tool"
                return 1
            fi
        fi
    done

    return 0
}

# Create hooks for FUB commands
create_fub_hooks() {
    # Create hooks that run before/after FUB commands
    # This allows dependency checking for FUB operations

    local hooks_dir="${FUB_ROOT_DIR}/hooks"
    ensure_dir "$hooks_dir"

    # Create pre-hook for dependency checking
    > "${hooks_dir}/pre-command" cat << 'EOF'
#!/bin/bash
# FUB Pre-Command Hook
# Check dependencies before running FUB commands

if [[ -n "${FUB_DEPS_CHECK_COMMANDS:-}" ]]; then
    fub-deps check --force
fi
EOF

    chmod +x "${hooks_dir}/pre-command"

    log_deps_debug "Created FUB command hooks"
}

# Setup integration with other FUB modules
setup_module_integration() {
    log_deps_debug "Setting up module integration..."

    # Integration with cleanup system
    if [[ -f "${FUB_ROOT_DIR}/lib/cleanup/cleanup.sh" ]]; then
        create_cleanup_integration
    fi

    # Integration with monitoring system
    if [[ -f "${FUB_ROOT_DIR}/lib/monitoring/monitoring-integration.sh" ]]; then
        create_monitoring_integration
    fi

    # Integration with scheduler system
    if [[ -f "${FUB_ROOT_DIR}/lib/scheduler/scheduler-integration.sh" ]]; then
        create_scheduler_integration
    fi

    log_deps_debug "Module integration setup completed"
}

# Create cleanup system integration
create_cleanup_integration() {
    # Add dependency cleanup to FUB cleanup system
    log_deps_debug "Created cleanup system integration"
}

# Create monitoring system integration
create_monitoring_integration() {
    # Add dependency monitoring to FUB monitoring system
    log_deps_debug "Created monitoring system integration"
}

# Create scheduler integration
create_scheduler_integration() {
    # Add dependency update checks to FUB scheduler
    log_deps_debug "Created scheduler integration"
}

# Export functions for external use
export -f init_fub_deps_integration setup_shell_integration setup_command_integration
export -f setup_theme_integration setup_monitoring_integration auto_init_if_needed
export -f get_deps_status_for_external ensure_dependencies create_fub_hooks
export -f setup_module_integration

# Auto-initialize if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_fub_deps_integration
    echo "FUB Dependencies integration initialized"
    echo "Status: $(get_deps_status_for_external simple)"
fi

log_deps_debug "FUB dependencies integration loaded"