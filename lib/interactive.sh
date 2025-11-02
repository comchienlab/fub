#!/usr/bin/env bash

# FUB Interactive UI System
# Provides comprehensive interactive components with optional gum enhancements
# Works with pure bash foundation and graceful degradation when gum is unavailable

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_SCRIPT_DIR}/common.sh"
    source "${FUB_SCRIPT_DIR}/theme.sh"
    source "${FUB_SCRIPT_DIR}/ui.sh"
fi

# Interactive system constants
readonly FUB_INTERACTIVE_TIMEOUT="${FUB_INTERACTIVE_TIMEOUT:-60}"
readonly FUB_MENU_HEIGHT="${FUB_MENU_HEIGHT:-10}"
readonly FUB_SCROLL_THRESHOLD="${FUB_SCROLL_THRESHOLD:-5}"

# Interactive system state
FUB_GUM_AVAILABLE=false
FUB_INTERACTIVE_ESC_SEQS=false
FUB_INTERACTIVE_CLEANUP_FUNCS=()

# Initialize interactive system
init_interactive() {
    log_debug "Initializing interactive UI system"

    # Check if gum is available
    if command_exists gum; then
        FUB_GUM_AVAILABLE=true
        log_debug "Gum detected - enhanced UI features available"
    else
        FUB_GUM_AVAILABLE=false
        log_debug "Gum not found - using pure bash interactive components"
    fi

    # Check if terminal supports escape sequences
    if [[ -t 0 ]] && [[ "${TERM:-}" != "dumb" ]]; then
        FUB_INTERACTIVE_ESC_SEQS=true
        log_debug "Terminal supports escape sequences"
    fi

    # Set up cleanup handlers
    trap 'cleanup_interactive' EXIT

    log_debug "Interactive system initialized (gum: $FUB_GUM_AVAILABLE, escape sequences: $FUB_INTERACTIVE_ESC_SEQS)"
}

# Cleanup interactive system
cleanup_interactive() {
    log_debug "Cleaning up interactive system"

    # Run any registered cleanup functions (check if array exists)
    if [[ "${FUB_INTERACTIVE_CLEANUP_FUNCS:+x}" == "x" ]]; then
        for cleanup_func in "${FUB_INTERACTIVE_CLEANUP_FUNCS[@]:-}"; do
            if command -v "$cleanup_func" >/dev/null 2>&1; then
                "$cleanup_func" || true
            fi
        done
    fi

    # Reset terminal state
    if [[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]]; then
        tput cnorm 2>/dev/null || true  # Show cursor
        stty echo 2>/dev/null || true   # Restore echo
    fi

    log_debug "Interactive system cleanup completed"
}

# Register cleanup function
register_cleanup() {
    local cleanup_func="$1"
    # Initialize array if it doesn't exist
    if [[ "${FUB_INTERACTIVE_CLEANUP_FUNCS+x}" != "x" ]]; then
        FUB_INTERACTIVE_CLEANUP_FUNCS=()
    fi
    FUB_INTERACTIVE_CLEANUP_FUNCS+=("$cleanup_func")
}

# Arrow key navigation without external dependencies
read_key() {
    local key
    local timeout="${1:-0}"

    if [[ $timeout -gt 0 ]]; then
        IFS= read -r -t "$timeout" -n 1 -s key 2>/dev/null || key=""
    else
        IFS= read -r -n 1 -s key 2>/dev/null || key=""
    fi

    # Handle escape sequences for arrow keys
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -r -t 0.1 -n 2 key 2>/dev/null || key=""
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
            '[1')
                # Handle extended escape sequences (Home, End, etc.)
                IFS= read -r -t 0.1 -n 1 key 2>/dev/null || key=""
                case "$key" in
                    '~') echo "HOME" ;;
                    *) echo "UNKNOWN" ;;
                esac
                ;;
            '[4')
                IFS= read -r -t 0.1 -n 1 key 2>/dev/null || key=""
                case "$key" in
                    '~') echo "END" ;;
                    *) echo "UNKNOWN" ;;
                esac
                ;;
            *) echo "UNKNOWN" ;;
        esac
    else
        case "$key" in
            '') echo "ENTER" ;;
            $'\x7f') echo "BACKSPACE" ;;
            $'\x09') echo "TAB" ;;
            ' ') echo "SPACE" ;;
            'q'|'Q') echo "QUIT" ;;
            'h'|'H') echo "HELP" ;;
            'r'|'R') echo "REFRESH" ;;
            *) echo "$key" ;;
        esac
    fi
}

