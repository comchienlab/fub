#!/usr/bin/env bash

# FUB Dependencies Alternative Implementations
# Provides alternative implementations for missing tools with similar functionality

set -euo pipefail

# Source dependencies and common utilities
DEPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUB_ROOT_DIR="$(cd "${DEPS_SCRIPT_DIR}/../.." && pwd)"
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/dependencies/core/dependencies.sh"

# Alternative implementations registry
declare -A TOOL_ALTERNATIVES
declare -A ALTERNATIVE_FUNCTIONS

# Initialize alternative system
init_alternatives_system() {
    log_deps_debug "Initializing alternative implementations system..."

    # Define tool alternatives
    define_tool_alternatives

    # Create alternative functions
    create_alternative_functions

    log_deps_debug "Alternative implementations system initialized"
}

# Define tool alternatives
define_tool_alternatives() {
    # Define primary tools and their alternatives
    TOOL_ALTERNATIVES=(
        # Interactive UI alternatives
        ["gum"]="dialog,whiptail"

        # Monitoring alternatives
        ["btop"]="htop,top,glances"
        ["htop"]="top,ps aux"

        # File search alternatives
        ["fd"]="find"
        ["find"]="fd"
        ["ripgrep"]="grep,ag"
        ["grep"]="ripgrep,ag"
        ["ag"]="ripgrep,grep"

        # Storage analysis alternatives
        ["dust"]="du,ncdu"
        ["duf"]="df,dust"
        ["ncdu"]="dust,du"

        # File viewing alternatives
        ["bat"]="cat,less,more"
        ["cat"]="bat,less"
        ["less"]="bat,cat,more"
        ["exa"]="ls,tree"
        ["ls"]="exa,tree"
        ["tree"]="exa,ls -R"

        # Process management alternatives
        ["procs"]="ps,htop,top"
        ["ps"]="procs,htop"

        # Git alternatives
        ["lazygit"]="tig,git"
        ["tig"]="lazygit,git"

        # System info alternatives
        ["neofetch"]="screenfetch,uname -a"
        ["screenfetch"]="neofetch,uname -a"

        # Container alternatives
        ["lazydocker"]="docker,podman"
        ["docker"]="podman,lazydocker"
        ["podman"]="docker,lazydocker"

        # Fuzzy finding alternatives
        ["fzf"]="select-menu,pep"
        ["select-menu"]="fzf"
    )

    log_deps_debug "Defined alternatives for ${#TOOL_ALTERNATIVES[@]} tools"
}

# Create alternative functions
create_alternative_functions() {
    log_deps_debug "Creating alternative functions..."

    # Create enhanced alternatives for common tools

    # Enhanced cat (bat alternative)
    if ! command_exists bat; then
        create_bat_alternative
    fi

    # Enhanced ls (exa alternative)
    if ! command_exists exa; then
        create_exa_alternative
    fi

    # Enhanced find (fd alternative)
    if ! command_exists fd; then
        create_fd_alternative
    fi

    # Enhanced grep (ripgrep alternative)
    if ! command_exists rg; then
        create_ripgrep_alternative
    fi

    # Enhanced du (dust alternative)
    if ! command_exists dust; then
        create_dust_alternative
    fi

    # Enhanced df (duf alternative)
    if ! command_exists duf; then
        create_duf_alternative
    fi

    # Enhanced git UI (lazygit alternative)
    if ! command_exists lazygit; then
        create_lazygit_alternative
    fi

    log_deps_debug "Alternative functions created"
}

# Create bat alternative
create_bat_alternative() {
    log_deps_debug "Creating bat alternative"

    bat() {
        local file="$1"
        local line_numbers=false
        local show_nonprinting=false

        # Parse simple options
        while [[ $# -gt 1 ]]; do
            case "$1" in
                "-n"|"--number")
                    line_numbers=true
                    shift
                    ;;
                "-A"|"--show-all")
                    show_nonprinting=true
                    shift
                    ;;
                *)
                    file="$1"
                    shift
                    ;;
            esac
        done

        if [[ ! -f "$file" ]]; then
            echo "${RED}Error: File not found: $file${RESET}" >&2
            return 1
        fi

        # Determine file type for syntax highlighting (basic)
        local extension="${file##*.}"
        local use_color=false

        case "$extension" in
            "sh"|"bash") use_color=true ;;
            "py") use_color=true ;;
            "js"|"json") use_color=true ;;
            "css"|"html") use_color=true ;;
            "yaml"|"yml") use_color=true ;;
            "md") use_color=true ;;
        esac

        # Display file with basic formatting
        if [[ "$use_color" == "true" ]] && command_exists pygmentize; then
            if [[ "$line_numbers" == "true" ]]; then
                nl -ba "$file" | pygmentize -l "$extension"
            else
                pygmentize -l "$extension" "$file"
            fi
        else
            if [[ "$line_numbers" == "true" ]]; then
                nl -ba "$file"
            else
                cat "$file"
            fi
        fi
    }

    export -f bat
}

