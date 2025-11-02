#!/usr/bin/env bash

# FUB Dependencies Registry
# Central registry for all supported tools and their metadata

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/types/dependency.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/config.sh"

# Registry state
DEPS_REGISTRY_LOADED=false
DEPS_REGISTRY_LOADED_COUNT=0

# Initialize the dependency registry
init_deps_registry() {
    log_deps_debug "Initializing dependency registry..."

    # Load built-in tools
    load_builtin_tools

    # Load custom tools from registry file if it exists
    if file_exists "$DEPS_REGISTRY_FILE"; then
        load_registry_from_file "$DEPS_REGISTRY_FILE"
    else
        create_default_registry_file
    fi

    DEPS_REGISTRY_LOADED=true
    DEPS_REGISTRY_LOADED_COUNT=$DEPS_TOOL_count

    log_deps_info "Dependency registry initialized with $DEPS_REGISTRY_LOADED_COUNT tools"
}

# Load built-in tools registry
load_builtin_tools() {
    log_deps_debug "Loading built-in tools registry..."

    # Core Tools (Category: core)
    register_tool "gum" \
        "$DEPS_CATEGORY_CORE" \
        "Interactive terminal UI for shell scripts" \
        "apt:gum,snap:gum,brew:gum" \
        "0.8.0" \
        "gum" \
        "interactive-ui,tui,dialogs,forms" \
        "Enhanced interactive experiences with beautiful dialogs, forms, and menus" \
        95 \
        "15MB"

    register_tool "btop" \
        "$DEPS_CATEGORY_CORE" \
        "Advanced system resource monitor" \
        "apt:btop,snap:btop,brew:btop" \
        "1.2.0" \
        "btop" \
        "monitoring,system-stats,resource-usage" \
        "Beautiful real-time system monitoring with detailed resource usage" \
        90 \
        "2MB"

    register_tool "fd" \
        "$DEPS_CATEGORY_CORE" \
        "Simple, fast and user-friendly alternative to find" \
        "apt:fd-find,snap:fd,brew:fd" \
        "8.0.0" \
        "fd,fd-find" \
        "file-search,find-alternative,search" \
        "Intuitive file finding with smart defaults and syntax highlighting" \
        85 \
        "5MB"

    register_tool "ripgrep" \
        "$DEPS_CATEGORY_CORE" \
        "Fast search tool that recursively searches directories" \
        "apt:ripgrep,snap:ripgrep,brew:ripgrep" \
        "13.0.0" \
        "rg,ripgrep" \
        "search,grep-alternative,text-search" \
        "Blazing fast text search with ripgrep for instant results" \
        85 \
        "8MB"

    # Enhanced Tools (Category: enhanced)
    register_tool "dust" \
        "$DEPS_CATEGORY_ENHANCED" \
        "More intuitive version of du in rust" \
        "apt:dust,snap:dust,brew:dust" \
        "0.8.0" \
        "dust" \
        "disk-usage,du-alternative,storage-analysis" \
        "Visual disk usage analysis with intuitive tree display" \
        70 \
        "3MB"

    register_tool "duf" \
        "$DEPS_CATEGORY_ENHANCED" \
        "Disk Usage/Free Utility - a better 'df' alternative" \
        "apt:duf,snap:duf,brew:duf" \
        "0.8.0" \
        "duf" \
        "disk-space,df-alternative,mount-points" \
        "Beautiful disk usage display across all mount points" \
        70 \
        "4MB"

    register_tool "procs" \
        "$DEPS_CATEGORY_ENHANCED" \
        "Modern replacement for ps" \
        "apt:procs,snap:procs,brew:procs" \
        "0.13.0" \
        "procs" \
        "process-management,ps-alternative,process-list" \
        "Modern process viewer with search, sorting, and visual indicators" \
        65 \
        "6MB"

    register_tool "bat" \
        "$DEPS_CATEGORY_ENHANCED" \
        "A cat clone with wings" \
        "apt:bat,snap:bat,brew:bat" \
        "0.22.0" \
        "bat" \
        "cat-alternative,file-viewer,syntax-highlighting" \
        "Enhanced file viewing with syntax highlighting and git integration" \
        75 \
        "10MB"

    register_tool "exa" \
        "$DEPS_CATEGORY_ENHANCED" \
        "A modern replacement for ls" \
        "apt:exa,snap:exa,brew:exa" \
        "0.10.0" \
        "exa" \
        "ls-alternative,file-listing,directory-browser" \
        "Modern directory listing with colors, icons, and git integration" \
        75 \
        "8MB"

    # Development Tools (Category: development)
    register_tool "git-delta" \
        "$DEPS_CATEGORY_DEVELOPMENT" \
        "Syntax-highlighting pager for git and diff output" \
        "apt:git-delta,snap:git-delta,brew:git-delta" \
        "0.15.0" \
        "delta" \
        "git,diff,pager,syntax-highlighting" \
        "Beautiful diff display with syntax highlighting and improved readability" \
        80 \
        "12MB"

    register_tool "lazygit" \
        "$DEPS_CATEGORY_DEVELOPMENT" \
        "Simple terminal UI for git commands" \
        "apt:lazygit,snap:lazygit,brew:lazygit" \
        "0.35.0" \
        "lazygit" \
        "git,git-ui,version-control" \
        "Intuitive git interface with visual commit history and branch management" \
        85 \
        "20MB"

    register_tool "tig" \
        "$DEPS_CATEGORY_DEVELOPMENT" \
        "Text-mode interface for git" \
        "apt:tig,snap:tig,brew:tig" \
        "2.5.0" \
        "tig" \
        "git,git-ui,text-interface" \
        "Powerful text-mode git repository browser and interface" \
        70 \
        "5MB"

    # System Tools (Category: system)
    register_tool "neofetch" \
        "$DEPS_CATEGORY_SYSTEM" \
        "Fast, highly customizable system info script" \
        "apt:neofetch,snap:neofetch,brew:neofetch" \
        "7.1.0" \
        "neofetch" \
        "system-info,system-display,ascii-art" \
        "Beautiful system information display with ASCII art logos" \
        60 \
        "2MB"

    register_tool "screenfetch" \
        "$DEPS_CATEGORY_SYSTEM" \
        "Fetches system theme information" \
        "apt:screenfetch,snap:screenfetch,brew:screenfetch" \
        "3.9.0" \
        "screenfetch" \
        "system-info,theme-info,screenshot-info" \
        "System information and theme display for screenshots" \
        55 \
        "1MB"

    register_tool "hwinfo" \
        "$DEPS_CATEGORY_SYSTEM" \
        "Hardware information tool" \
        "apt:hwinfo,snap:hwinfo,brew:hwinfo" \
        "21.70.0" \
        "hwinfo" \
        "hardware-info,system-probing,device-info" \
        "Comprehensive hardware information and probing utility" \
        65 \
        "8MB"

    # Optional Tools (Category: optional)
    register_tool "docker" \
        "$DEPS_CATEGORY_OPTIONAL" \
        "Platform for developing, shipping, and running applications" \
        "apt:docker.io,snap:docker,brew:docker" \
        "20.10.0" \
        "docker" \
        "containers,virtualization,containerization" \
        "Industry-standard container platform for application development" \
        40 \
        "200MB"

    register_tool "podman" \
        "$DEPS_CATEGORY_OPTIONAL" \
        "Daemonless container engine" \
        "apt:podman,snap:podman,brew:podman" \
        "4.0.0" \
        "podman" \
        "containers,virtualization,containerization" \
        "Daemonless container engine for secure container management" \
        40 \
        "150MB"

    register_tool "lazydocker" \
        "$DEPS_CATEGORY_OPTIONAL" \
        "The lazier way to manage everything docker" \
        "apt:lazydocker,snap:lazydocker,brew:lazydocker" \
        "0.20.0" \
        "lazydocker" \
        "docker-management,docker-ui,containers" \
        "Intuitive terminal UI for docker and docker-compose management" \
        35 \
        "25MB"

    register_tool "fzf" \
        "$DEPS_CATEGORY_OPTIONAL" \
        "Command-line fuzzy finder" \
        "apt:fzf,snap:fzf,brew:fzf" \
        "0.40.0" \
        "fzf" \
        "fuzzy-finder,search,interactive-search" \
        "Powerful command-line fuzzy finder for interactive filtering" \
        75 \
        "6MB"

    log_deps_debug "Loaded $(($DEPS_TOOL_count - DEPS_REGISTRY_LOADED_COUNT)) built-in tools"
}