# Interactive menu with arrow key navigation
interactive_menu() {
    local -n options_ref=$1
    local title="${2:-Select an option}"
    local default="${3:-1}"
    local allow_quit="${4:-true}"
    local show_help="${5:-false}"

    # Adjust default to zero-based index
    default=$((default - 1))

    if [[ ${#options_ref[@]} -eq 0 ]]; then
        log_error "No options available for interactive menu"
        return 1
    fi

    # Use gum if available and in interactive mode
    if [[ "$FUB_GUM_AVAILABLE" == true ]] && [[ "$FUB_INTERACTIVE_MODE" == true ]]; then
        local gum_options=()
        for option in "${options_ref[@]}"; do
            gum_options+=("$option")
        done

        if [[ "$allow_quit" == true ]]; then
            gum_options+=("❌ Quit")
        fi

        if [[ "$show_help" == true ]]; then
            gum_options+=("❓ Help")
        fi

        local selection
        selection=$(safe_gum choose --header="$title" --cursor="$default" "${gum_options[@]}")

        # Handle special options
        if [[ "$selection" == "❌ Quit" ]]; then
            echo "QUIT"
            return 130  # User cancelled
        elif [[ "$selection" == "❓ Help" ]]; then
            echo "HELP"
            return 126
        fi

        echo "$selection"
        return 0
    fi

    # Pure bash implementation
    local current=$default
    local max_index=$((${#options_ref[@]} - 1))
    local window_start=0
    local window_end=$((window_start + FUB_MENU_HEIGHT - 1))

    # Adjust window if needed
    if [[ $window_end -gt $max_index ]]; then
        window_end=$max_index
        window_start=$((window_end - FUB_MENU_HEIGHT + 1))
        if [[ $window_start -lt 0 ]]; then
            window_start=0
        fi
    fi

    # Save terminal state
    local saved_stty
    if [[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]]; then
        saved_stty=$(stty -g 2>/dev/null || echo "")
        stty -echo 2>/dev/null || true
        tput civis 2>/dev/null || true  # Hide cursor
    fi

    while true; do
        # Clear screen and redraw menu
        clear
        echo ""
        if supports_colors; then
            echo "${BOLD}${CYAN}$title${RESET}"
            echo "${GRAY}$(repeat_char "─" "${#title}")${RESET}"
        else
            echo "$title"
            echo "$(repeat_char "─" "${#title}")"
        fi
        echo ""

        # Display help text
        echo "${GRAY}Use ↑↓ to navigate, Enter to select"
        if [[ "$allow_quit" == true ]]; then
            echo "q: Quit"
        fi
        if [[ "$show_help" == true ]]; then
            echo "h: Help"
        fi
        echo "${RESET}"
        echo ""

        # Display menu items
        for ((i = window_start; i <= window_end && i <= max_index; i++)); do
            local option="${options_ref[$i]}"
            local marker=" "

            if [[ $i -eq $current ]]; then
                if supports_colors; then
                    marker="${BG_HIGHLIGHT}${WHITE}▶${RESET} "
                    echo -e " ${BOLD}${BG_HIGHLIGHT}${WHITE} $((i + 1)). ${option} ${RESET}"
                else
                    marker="> "
                    echo " $((i + 1)). $option"
                fi
            else
                if supports_colors; then
                    echo " ${GRAY}$((i + 1)).${RESET} $option"
                else
                    echo " $((i + 1)). $option"
                fi
            fi
        done

        # Show scroll indicators if needed
        if [[ $window_start -gt 0 ]]; then
            echo "${CYAN}  ⬆︎ (more above)${RESET}"
        fi
        if [[ $window_end -lt $max_index ]]; then
            echo "${CYAN}  ⬇︎ (more below)${RESET}"
        fi

        echo ""

        # Get user input
        local key
        key=$(read_key)

        case "$key" in
            "UP")
                if [[ $current -gt 0 ]]; then
                    ((current--))
                    # Adjust window if needed
                    if [[ $current -lt $window_start ]]; then
                        window_start=$current
                        window_end=$((window_start + FUB_MENU_HEIGHT - 1))
                    fi
                fi
                ;;
            "DOWN")
                if [[ $current -lt $max_index ]]; then
                    ((current++))
                    # Adjust window if needed
                    if [[ $current -gt $window_end ]]; then
                        window_end=$current
                        window_start=$((window_end - FUB_MENU_HEIGHT + 1))
                    fi
                fi
                ;;
            "HOME")
                current=0
                window_start=0
                window_end=$((window_start + FUB_MENU_HEIGHT - 1))
                if [[ $window_end -gt $max_index ]]; then
                    window_end=$max_index
                fi
                ;;
            "END")
                current=$max_index
                window_end=$max_index
                window_start=$((window_end - FUB_MENU_HEIGHT + 1))
                if [[ $window_start -lt 0 ]]; then
                    window_start=0
                fi
                ;;
            "ENTER")
                # Restore terminal state
                if [[ -n "$saved_stty" ]]; then
                    stty "$saved_stty" 2>/dev/null || true
                fi
                tput cnorm 2>/dev/null || true

                clear
                echo "${options_ref[$current]}"
                return $current
                ;;
            "QUIT")
                if [[ "$allow_quit" == true ]]; then
                    # Restore terminal state
                    if [[ -n "$saved_stty" ]]; then
                        stty "$saved_stty" 2>/dev/null || true
                    fi
                    tput cnorm 2>/dev/null || true

                    clear
                    echo "QUIT"
                    return 130
                fi
                ;;
            "HELP")
                if [[ "$show_help" == true ]]; then
                    # Restore terminal state
                    if [[ -n "$saved_stty" ]]; then
                        stty "$saved_stty" 2>/dev/null || true
                    fi
                    tput cnorm 2>/dev/null || true

                    clear
                    echo "HELP"
                    return 126
                fi
                ;;
            "1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9")
                local num="$key"
                # Read additional digits
                while true; do
                    local next_key
                    next_key=$(read_key 0.2)
                    if [[ "$next_key" =~ ^[0-9]$ ]]; then
                        num+="$next_key"
                    else
                        break
                    fi
                done

                local selection=$((num - 1))
                if [[ $selection -ge 0 ]] && [[ $selection -le $max_index ]]; then
                    # Restore terminal state
                    if [[ -n "$saved_stty" ]]; then
                        stty "$saved_stty" 2>/dev/null || true
                    fi
                    tput cnorm 2>/dev/null || true

                    clear
                    echo "${options_ref[$selection]}"
                    return $selection
                fi
                ;;
        esac
    done
}