# Create exa alternative
create_exa_alternative() {
    log_deps_debug "Creating exa alternative"

    exa() {
        local show_all=false
        local show_long=false
        local show_tree=false
        local path="."

        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                "-a"|"--all")
                    show_all=true
                    shift
                    ;;
                "-l"|"--long")
                    show_long=true
                    shift
                    ;;
                "-T"|"--tree")
                    show_tree=true
                    shift
                    ;;
                "-la"|"-al")
                    show_all=true
                    show_long=true
                    shift
                    ;;
                *)
                    if [[ "$1" != "-"* ]]; then
                        path="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Build ls command
        local ls_cmd="ls"

        if supports_colors; then
            ls_cmd="$ls_cmd --color=auto"
        fi

        if [[ "$show_all" == "true" ]]; then
            ls_cmd="$ls_cmd -A"
        fi

        if [[ "$show_long" == "true" ]]; then
            ls_cmd="$ls_cmd -l"
            # Add human-readable sizes
            if ls --help 2>/dev/null | grep -q human-readable; then
                ls_cmd="$ls_cmd -h"
            fi
        fi

        if [[ "$show_tree" == "true" ]]; then
            if command_exists tree; then
                tree "$path"
            else
                echo "${YELLOW}tree not available, using ls -R${RESET}"
                ls -laR "$path"
            fi
        else
            eval "$ls_cmd \"$path\""
        fi
    }

    export -f exa
}

# Create fd alternative
create_fd_alternative() {
    log_deps_debug "Creating fd alternative"

    fd() {
        local pattern="."
        local path="."
        local show_hidden=false
        local case_sensitive=true
        local file_type=""

        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                "-H"|"--hidden")
                    show_hidden=true
                    shift
                    ;;
                "-i"|"--ignore-case")
                    case_sensitive=false
                    shift
                    ;;
                "-t"|"--type")
                    file_type="$2"
                    shift 2
                    ;;
                "-e"|"--extension")
                    pattern="*.$2"
                    shift 2
                    ;;
                *)
                    if [[ "$1" != "-"* && "$pattern" == "." ]]; then
                        pattern="*$1*"
                    elif [[ "$1" != "-"* ]]; then
                        path="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Build find command
        local find_cmd="find \"$path\""

        if [[ "$show_hidden" != "true" ]]; then
            find_cmd="$find_cmd -name \".*\" -prune -o"
        fi

        find_cmd="$find_cmd -name \"$pattern\" -print"

        # Add file type filter
        case "$file_type" in
            "f"|"file")
                find_cmd="$find_cmd -type f"
                ;;
            "d"|"dir"|"directory")
                find_cmd="$find_cmd -type d"
                ;;
        esac

        # Case sensitivity
        if [[ "$case_sensitive" != "true" ]]; then
            find_cmd="$find_cmd -iname \"$pattern\""
        fi

        # Execute command
        eval "$find_cmd" 2>/dev/null
    }

    export -f fd
}

# Create ripgrep alternative
create_ripgrep_alternative() {
    log_deps_debug "Creating ripgrep alternative"

    rg() {
        local pattern="$1"
        local path="."
        local case_sensitive=true
        local show_line_numbers=true
        local only_matching=false

        shift

        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                "-i"|"--ignore-case")
                    case_sensitive=false
                    shift
                    ;;
                "-n"|"--line-number")
                    show_line_numbers=true
                    shift
                    ;;
                "-o"|"--only-matching")
                    only_matching=true
                    shift
                    ;;
                *)
                    if [[ "$1" != "-"* ]]; then
                        path="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Build grep command
        local grep_cmd="grep"

        if [[ "$case_sensitive" != "true" ]]; then
            grep_cmd="$grep_cmd -i"
        fi

        if [[ "$show_line_numbers" == "true" ]]; then
            grep_cmd="$grep_cmd -n"
        fi

        if supports_colors; then
            grep_cmd="$grep_cmd --color=auto"
        fi

        # Add pattern and path
        grep_cmd="$grep_cmd -r \"$pattern\" \"$path\""

        # Execute command
        eval "$grep_cmd" 2>/dev/null
    }

    export -f rg
}

# Create dust alternative
create_dust_alternative() {
    log_deps_debug "Creating dust alternative"

    dust() {
        local path="."
        local max_depth=5
        local reverse_sort=false

        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                "-d"|"--depth")
                    max_depth="$2"
                    shift 2
                    ;;
                "-r"|"--reverse")
                    reverse_sort=true
                    shift
                    ;;
                *)
                    if [[ "$1" != "-"* ]]; then
                        path="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Use du with sorting
        local du_cmd="du -sh \"$path\"/* 2>/dev/null"

        if [[ "$reverse_sort" == "true" ]]; then
            du_cmd="$du_cmd | sort -hr"
        else
            du_cmd="$du_cmd | sort -h"
        fi

        # Limit results if depth is specified
        if [[ "$max_depth" -gt 0 ]]; then
            du_cmd="$du_cmd | head -20"
        fi

        # Execute with header
        echo "${YELLOW}Disk usage for $path (fallback implementation):${RESET}"
        eval "$du_cmd"
    }

    export -f dust
}