# Create default registry file
create_default_registry_file() {
    log_deps_info "Creating default dependency registry file: $DEPS_REGISTRY_FILE"

    ensure_dir "$(dirname "$DEPS_REGISTRY_FILE")"

    > "$DEPS_REGISTRY_FILE" cat << 'EOF'
# FUB Dependencies Registry
# This file contains the registry of all supported tools and their metadata

# Registry Format:
# name: Tool identifier
# category: core|enhanced|development|system|optional
# description: Human-readable description
# packages: Package manager mappings (manager:package_name,manager:package_name)
# min_version: Minimum required version
# executables: Command names to check for presence
# capabilities: Comma-separated list of capabilities
# benefit: User-facing benefit description
# priority: 1-100 (higher = more important)
# size: Estimated download size
# max_version: Maximum compatible version (optional)

# Core Tools
gum:
  category: core
  description: Interactive terminal UI for shell scripts
  packages: "apt:gum,snap:gum,brew:gum"
  min_version: "0.8.0"
  executables: "gum"
  capabilities: "interactive-ui,tui,dialogs,forms"
  benefit: "Enhanced interactive experiences with beautiful dialogs, forms, and menus"
  priority: 95
  size: "15MB"

btop:
  category: core
  description: Advanced system resource monitor
  packages: "apt:btop,snap:btop,brew:btop"
  min_version: "1.2.0"
  executables: "btop"
  capabilities: "monitoring,system-stats,resource-usage"
  benefit: "Beautiful real-time system monitoring with detailed resource usage"
  priority: 90
  size: "2MB"

# Enhanced Tools
dust:
  category: enhanced
  description: More intuitive version of du in rust
  packages: "apt:dust,snap:dust,brew:dust"
  min_version: "0.8.0"
  executables: "dust"
  capabilities: "disk-usage,du-alternative,storage-analysis"
  benefit: "Visual disk usage analysis with intuitive tree display"
  priority: 70
  size: "3MB"

# Development Tools
lazygit:
  category: development
  description: Simple terminal UI for git commands
  packages: "apt:lazygit,snap:lazygit,brew:lazygit"
  min_version: "0.35.0"
  executables: "lazygit"
  capabilities: "git,git-ui,version-control"
  benefit: "Intuitive git interface with visual commit history and branch management"
  priority: 85
  size: "20MB"

# System Tools
neofetch:
  category: system
  description: Fast, highly customizable system info script
  packages: "apt:neofetch,snap:neofetch,brew:neofetch"
  min_version: "7.1.0"
  executables: "neofetch"
  capabilities: "system-info,system-display,ascii-art"
  benefit: "Beautiful system information display with ASCII art logos"
  priority: 60
  size: "2MB"

# Optional Tools
fzf:
  category: optional
  description: Command-line fuzzy finder
  packages: "apt:fzf,snap:fzf,brew:fzf"
  min_version: "0.40.0"
  executables: "fzf"
  capabilities: "fuzzy-finder,search,interactive-search"
  benefit: "Powerful command-line fuzzy finder for interactive filtering"
  priority: 75
  size: "6MB"
EOF

    log_deps_info "Default dependency registry file created"
}