# Multi-select interface with checkboxes
interactive_multiselect() {
    local -n options_ref=$1
    local -n defaults_ref=$2
    local title="${3:-Select options}"
    local allow_all="${4:-true}"
    local allow_none="${5:-true}"

    if [[ ${#options_ref[@]} -eq 0 ]]; then
        log_error "No options available for multi-select"
        return 1
    fi

    # Use gum if available
    if [[ "$FUB_GUM_AVAILABLE" == true ]] && [[ "$FUB_INTERACTIVE_MODE" == true ]]; then
        local gum_options=()

        # Prepare options for gum (add [ ] for checkboxes)
        for i in "${!options_ref[@]}"; do
            local option="${options_ref[$i]}"
            local selected=false

            # Check if this option is in defaults
            for default in "${defaults_ref[@]}"; do
                if [[ "$option" == "$default" ]]; then
                    selected=true
                    break
                fi
            done

            if [[ "$selected" == true ]]; then
                gum_options+=("✓ ${option}")
            else
                gum_options+=("  ${option}")
            fi
        done

        local selections
        selections=$(safe_gum choose --no-limit --header="$title" "${gum_options[@]}")

        # Process selections back to original format
        local -a result=()
        while IFS= read -r selection; do
            if [[ -n "$selection" ]]; then
                # Remove checkbox prefix
                local clean_selection="${selection:2}"
                result+=("$clean_selection")
            fi
        done <<< "$selections"

        printf '%s\n' "${result[@]}"
        return 0
    fi

    # Pure bash implementation
    local -a selected_indices=()
    local current=0
    local max_index=$((${#options_ref[@]} - 1))

    # Initialize with defaults
    for default in "${defaults_ref[@]}"; do
        for i in "${!options_ref[@]}"; do
            if [[ "${options_ref[$i]}" == "$default" ]]; then
                selected_indices+=("$i")
                break
            fi
        done
    done

    # Save terminal state
    local saved_stty
    if [[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]]; then
        saved_stty=$(stty -g 2>/dev/null || echo "")
        stty -echo 2>/dev/null || true
        tput civis 2>/dev/null || true
    fi

    while true; do
        clear
        echo ""
        if supports_colors; then
            echo "${BOLD}${CYAN}$title${RESET}"
            echo "${GRAY}$(repeat_char "─" "${#title}")${RESET}"
        else
            echo "$title"
            echo "$(repeat_char "─" "${#title}")"
        fi
        echo ""

        echo "${GRAY}Use ↑↓ to navigate, Space to toggle, Enter to confirm"
        if [[ "$allow_all" == true ]]; then
            echo "a: Toggle all"
        fi
        if [[ "$allow_none" == true ]]; then
            echo "n: Deselect all"
        fi
        echo "q: Quit"
        echo "${RESET}"
        echo ""

        # Display menu items
        for i in "${!options_ref[@]}"; do
            local option="${options_ref[$i]}"
            local is_selected=false

            # Check if this item is selected
            for selected in "${selected_indices[@]}"; do
                if [[ "$selected" == "$i" ]]; then
                    is_selected=true
                    break
                fi
            done

            if [[ $i -eq $current ]]; then
                if [[ "$is_selected" == true ]]; then
                    if supports_colors; then
                        echo -e " ${BOLD}${BG_HIGHLIGHT}${WHITE}[✓] ${option} ${RESET}"
                    else
                        echo "> [✓] $option"
                    fi
                else
                    if supports_colors; then
                        echo -e " ${BOLD}${BG_HIGHLIGHT}${WHITE}[ ] ${option} ${RESET}"
                    else
                        echo "> [ ] $option"
                    fi
                fi
            else
                if [[ "$is_selected" == true ]]; then
                    if supports_colors; then
                        echo " ${GREEN}[✓]${RESET} $option"
                    else
                        echo " [✓] $option"
                    fi
                else
                    echo " [ ] $option"
                fi
            fi
        done

        echo ""

        # Show summary
        if [[ ${#selected_indices[@]} -gt 0 ]]; then
            if supports_colors; then
                echo "${INFO}Selected: ${#selected_indices[@]} option(s)${RESET}"
            else
                echo "Selected: ${#selected_indices[@]} option(s)"
            fi
        else
            if supports_colors; then
                echo "${GRAY}No options selected${RESET}"
            else
                echo "No options selected"
            fi
        fi

        echo ""

        # Get user input
        local key
        key=$(read_key)

        case "$key" in
            "UP")
                if [[ $current -gt 0 ]]; then
                    ((current--))
                fi
                ;;
            "DOWN")
                if [[ $current -lt $max_index ]]; then
                    ((current++))
                fi
                ;;
            "SPACE")
                # Toggle selection
                local already_selected=false
                local -a new_selected=()

                for selected in "${selected_indices[@]}"; do
                    if [[ "$selected" != "$current" ]]; then
                        new_selected+=("$selected")
                    else
                        already_selected=true
                    fi
                done

                if [[ "$already_selected" != true ]]; then
                    new_selected+=("$current")
                fi

                selected_indices=("${new_selected[@]}")
                ;;
            "ENTER")
                # Restore terminal state
                if [[ -n "$saved_stty" ]]; then
                    stty "$saved_stty" 2>/dev/null || true
                fi
                tput cnorm 2>/dev/null || true

                clear

                # Output selected options
                if [[ ${#selected_indices[@]} -gt 0 ]]; then
                    local -a result=()
                    for index in "${selected_indices[@]}"; do
                        result+=("${options_ref[$index]}")
                    done
                    printf '%s\n' "${result[@]}"
                fi

                return 0
                ;;
            "QUIT")
                # Restore terminal state
                if [[ -n "$saved_stty" ]]; then
                    stty "$saved_stty" 2>/dev/null || true
                fi
                tput cnorm 2>/dev/null || true

                clear
                return 130
                ;;
            "a"|"A")
                if [[ "$allow_all" == true ]]; then
                    # Toggle all
                    if [[ ${#selected_indices[@]} -eq ${#options_ref[@]} ]]; then
                        selected_indices=()
                    else
                        selected_indices=()
                        for ((i=0; i<=max_index; i++)); do
                            selected_indices+=("$i")
                        done
                    fi
                fi
                ;;
            "n"|"N")
                if [[ "$allow_none" == true ]]; then
                    selected_indices=()
                fi
                ;;
        esac
    done
}

# Progress indicator with optional gum integration
show_progress_interactive() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing...}"
    local width="${4:-40}"

    # Note: gum doesn't have a progress command in current version
    # Always fall back to basic progress bar from ui.sh
    show_progress "$current" "$total" "$message" "$width"
}

# Spinner with optional gum integration
show_spinner_interactive() {
    local message="$1"
    local pid="$2"
    local delay="${3:-0.1}"

    # Use gum if available
    if [[ "$FUB_GUM_AVAILABLE" == true ]] && [[ "$FUB_INTERACTIVE_MODE" == true ]]; then
        # Wait for the process to complete
        if wait "$pid"; then
            safe_gum spin --spinner dot --title="$message" -- sleep 0.1 && safe_gum style --foreground=green "✓ $message completed"
        else
            safe_gum spin --spinner cross --title="$message" -- sleep 0.1 && safe_gum style --foreground=red "✗ $message failed"
        fi
        return $?
    fi

    # Fall back to basic spinner from ui.sh
    show_spinner "$message" "$pid" "$delay"
}

# Enhanced confirmation dialog with expert warnings
confirm_with_warning() {
    local message="$1"
    local warning="${2:-}"
    local default="${3:-n}"
    local require_expert="${4:-false}"

    if [[ "$FUB_INTERACTIVE_MODE" != true ]]; then
        # Default to 'no' in non-interactive mode
        [[ "$default" =~ ^[Yy] ]] && return 0 || return 1
    fi

    # Use gum if available
    if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
        local gum_message="$message"

        if [[ -n "$warning" ]]; then
            gum_message="$message

⚠ WARNING: $warning"
        fi

        if [[ "$require_expert" == true ]]; then
            gum_message="$gum_message

⚠ EXPERT MODE REQUIRED: This operation can cause system instability!"
        fi

        if safe_gum confirm "$gum_message" --default="$default"; then
            return 0
        else
            return 1
        fi
    fi

    # Pure bash implementation
    echo ""
    if supports_colors; then
        echo "${BOLD}${YELLOW}╔════════════════════════════════════════════════════════════════╗${RESET}"
        echo "${BOLD}${YELLOW}║ ${WARNING}⚠ CONFIRMATION REQUIRED${RESET}                                    ${BOLD}${YELLOW}║${RESET}"
        echo "${BOLD}${YELLOW}╚════════════════════════════════════════════════════════════════╝${RESET}"
    else
        echo "=================================================================="
        echo "⚠ CONFIRMATION REQUIRED"
        echo "=================================================================="
    fi
    echo ""

    if supports_colors; then
        echo "${BOLD}${WHITE}$message${RESET}"
    else
        echo "$message"
    fi

    if [[ -n "$warning" ]]; then
        echo ""
        if supports_colors; then
            echo "${BOLD}${YELLOW}WARNING: $warning${RESET}"
        else
            echo "WARNING: $warning"
        fi
    fi

    if [[ "$require_expert" == true ]]; then
        echo ""
        if supports_colors; then
            echo "${BOLD}${RED}EXPERT MODE REQUIRED: This operation can cause system instability!${RESET}"
        else
            echo "EXPERT MODE REQUIRED: This operation can cause system instability!"
        fi
    fi

    echo ""

    # Ask for confirmation
    if [[ "$default" =~ ^[Yy] ]]; then
        echo "${BOLD}${YELLOW}Continue? [Y/n]${RESET}"
    else
        echo "${BOLD}${YELLOW}Continue? [y/N]${RESET}"
    fi

    local answer
    while true; do
        read -p "> " answer
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

# Main menu interface for FUB
show_main_menu() {
    local -a main_options=(
        "System Cleanup & Maintenance"
        "Package Management"
        "Service Management"
        "Network Utilities"
        "Configuration Management"
        "System Information"
        "Performance Monitoring"
        "Security Tools"
        "Help & Documentation"
        "Quit"
    )

    local choice
    choice=$(interactive_menu main_options "FUB - Ubuntu Utility Toolkit" 1 true true)

    case "$choice" in
        "System Cleanup & Maintenance")
            echo "cleanup"
            ;;
        "Package Management")
            echo "packages"
            ;;
        "Service Management")
            echo "services"
            ;;
        "Network Utilities")
            echo "network"
            ;;
        "Configuration Management")
            echo "config"
            ;;
        "System Information")
            echo "info"
            ;;
        "Performance Monitoring")
            echo "performance"
            ;;
        "Security Tools")
            echo "security"
            ;;
        "Help & Documentation")
            echo "help"
            ;;
        "Quit")
            echo "quit"
            ;;
    esac
}