# Create duf alternative
create_duf_alternative() {
    log_deps_debug "Creating duf alternative"

    duf() {
        echo "${YELLOW}Disk usage (fallback implementation):${RESET}"
        echo ""

        if command_exists df; then
            if supports_colors; then
                df -h | grep -E '^/dev/' | head -10
            else
                df -h | grep -E '^/dev/' | head -10
            fi
        else
            echo "${RED}df command not available${RESET}"
        fi
    }

    export -f duf
}

# Create lazygit alternative
create_lazygit_alternative() {
    log_deps_debug "Creating lazygit alternative"

    lazygit() {
        echo "${YELLOW}LazyGit alternative - Basic git interface:${RESET}"
        echo ""

        if ! git rev-parse --git-dir >/dev/null 2>&1; then
            echo "${RED}Not a git repository${RESET}"
            echo "${GRAY}Run 'git init' to create a repository${RESET}"
            return 1
        fi

        # Show current status
        echo "${CYAN}Git Status:${RESET}"
        git status --porcelain
        echo ""

        # Show recent commits
        echo "${CYAN}Recent Commits:${RESET}"
        git log --oneline -5
        echo ""

        # Show branches
        echo "${CYAN}Branches:${RESET}"
        git branch -a
        echo ""

        # Interactive menu
        echo "${YELLOW}Available Actions:${RESET}"
        echo "  1) Show detailed status"
        echo "  2) Add all changes"
        echo "  3) Commit changes"
        echo "  4) Push changes"
        echo "  5) Pull changes"
        echo "  6) Show log"
        echo "  7) Exit"

        if [[ -t 0 ]]; then
            echo -n "${CYAN}Choose action (1-7):${RESET} "
            read -r choice

            case "$choice" in
                1)
                    echo ""
                    git status
                    ;;
                2)
                    echo ""
                    git add .
                    echo "${GREEN}All changes added${RESET}"
                    ;;
                3)
                    echo ""
                    echo -n "${YELLOW}Commit message:${RESET} "
                    read -r message
                    git commit -m "$message"
                    ;;
                4)
                    echo ""
                    git push
                    ;;
                5)
                    echo ""
                    git pull
                    ;;
                6)
                    echo ""
                    git log --oneline -10
                    ;;
                *)
                    echo "Exiting..."
                    ;;
            esac
        fi
    }

    export -f lazygit
}

# Get alternative for a tool
get_alternative() {
    local tool="$1"

    local alternatives="${TOOL_ALTERNATIVES[$tool]:-}"
    if [[ -n "$alternatives" ]]; then
        # Return the first available alternative
        IFS=',' read -ra alt_list <<< "$alternatives"
        for alt in "${alt_list[@]}"; do
            alt=$(trim "$alt")
            if command_exists "$alt"; then
                echo "$alt"
                return 0
            fi
        done
    fi

    return 1
}

# Check if alternative is available
has_alternative() {
    local tool="$1"

    local alternatives="${TOOL_ALTERNATIVES[$tool]:-}"
    if [[ -n "$alternatives" ]]; then
        IFS=',' read -ra alt_list <<< "$alternatives"
        for alt in "${alt_list[@]}"; do
            alt=$(trim "$alt")
            if command_exists "$alt"; then
                return 0
            fi
        done
    fi

    return 1
}

# Show tool alternatives
show_tool_alternatives() {
    local tool="$1"

    if tool_exists "$tool"; then
        echo "${GREEN}✓ $tool is installed${RESET}"
    else
        echo "${RED}✗ $tool is not installed${RESET}"

        local alternatives="${TOOL_ALTERNATIVES[$tool]:-}"
        if [[ -n "$alternatives" ]]; then
            echo "${YELLOW}Alternatives:${RESET}"
            IFS=',' read -ra alt_list <<< "$alternatives"
            for alt in "${alt_list[@]}"; do
                alt=$(trim "$alt")
                if command_exists "$alt"; then
                    echo "  ${GREEN}✓${RESET} $alt (available)"
                else
                    echo "  ${GRAY}✗${RESET} $alt (not available)"
                fi
            done
        else
            echo "${GRAY}No alternatives available${RESET}"
        fi
    fi
}

# Show all alternatives status
show_alternatives_status() {
    echo ""
    echo "${BOLD}${CYAN}Tool Alternatives Status${RESET}"
    echo "==========================="
    echo ""

    for tool in "${!TOOL_ALTERNATIVES[@]}"; do
        show_tool_alternatives "$tool"
        echo ""
    done
}

# Export functions
export -f init_alternatives_system define_tool_alternatives create_alternative_functions
export -f create_bat_alternative create_exa_alternative create_fd_alternative
export -f create_ripgrep_alternative create_dust_alternative create_duf_alternative
export -f create_lazygit_alternative get_alternative has_alternative
export -f show_tool_alternatives show_alternatives_status

log_deps_debug "Alternative implementations system loaded"