# Load registry from YAML file
load_registry_from_file() {
    local registry_file="$1"

    log_deps_debug "Loading dependency registry from file: $registry_file"

    if [[ ! -f "$registry_file" ]]; then
        log_deps_warn "Registry file not found: $registry_file"
        return 1
    fi

    local line_num=0
    local current_tool=""
    local current_tool_data=()

    while IFS= read -r line; do
        ((line_num++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Handle tool name (top-level key without indentation)
        if [[ "$line" =~ ^([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
            # Save previous tool if exists
            if [[ -n "$current_tool" ]]; then
                register_tool_from_data "$current_tool" "${current_tool_data[@]}"
            fi

            # Start new tool
            current_tool="${BASH_REMATCH[1]}"
            current_tool_data=()
            log_deps_debug "Found tool in registry: $current_tool"
            continue
        fi

        # Handle tool properties
        if [[ -n "$current_tool" ]] && [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9_-]+):[[:space:]]*(.*)[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Store property
            current_tool_data+=("$key:$value")
        fi
    done < "$registry_file"

    # Save last tool if exists
    if [[ -n "$current_tool" ]]; then
        register_tool_from_data "$current_tool" "${current_tool_data[@]}"
    fi

    log_deps_debug "Registry loaded from file: $registry_file"
}

# Register tool from parsed data
register_tool_from_data() {
    local tool_name="$1"
    shift
    local tool_data=("$@")

    local category=""
    local description=""
    local packages=""
    local min_version="0.0.0"
    local executables="$tool_name"
    local capabilities=""
    local benefit=""
    local priority="50"
    local size="unknown"
    local max_version=""

    # Parse tool data
    for data_item in "${tool_data[@]}"; do
        local key="${data_item%%:*}"
        local value="${data_item#*:}"

        case "$key" in
            category) category="$value" ;;
            description) description="$value" ;;
            packages) packages="$value" ;;
            min_version) min_version="$value" ;;
            executables) executables="$value" ;;
            capabilities) capabilities="$value" ;;
            benefit) benefit="$value" ;;
            priority) priority="$value" ;;
            size) size="$value" ;;
            max_version) max_version="$value" ;;
        esac
    done

    # Set defaults
    [[ -z "$category" ]] && category="$DEPS_CATEGORY_OPTIONAL"
    [[ -z "$description" ]] && description="Tool: $tool_name"

    # Register the tool
    register_tool "$tool_name" "$category" "$description" "$packages" "$min_version" \
                   "$executables" "$capabilities" "$benefit" "$priority" "$size" "$max_version"
}