# Category selection for cleanup operations
select_cleanup_categories() {
    local -a categories=(
        "Temporary Files"
        "Package Cache"
        "Log Files"
        "Old Kernels"
        "Browser Cache"
        "System Junk"
        "Thumbnails Cache"
        "Application Cache"
    )

    local -a defaults=("Temporary Files" "Package Cache")

    local selections
    selections=$(interactive_multiselect categories defaults "Select Cleanup Categories" true true)

    if [[ $? -eq 0 ]]; then
        # Convert selections to internal format
        local -a result=()
        while IFS= read -r selection; do
            case "$selection" in
                "Temporary Files") result+=("temp") ;;
                "Package Cache") result+=("cache") ;;
                "Log Files") result+=("logs") ;;
                "Old Kernels") result+=("kernels") ;;
                "Browser Cache") result+=("browser") ;;
                "System Junk") result+=("junk") ;;
                "Thumbnails Cache") result+=("thumbnails") ;;
                "Application Cache") result+=("appcache") ;;
            esac
        done <<< "$selections"

        # Output as comma-separated string
        echo "${result[@]}"
    else
        return 1
    fi
}

# Helper function to safely run gum commands
safe_gum() {
    # Save all potentially conflicting environment variables
    local old_bold="${BOLD:-}"
    local old_dim="${DIM:-}"
    local old_italic="${ITALIC:-}"
    local old_underline="${UNDERLINE:-}"
    local old_reset="${RESET:-}"
    local old_fg_color="${FOREGROUND:-}"
    local old_bg_color="${BACKGROUND:-}"
    local old_border_color="${BORDER_FOREGROUND:-}"

    # Clear environment variables that interfere with gum
    unset BOLD DIM ITALIC UNDERLINE RESET FOREGROUND BACKGROUND BORDER_FOREGROUND

    # Run gum with the provided arguments
    gum "$@"
    local gum_exit_code=$?

    # Restore environment
    export BOLD="$old_bold"
    export DIM="$old_dim"
    export ITALIC="$old_italic"
    export UNDERLINE="$old_underline"
    export RESET="$old_reset"
    export FOREGROUND="$old_fg_color"
    export BACKGROUND="$old_bg_color"
    export BORDER_FOREGROUND="$old_border_color"

    return $gum_exit_code
}

