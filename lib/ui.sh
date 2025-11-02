#!/usr/bin/env bash

# FUB UI/Interaction Helpers
# Provides user interface components and interaction utilities

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/theme.sh"
fi

# UI constants
[[ -z "${FUB_INDENT:-}" ]] && readonly FUB_INDENT="    "
[[ -z "${FUB_PROGRESS_BAR_WIDTH:-}" ]] && readonly FUB_PROGRESS_BAR_WIDTH=40
[[ -z "${FUB_SPINNER_CHARS:-}" ]] && readonly FUB_SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# UI state
FUB_QUIET_MODE=false
FUB_VERBOSE_MODE=false
FUB_INTERACTIVE_MODE=true
FUB_SHOW_PROGRESS=true

# Initialize UI system
init_ui() {
    local interactive="${1:-true}"
    local quiet="${2:-false}"
    local verbose="${3:-false}"

    FUB_INTERACTIVE_MODE="$interactive"
    FUB_QUIET_MODE="$quiet"
    FUB_VERBOSE_MODE="$verbose"

    log_debug "UI system initialized (interactive: $interactive, quiet: $quiet, verbose: $verbose)"

    # Ensure colors are available
    if ! supports_colors; then
        log_debug "Terminal does not support colors, disabling them"
        FUB_QUIET_MODE=true
    fi
}