# Get tools by category
get_tools_by_category() {
    local category="$1"
    list_tools_by_category "$category"
}

# Get tools by priority (threshold)
get_tools_by_priority() {
    local min_priority="$1"
    local tools=()

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local priority=$(get_tool_priority "$i")
        if [[ $priority -ge $min_priority ]]; then
            tools+=("$(get_tool_name "$i")")
        fi
    done

    printf '%s\n' "${tools[@]}"
}

# Get tool metadata
get_tool_metadata() {
    local tool_name="$1"
    local tool_index=$(find_tool_index "$tool_name")

    if [[ $tool_index -lt 0 ]]; then
        log_deps_error "Tool not found in registry: $tool_name"
        return 1
    fi

    echo "name:$(get_tool_name "$tool_index")"
    echo "category:$(get_tool_category "$tool_index")"
    echo "description:$(get_tool_description "$tool_index")"
    echo "packages:$(get_tool_package_names "$tool_index")"
    echo "min_version:$(get_tool_min_version "$tool_index")"
    echo "max_version:$(get_tool_max_version "$tool_index")"
    echo "executables:$(get_tool_executables "$tool_index")"
    echo "capabilities:$(get_tool_capabilities "$tool_index")"
    echo "benefit:$(get_tool_benefit "$tool_index")"
    echo "priority:$(get_tool_priority "$tool_index")"
    echo "size:$(get_tool_size "$tool_index")"
}