# Visual feedback system
show_operation_result() {
    local operation="$1"
    local result="$2"
    local details="${3:-}"

    echo ""

    case "$result" in
        "success"|"ok"|"completed")
            if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
                safe_gum style \
                    --foreground=green \
                    --border=rounded \
                    --padding="1 2" \
                    "✓ $operation completed successfully"
            else
                if supports_colors; then
                    echo "${BOLD}${GREEN}✓ $operation completed successfully${RESET}"
                else
                    echo "✓ $operation completed successfully"
                fi
            fi
            ;;
        "error"|"failed"|"failure")
            if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
                safe_gum style \
                    --foreground=red \
                    --border=rounded \
                    --padding="1 2" \
                    "✗ $operation failed"
            else
                if supports_colors; then
                    echo "${BOLD}${RED}✗ $operation failed${RESET}"
                else
                    echo "✗ $operation failed"
                fi
            fi
            ;;
        "warning"|"partial")
            if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
                safe_gum style \
                    --foreground=yellow \
                    --border=rounded \
                    --padding="1 2" \
                    "⚠ $operation completed with warnings"
            else
                if supports_colors; then
                    echo "${BOLD}${YELLOW}⚠ $operation completed with warnings${RESET}"
                else
                    echo "⚠ $operation completed with warnings"
                fi
            fi
            ;;
        *)
            if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
                safe_gum style \
                    --foreground=blue \
                    --border=rounded \
                    --padding="1 2" \
                    "ℹ $operation"
            else
                if supports_colors; then
                    echo "${BOLD}${BLUE}ℹ $operation${RESET}"
                else
                    echo "ℹ $operation"
                fi
            fi
            ;;
    esac

    if [[ -n "$details" ]]; then
        echo ""
        if supports_colors; then
            echo "${GRAY}$details${RESET}"
        else
            echo "$details"
        fi
    fi

    echo ""
}