# Print header
print_header() {
    local title="$1"
    local subtitle="${2:-}"

    echo ""
    if supports_colors; then
        echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        printf "${BOLD}${CYAN}║%*s║${RESET}\n" 72 " "
        printf "${BOLD}${CYAN}║%s%*s║${RESET}\n" "$(( (72 - ${#title}) / 2 ))" "$title" "$(( (72 - ${#title}) / 2 ))" " "
        printf "${BOLD}${CYAN}║%*s║${RESET}\n" 72 " "
        echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    else
        echo "===================================================================="
        printf "%*s\n" $(( (72 - ${#title}) / 2 )) "$title"
        echo "===================================================================="
    fi

    if [[ -n "$subtitle" ]]; then
        echo ""
        if supports_colors; then
            echo "${ITALIC}${GRAY}$subtitle${RESET}"
        else
            echo "$subtitle"
        fi
    fi
    echo ""
}

# Print section header
print_section() {
    local title="$1"

    echo ""
    if supports_colors; then
        echo "${BOLD}${YELLOW}$title${RESET}"
        echo "${GRAY}$(printf '─%.0s' $(seq 1 ${#title}))${RESET}"
    else
        echo "$title"
        echo "$(printf '─%.0s' $(seq 1 ${#title}))"
    fi
    echo ""
}

# Print success message
print_success() {
    local message="$*"

    if [[ "$FUB_QUIET_MODE" != true ]]; then
        if supports_colors; then
            echo "${BOLD}${GREEN}✓${RESET} $message"
        else
            echo "✓ $message"
        fi
    fi
    log_info "SUCCESS: $message"
}

# Print error message
print_error() {
    local message="$*"

    if supports_colors; then
        echo "${BOLD}${RED}✗${RESET} ${BOLD}ERROR:${RESET} $message" >&2
    else
        echo "✗ ERROR: $message" >&2
    fi
    log_error "ERROR: $message"
}

# Print warning message
print_warning() {
    local message="$*"

    if [[ "$FUB_QUIET_MODE" != true ]]; then
        if supports_colors; then
            echo "${BOLD}${YELLOW}⚠${RESET} ${BOLD}WARNING:${RESET} $message"
        else
            echo "⚠ WARNING: $message"
        fi
    fi
    log_warn "WARNING: $message"
}

# Print info message
print_info() {
    local message="$*"

    if [[ "$FUB_QUIET_MODE" != true ]]; then
        if supports_colors; then
            echo "${BOLD}${BLUE}ℹ${RESET} $message"
        else
            echo "ℹ $message"
        fi
    fi
    log_info "INFO: $message"
}

# Print debug message
print_debug() {
    local message="$*"

    if [[ "$FUB_VERBOSE_MODE" == true ]] && [[ "$FUB_QUIET_MODE" != true ]]; then
        if supports_colors; then
            echo "${DIM}${GRAY}DEBUG:${RESET} $message"
        else
            echo "DEBUG: $message"
        fi
    fi
    log_debug "DEBUG: $message"
}

# Print step/progress message
print_step() {
    local step="$1"
    local total="$2"
    local message="$3"

    if [[ "$FUB_QUIET_MODE" != true ]]; then
        if supports_colors; then
            printf "${BOLD}[%d/%d]${RESET} %s\n" "$step" "$total" "$message"
        else
            printf "[%d/%d] %s\n" "$step" "$total" "$message"
        fi
    fi
}

# Print indented message
print_indented() {
    local level="${1:-1}"
    shift
    local message="$*"

    local indent=""
    for ((i=0; i<level; i++)); do
        indent+="$FUB_INDENT"
    done

    echo "${indent}$message"
}

# Print bullet point
print_bullet() {
    local message="$*"
    local bullet="${1:-•}"

    if supports_colors; then
        echo "${CYAN}${bullet}${RESET} $message"
    else
        echo "${bullet} $message"
    fi
}

# Print numbered item
print_numbered() {
    local number="$1"
    shift
    local message="$*"

    if supports_colors; then
        printf "${BOLD}%d.${RESET} %s\n" "$number" "$message"
    else
        printf "%d. %s\n" "$number" "$message"
    fi
}

# Print table
print_table() {
    local -n rows_ref=$1
    local headers=("${!2}")
    local separator="${3:-|}"

    if [[ ${#rows_ref[@]} -eq 0 ]]; then
        print_warning "No data to display"
        return
    fi

    # Calculate column widths
    local -a col_widths
    local num_cols=${#headers[@]}

    # Initialize with header widths
    for ((i=0; i<num_cols; i++)); do
        col_widths[$i]=${#headers[$i]}
    done

    # Find maximum width for each column
    for row in "${rows_ref[@]}"; do
        local -a cols=($row)
        for ((i=0; i<${#cols[@]} && i<num_cols; i++)); do
            local len=${#cols[$i]}
            if [[ $len -gt ${col_widths[$i]} ]]; then
                col_widths[$i]=$len
            fi
        done
    done

    # Print header
    echo ""
    local header_line=""
    for ((i=0; i<num_cols; i++)); do
        local width=${col_widths[$i]}
        local header="${headers[$i]}"
        printf -v header_line "%s %-${width}s" "$header_line" "$header"
        if [[ $i -lt $((num_cols - 1)) ]]; then
            header_line+=" $separator "
        fi
    done

    if supports_colors; then
        echo "${BOLD}${UNDERLINE}${CYAN}$header_line${RESET}"
    else
        echo "$header_line"
    fi

    # Print separator
    local sep_line=""
    for ((i=0; i<num_cols; i++)); do
        local width=${col_widths[$i]}
        printf -v sep_line "%s %s" "$sep_line" "$(printf '%.0s-' $(seq 1 $width))"
        if [[ $i -lt $((num_cols - 1)) ]]; then
            sep_line+=" $separator "
        fi
    done
    echo "$sep_line"

    # Print rows
    for row in "${rows_ref[@]}"; do
        local -a cols=($row)
        local row_line=""
        for ((i=0; i<${#cols[@]} && i<num_cols; i++)); do
            local width=${col_widths[$i]}
            local cell="${cols[$i]}"
            printf -v row_line "%s %-${width}s" "$row_line" "$cell"
            if [[ $i -lt $((num_cols - 1)) ]]; then
                row_line+=" $separator "
            fi
        done
        echo "$row_line"
    done
    echo ""
}

# Progress bar functions
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing...}"
    local width="${4:-$FUB_PROGRESS_BAR_WIDTH}"

    if [[ "$FUB_SHOW_PROGRESS" != true ]] || [[ "$FUB_QUIET_MODE" == true ]]; then
        return
    fi

    local percentage=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    # Build progress bar
    local bar="["
    bar+="$(printf '%0.s█' $(seq 1 $filled))"
    bar+="$(printf '%0.s░' $(seq 1 $empty))"
    bar+="]"

    # Print progress
    printf "\r${BOLD}${BLUE}$message${RESET} %3d%% %s" "$percentage" "$bar"

    # Complete if finished
    if [[ $current -ge $total ]]; then
        echo ""
    fi
}

# Spinner for long operations
show_spinner() {
    local message="$1"
    local pid="$2"
    local delay="${3:-0.1}"

    if [[ "$FUB_QUIET_MODE" == true ]]; then
        return
    fi

    local spin_index=0
    while kill -0 "$pid" 2>/dev/null; do
        local spin_char="${FUB_SPINNER_CHARS[$spin_index]}"
        printf "\r${BOLD}${BLUE}$message${RESET} ${spin_char}"
        sleep "$delay"
        spin_index=$(( (spin_index + 1) % ${#FUB_SPINNER_CHARS[@]} ))
    done

    # Clear spinner line
    printf "\r%*s\r" 80 ""
}

# Interactive prompt functions
ask_question() {
    local question="$1"
    local default="${2:-}"

    if [[ "$FUB_INTERACTIVE_MODE" != true ]]; then
        echo "$default"
        return 0
    fi

    local prompt="$question"
    if [[ -n "$default" ]]; then
        prompt+=" [$default]"
    fi
    prompt+=": "

    if supports_colors; then
        prompt="${BOLD}${YELLOW}$prompt${RESET}"
    fi

    local answer
    read -p "$prompt" answer
    echo "${answer:-$default}"
}

# Ask yes/no question
ask_confirmation() {
    local question="$1"
    local default="${2:-n}"

    if [[ "$FUB_INTERACTIVE_MODE" != true ]]; then
        # Default to 'no' in non-interactive mode
        [[ "$default" =~ ^[Yy] ]] && return 0 || return 1
    fi

    local prompt="$question"
    if [[ "$default" =~ ^[Yy] ]]; then
        prompt+=" [Y/n]"
    else
        prompt+=" [y/N]"
    fi

    if supports_colors; then
        prompt="${BOLD}${YELLOW}$prompt${RESET}"
    else
        prompt="$prompt"
    fi

    local answer
    while true; do
        read -p "$prompt " answer
        answer="${answer:-$default}"

        case "$answer" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                if supports_colors; then
                    echo "${RED}Please answer yes or no.${RESET}"
                else
                    echo "Please answer yes or no."
                fi
                ;;
        esac
    done
}

# Ask for password (without echo)
ask_password() {
    local prompt="${1:-Enter password: }"

    if [[ "$FUB_INTERACTIVE_MODE" != true ]]; then
        echo ""
        log_error "Password required in non-interactive mode"
        return 1
    fi

    if supports_colors; then
        prompt="${BOLD}${YELLOW}$prompt${RESET}"
    fi

    local password
    read -s -p "$prompt" password
    echo ""
    echo "$password"
}

# Select from menu
select_menu() {
    local -n options_ref=$1
    local title="${2:-Select an option}"
    local default="${3:-1}"

    if [[ "$FUB_INTERACTIVE_MODE" != true ]]; then
        echo "${options_ref[$default]}"
        return "$default"
    fi

    if [[ ${#options_ref[@]} -eq 0 ]]; then
        log_error "No options available"
        return 1
    fi

    while true; do
        echo ""
        if supports_colors; then
            echo "${BOLD}${CYAN}$title${RESET}"
        else
            echo "$title"
        fi

        for i in "${!options_ref[@]}"; do
            local option="${options_ref[$i]}"
            local marker=" "
            if [[ $((i + 1)) -eq $default ]]; then
                marker="*"
            fi
            printf "  %s%d) %s\n" "$marker" "$((i + 1))" "$option"
        done

        echo ""
        local selection
        read -p "Enter choice (1-${#options_ref[@]}): " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#options_ref[@]} ]]; then
            echo "${options_ref[$((selection - 1))]}"
            return $((selection - 1))
        else
            if supports_colors; then
                echo "${RED}Invalid selection. Please try again.${RESET}"
            else
                echo "Invalid selection. Please try again."
            fi
        fi
    done
}

# Multi-select menu
select_multiple() {
    local -n options_ref=$1
    local title="${2:-Select options}"
    local -n defaults_ref=$3

    if [[ "$FUB_INTERACTIVE_MODE" != true ]]; then
        # Return defaults in non-interactive mode
        printf '%s\n' "${defaults_ref[@]}"
        return 0
    fi

    local -a selected=()
    local -a selected_indices=()

    # Initialize with defaults
    for default in "${defaults_ref[@]}"; do
        for i in "${!options_ref[@]}"; do
            if [[ "${options_ref[$i]}" == "$default" ]]; then
                selected+=("${options_ref[$i]}")
                selected_indices+=("$i")
                break
            fi
        done
    done

    while true; do
        echo ""
        if supports_colors; then
            echo "${BOLD}${CYAN}$title${RESET}"
            echo "${GRAY}(Space to toggle, Enter to confirm)${RESET}"
        else
            echo "$title"
            echo "(Space to toggle, Enter to confirm)"
        fi

        for i in "${!options_ref[@]}"; do
            local option="${options_ref[$i]}"
            local marker=" "

            if [[ " ${selected_indices[*]} " =~ " $i " ]]; then
                marker="${GREEN}✓${RESET}"
            else
                marker=" "
            fi

            if supports_colors; then
                printf "  [%s] %s\n" "$marker" "$option"
            else
                printf "  [%s] %s\n" "$([[ " ${selected_indices[*]} " =~ " $i " ]] && echo "✓" || echo " ")" "$option"
            fi
        done

        echo ""
        read -p "Your selection: " -n 1 -r choice
        echo ""

        case "$choice" in
            "")
                # Enter - confirm selection
                printf '%s\n' "${selected[@]}"
                return 0
                ;;
            [0-9]*)
                # Number selection
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#options_ref[@]} ]]; then
                    local index=$((choice - 1))
                    if [[ " ${selected_indices[*]} " =~ " $index " ]]; then
                        # Remove from selection
                        selected_indices=($(printf '%s\n' "${selected_indices[@]}" | grep -v "^$index$"))
                        selected=()
                        for idx in "${selected_indices[@]}"; do
                            selected+=("${options_ref[$idx]}")
                        done
                    else
                        # Add to selection
                        selected_indices+=("$index")
                        selected+=("${options_ref[$index]}")
                    fi
                fi
                ;;
        esac
    done
}

# File selection dialog
select_file() {
    local directory="${1:-.}"
    local pattern="${2:-*}"
    local title="${3:-Select a file}"

    if [[ ! -d "$directory" ]]; then
        log_error "Directory not found: $directory"
        return 1
    fi

    local -a files=()
    while IFS= read -r -d '' file; do
        files+=("$(basename "$file")")
    done < <(find "$directory" -maxdepth 1 -name "$pattern" -type f -print0 | sort -z)

    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "No files found matching pattern: $pattern"
        return 1
    fi

    local selected_file
    selected_file=$(select_menu files "$title")

    echo "$directory/$selected_file"
}

# Input validation functions
validate_input() {
    local input="$1"
    local validation_type="$2"
    local pattern="$3"

    case "$validation_type" in
        email)
            validate_email "$input"
            ;;
        url)
            validate_url "$input"
            ;;
        number)
            [[ "$input" =~ ^[0-9]+$ ]]
            ;;
        port)
            validate_port "$input"
            ;;
        pattern)
            [[ "$input" =~ $pattern ]]
            ;;
        *)
            log_error "Unknown validation type: $validation_type"
            return 1
            ;;
    esac
}

# Get validated input
get_validated_input() {
    local prompt="$1"
    local validation_type="$2"
    local pattern="${3:-}"
    local default="${4:-}"
    local error_message="${5:-Invalid input. Please try again.}"

    while true; do
        local input
        input=$(ask_question "$prompt" "$default")

        # Skip validation if empty and default is provided
        if [[ -z "$input" ]] && [[ -n "$default" ]]; then
            echo "$default"
            return 0
        fi

        if validate_input "$input" "$validation_type" "$pattern"; then
            echo "$input"
            return 0
        else
            print_error "$error_message"
        fi
    done
}

# Status message formatting
format_status() {
    local status="$1"
    local message="$2"

    case "$status" in
        success|ok|done)
            if supports_colors; then
                echo "${BOLD}${GREEN}✓${RESET} $message"
            else
                echo "✓ $message"
            fi
            ;;
        error|fail|failed)
            if supports_colors; then
                echo "${BOLD}${RED}✗${RESET} $message"
            else
                echo "✗ $message"
            fi
            ;;
        warning|warn)
            if supports_colors; then
                echo "${BOLD}${YELLOW}⚠${RESET} $message"
            else
                echo "⚠ $message"
            fi
            ;;
        info|notice)
            if supports_colors; then
                echo "${BOLD}${BLUE}ℹ${RESET} $message"
            else
                echo "ℹ $message"
            fi
            ;;
        loading|progress)
            if supports_colors; then
                echo "${BOLD}${CYAN}⏳${RESET} $message"
            else
                echo "⏳ $message"
            fi
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Box drawing for UI elements
print_box() {
    local title="$1"
    local content="$2"
    local width="${3:-60}"

    local border_line="┌"
    border_line+="$(printf '─%.0s' $(seq 1 $((width - 2))))"
    border_line+="┐"

    local title_line="│"
    local title_padding=$(( (width - ${#title} - 2) / 2 ))
    title_line+="$(printf ' %.0s' $(seq 1 $title_padding))"
    title_line+="$title"
    title_line+="$(printf ' %.0s' $(seq 1 $((width - ${#title} - title_padding - 2))))"
    title_line+="│"

    local content_line="│ $content"
    local content_padding=$(( width - ${#content} - 3 ))
    content_line+="$(printf ' %.0s' $(seq 1 $content_padding))"
    content_line+="│"

    local bottom_line="└"
    bottom_line+="$(printf '─%.0s' $(seq 1 $((width - 2))))"
    bottom_line+="┘"

    echo ""
    if supports_colors; then
        echo "${CYAN}$border_line${RESET}"
        echo "${CYAN}$title_line${RESET}"
        echo "${CYAN}$content_line${RESET}"
        echo "${CYAN}$bottom_line${RESET}"
    else
        echo "$border_line"
        echo "$title_line"
        echo "$content_line"
        echo "$bottom_line"
    fi
    echo ""
}

# Display system status
display_system_status() {
    local -a status_items=("$@")

    echo ""
    if supports_colors; then
        echo "${BOLD}${CYAN}System Status${RESET}"
        echo "${GRAY}=============${RESET}"
    else
        echo "System Status"
        echo "============="
    fi

    for item in "${status_items[@]}"; do
        local name="${item%%:*}"
        local value="${item##*:}"
        local status="unknown"

        case "$value" in
            running|active|up|online|enabled)
                status="success"
                ;;
            stopped|inactive|down|offline|disabled)
                status="error"
                ;;
            warning|partial|degraded)
                status="warning"
                ;;
            *)
                status="info"
                ;;
        esac

        printf "  %-20s: %s\n" "$name" "$(format_status "$status" "$value")"
    done
    echo ""
}

# Export functions for use in other modules
export -f init_ui print_header print_section print_success print_error print_warning
export -f print_info print_debug print_step print_indented print_bullet print_numbered
export -f print_table show_progress show_spinner ask_question ask_confirmation
export -f ask_password select_menu select_multiple select_file validate_input
export -f get_validated_input format_status print_box display_system_status

# Initialize UI system if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_ui true false true
    print_header "FUB UI System" "User interface and interaction utilities"
    print_success "UI system initialized successfully"
fi