# Check if tool exists in registry
tool_exists() {
    local tool_name="$1"
    local tool_index=$(find_tool_index "$tool_name")
    [[ $tool_index -ge 0 ]]
}

# Get all tool categories
get_tool_categories() {
    local categories=()

    for category in "$DEPS_CATEGORY_CORE" "$DEPS_CATEGORY_ENHANCED" "$DEPS_CATEGORY_DEVELOPMENT" "$DEPS_CATEGORY_SYSTEM" "$DEPS_CATEGORY_OPTIONAL"; do
        local tools_in_category
        tools_in_category=$(list_tools_by_category "$category")
        if [[ -n "$tools_in_category" ]]; then
            categories+=("$category")
        fi
    done

    printf '%s\n' "${categories[@]}"
}

# Show registry information
show_registry_info() {
    local section="${1:-overview}"

    echo ""
    echo "${BOLD}${CYAN}FUB Dependencies Registry${RESET}"
    echo "==========================="
    echo ""

    case "$section" in
        overview)
            echo "${YELLOW}Registry Overview:${RESET}"
            echo "  Total tools: $DEPS_REGISTRY_LOADED_COUNT"
            echo "  Registry file: $DEPS_REGISTRY_FILE"
            echo "  Loaded: $( [[ $DEPS_REGISTRY_LOADED == true ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"
            echo ""

            # Show tools by category
            local categories
            categories=$(get_tool_categories)
            for category in $categories; do
                local tools_in_category
                tools_in_category=$(list_tools_by_category "$category")
                local tool_count
                tool_count=$(echo "$tools_in_category" | wc -l)
                echo "  ${GREEN}${category^}${RESET}: $tool_count tools"
            done
            ;;
        categories)
            echo "${YELLOW}Tool Categories:${RESET}"
            echo ""

            local categories
            categories=$(get_tool_categories)
            for category in $categories; do
                echo "${BOLD}${category^}${RESET}"
                local tools_in_category
                tools_in_category=$(list_tools_by_category "$category")
                echo "$tools_in_category" | sed 's/^/  /'
                echo ""
            done
            ;;
        all)
            echo "${YELLOW}All Registered Tools:${RESET}"
            echo ""

            for ((i=0; i<DEPS_TOOL_count; i++)); do
                local name=$(get_tool_name "$i")
                local category=$(get_tool_category "$i")
                local priority=$(get_tool_priority "$i")
                local size=$(get_tool_size "$i")
                local priority_formatted=$(format_priority "$priority")

                printf "${GREEN}%-20s${RESET} ${CYAN}%-10s${RESET} ${YELLOW}%-8s${RESET} ${GRAY}%-8s${RESET}\n" \
                       "$name" "$category" "$priority_formatted" "$size"
            done
            ;;
        *)
            log_deps_error "Unknown registry section: $section"
            return 1
            ;;
    esac

    echo ""
}

# Search tools by name or description
search_tools() {
    local query="$1"
    local results=()

    # Convert query to lowercase for case-insensitive search
    local query_lower=$(lowercase "$query")

    for ((i=0; i<DEPS_TOOL_count; i++)); do
        local name=$(get_tool_name "$i")
        local name_lower=$(lowercase "$name")
        local description=$(get_tool_description "$i")
        local description_lower=$(lowercase "$description")
        local capabilities=$(get_tool_capabilities "$i")
        local capabilities_lower=$(lowercase "$capabilities")

        if [[ "$name_lower" == *"$query_lower"* ]] || \
           [[ "$description_lower" == *"$query_lower"* ]] || \
           [[ "$capabilities_lower" == *"$query_lower"* ]]; then
            results+=("$name")
        fi
    done

    printf '%s\n' "${results[@]}"
}

# Export functions
export -f init_deps_registry load_builtin_tools create_default_registry_file
export -f load_registry_from_file register_tool_from_data get_tools_by_category
export -f get_tools_by_priority get_tool_metadata tool_exists get_tool_categories
export -f show_registry_info search_tools

log_deps_debug "Dependency registry system loaded"