# Interactive help system
show_interactive_help() {
    local topic="${1:-main}"

    if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
        # Use gum pager for help if available
        local help_content
        help_content=$(get_help_content "$topic")
        echo "$help_content" | safe_gum pager --style=border --border=rounded
    else
        # Pure bash help display
        clear
        echo ""
        if supports_colors; then
            echo "${BOLD}${CYAN}FUB - Ubuntu Utility Toolkit - Help${RESET}"
            echo "${GRAY}$(repeat_char "═" 40)${RESET}"
        else
            echo "FUB - Ubuntu Utility Toolkit - Help"
            echo "$(repeat_char "═" 40)"
        fi
        echo ""

        get_help_content "$topic"

        echo ""
        if supports_colors; then
            echo "${GRAY}Press any key to return...${RESET}"
        else
            echo "Press any key to return..."
        fi
        read -n 1 -s
    fi
}

# Get help content for topics
get_help_content() {
    local topic="$1"

    case "$topic" in
        "main")
            cat << 'EOF'
MAIN MENU OPTIONS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FUB provides comprehensive system management utilities for Ubuntu:

🔹 System Cleanup & Maintenance
   Remove temporary files, clean caches, manage disk space

🔹 Package Management
   Install, remove, and update Ubuntu packages

🔹 Service Management
   Start, stop, enable, and monitor system services

🔹 Network Utilities
   Test connectivity, diagnose network issues

🔹 Configuration Management
   Backup and restore system configurations

🔹 System Information
   View detailed system information and statistics

🔹 Performance Monitoring
   Monitor CPU, memory, disk, and network usage

🔹 Security Tools
   Security scanning and system hardening utilities

🔹 Help & Documentation
   Access comprehensive help and documentation

NAVIGATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Use arrow keys (↑↓) to navigate menus
• Press Enter to select an option
• Press 'q' to quit from any menu
• Press 'h' for help where available

KEYBOARD SHORTCUTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Home/End: Jump to first/last item in long lists
• Space: Toggle items in multi-select menus
• Number keys: Quick selection by item number
• Esc: Cancel operation and return to previous menu
EOF
            ;;
        "cleanup")
            cat << 'EOF'
SYSTEM CLEANUP & MAINTENANCE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This module helps you safely remove unnecessary files and free up disk space.

AVAILABLE CATEGORIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔹 Temporary Files
   • Application temporary data
   • Session files
   • Crash reports

🔹 Package Cache
   • APT download cache
   • Old package versions
   • Package metadata

🔹 Log Files
   • System logs (older than 30 days)
   • Application logs
   • Debug logs

🔹 Old Kernels
   • Unused kernel versions
   • Kernel headers
   • Kernel modules

🔹 Browser Cache
   • Chrome/Chromium cache
   • Firefox cache
   • Other browser data

SAFETY FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Only removes files that are safe to delete
• Preserves recent system logs (last 30 days)
• Never removes currently running kernel
• Creates backup of important configs
• Confirmations for all destructive operations

⚠ EXPERT TIP: Run cleanup in single-user mode for maximum efficiency
EOF
            ;;
        *)
            echo "Help topic '$topic' not found."
            echo ""
            echo "Available help topics:"
            echo "  main    - Main menu navigation"
            echo "  cleanup - System cleanup guide"
            echo ""
            ;;
    esac
}

# Status display with real-time updates
show_system_status_interactive() {
    local refresh_interval="${1:-5}"
    local auto_refresh="${2:-false}"

    while true; do
        clear
        echo ""
        if supports_colors; then
            echo "${BOLD}${CYAN}FUB System Status${RESET}"
            echo "${GRAY}$(repeat_char "═" 50)${RESET}"
        else
            echo "FUB System Status"
            echo "$(repeat_char "═" 50)"
        fi
        echo ""

        # System Information
        echo "${BOLD}System Information:${RESET}"
        printf "  %-20s: %s\n" "OS" "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Ubuntu')"
        printf "  %-20s: %s\n" "Kernel" "$(uname -r)"
        printf "  %-20s: %s\n" "Uptime" "$(uptime -p 2>/dev/null || uptime)"
        printf "  %-20s: %s\n" "Load Average" "$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')"
        echo ""

        # Memory Usage
        echo "${BOLD}Memory Usage:${RESET}"
        local memory_info
        if command_exists free; then
            memory_info=$(free -h | grep "Mem:")
            local total=$(echo $memory_info | awk '{print $2}')
            local used=$(echo $memory_info | awk '{print $3}')
            local free=$(echo $memory_info | awk '{print $4}')
            local usage=$(echo $memory_info | awk '{print $3}' | sed 's/G//' | awk '{printf "%.1f", $1*100/($1+$(echo "'$memory_info'" | awk '{print $4}' | sed 's/G//'))}')

            printf "  %-20s: %s\n" "Total" "$total"
            printf "  %-20s: %s (%s%%)" "Used" "$used" "${usage%.*}"
            printf "  %-20s: %s\n" "Free" "$free"

            # Memory usage bar
            local bar_width=30
            local filled=$((usage * bar_width / 100))
            printf "  %-20s: [" "Usage"
            if [[ $usage -gt 80 ]]; then
                printf "${RED}%s${RESET}" "$(repeat_char "█" "$filled")"
            elif [[ $usage -gt 60 ]]; then
                printf "${YELLOW}%s${RESET}" "$(repeat_char "█" "$filled")"
            else
                printf "${GREEN}%s${RESET}" "$(repeat_char "█" "$filled")"
            fi
            printf "%s] %s%%\n" "$(repeat_char "░" $((bar_width - filled)))" "${usage%.*}"
        fi
        echo ""

        # Disk Usage
        echo "${BOLD}Disk Usage:${RESET}"
        if command_exists df; then
            df -h | grep -E '^/dev/' | while read line; do
                local filesystem=$(echo "$line" | awk '{print $1}')
                local size=$(echo "$line" | awk '{print $2}')
                local used=$(echo "$line" | awk '{print $3}')
                local avail=$(echo "$line" | awk '{print $4}')
                local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                local mount=$(echo "$line" | awk '{print $6}')

                printf "  %-20s: %s %s/%s (%s%%)\n" "$mount" "$filesystem" "$used" "$size" "$usage"
            done
        fi
        echo ""

        # Network Status
        echo "${BOLD}Network Status:${RESET}"
        if command_exists ip; then
            local interfaces=$(ip link show | grep 'state UP' | awk -F': ' '{print $2}' | cut -d'@' -f1)
            if [[ -n "$interfaces" ]]; then
                echo "$interfaces" | while read interface; do
                    if [[ -n "$interface" ]]; then
                        local ip_addr=$(ip addr show "$interface" | grep 'inet ' | awk '{print $2}' | head -1)
                        printf "  %-20s: %s\n" "$interface" "${ip_addr:-'No IP'}"
                    fi
                done
            else
                echo "  No active network interfaces"
            fi
        fi
        echo ""

        # Services Status
        echo "${BOLD}Key Services:${RESET}"
        local -a key_services=("ssh" "docker" "nginx" "apache2" "mysql" "postgresql")
        for service in "${key_services[@]}"; do
            if service_exists "$service"; then
                local status="inactive"
                if is_service_active "$service"; then
                    status="${GREEN}active${RESET}"
                else
                    status="${RED}inactive${RESET}"
                fi
                printf "  %-20s: %s\n" "$service" "$status"
            fi
        done
        echo ""

        if supports_colors; then
            echo "${GRAY}Last updated: $(date)${RESET}"
        else
            echo "Last updated: $(date)"
        fi

        if [[ "$auto_refresh" == false ]]; then
            echo ""
            echo "Press 'r' to refresh, 'q' to quit"

            local key
            key=$(read_key)
            case "$key" in
                "r"|"R")
                    continue
                    ;;
                "q"|"Q"|"QUIT")
                    break
                    ;;
            esac
        else
            sleep "$refresh_interval"
        fi
    done
}

# Quick actions menu
show_quick_actions() {
    local -a actions=(
        "Quick System Scan"
        "Clean Temp Files"
        "Update Package Lists"
        "Check Disk Space"
        "Show System Load"
        "Network Test"
        "Service Status"
        "Back to Main Menu"
    )

    local choice
    choice=$(interactive_menu actions "Quick Actions" 1 true false)

    case "$choice" in
        "Quick System Scan")
            echo "quick-scan"
            ;;
        "Clean Temp Files")
            echo "clean-temp"
            ;;
        "Update Package Lists")
            echo "update-packages"
            ;;
        "Check Disk Space")
            echo "disk-space"
            ;;
        "Show System Load")
            echo "system-load"
            ;;
        "Network Test")
            echo "network-test"
            ;;
        "Service Status")
            echo "service-status"
            ;;
        "Back to Main Menu")
            echo "main"
            ;;
    esac
}

# Export interactive functions
export -f init_interactive cleanup_interactive register_cleanup
export -f read_key interactive_menu interactive_multiselect
export -f show_progress_interactive show_spinner_interactive
export -f confirm_with_warning show_main_menu select_cleanup_categories
export -f show_operation_result show_interactive_help get_help_content
export -f show_system_status_interactive show_quick_actions

# Utility function to generate repeated characters (cross-platform)
repeat_char() {
    local char="$1"
    local count="$2"
    local result=""

    # Use different methods based on available commands
    if command -v jot >/dev/null 2>&1; then
        # BSD/macOS: use jot
        result=$(jot -b "$char" "$count" 2>/dev/null | tr -d '\n' || echo "")
    elif command -v seq >/dev/null 2>&1; then
        # GNU: use seq (avoiding the problematic syntax)
        result=$(seq -s "$char" "$count" 2>/dev/null | sed 's/[0-9]//g' || echo "")
    else
        # Fallback: use a simple loop
        for ((i=0; i<count; i++)); do
            result+="$char"
        done
    fi

    # If all methods failed, use the loop fallback
    if [[ -z "$result" ]] && [[ $count -gt 0 ]]; then
        result=""
        for ((i=0; i<count; i++)); do
            result+="$char"
        done
    fi

    echo "$result"
}

# Export repeat_char function for use in other scripts
export -f repeat_char

# Auto-initialize only when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_interactive
    log_debug "FUB interactive UI system loaded"
fi