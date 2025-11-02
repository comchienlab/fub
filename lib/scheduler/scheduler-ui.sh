#!/usr/bin/env bash

# FUB Scheduler UI
# Interactive user interface for scheduler management

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Source UI libraries
source "${FUB_ROOT_DIR}/lib/ui.sh"
source "${FUB_ROOT_DIR}/lib/theme.sh"

# Source scheduler components
source "${FUB_ROOT_DIR}/lib/scheduler/scheduler.sh"

# Scheduler UI constants
readonly FUB_SCHEDULER_UI_VERSION="1.0.0"

# Initialize scheduler UI
init_scheduler_ui() {
    init_scheduler
    init_theme
}

# Show scheduler main menu
show_scheduler_menu() {
    init_scheduler_ui

    while true; do
        clear
        show_scheduler_header

        local options=(
            "1" "View Scheduler Status"
            "2" "Manage Profiles"
            "3" "View Active Timers"
            "4" "Run Maintenance"
            "5" "View History"
            "6" "View Statistics"
            "7" "Configure Notifications"
            "8" "Generate Report"
            "9" "Test Scheduler"
            "10" "Maintenance"
            "0" "Exit"
        )

        local choice
        choice=$(show_menu "FUB Scheduler Management" "Choose an option:" "${options[@]}")

        case "$choice" in
            "1")
                show_scheduler_status_detailed
                ;;
            "2")
                show_profile_management_menu
                ;;
            "3")
                show_active_timers
                ;;
            "4")
                show_run_maintenance_menu
                ;;
            "5")
                show_history_menu
                ;;
            "6")
                show_statistics_menu
                ;;
            "7")
                show_notification_config_menu
                ;;
            "8")
                generate_maintenance_report
                show_pause "Report generated. Press Enter to continue..."
                ;;
            "9")
                test_scheduler
                show_pause "Scheduler test completed. Press Enter to continue..."
                ;;
            "10")
                scheduler_maintenance
                show_pause "Maintenance completed. Press Enter to continue..."
                ;;
            "0")
                echo "Exiting FUB Scheduler..."
                return 0
                ;;
            *)
                show_error "Invalid option: $choice"
                show_pause "Press Enter to continue..."
                ;;
        esac
    done
}

# Show scheduler header
show_scheduler_header() {
    echo "${COLOR_CYAN}${COLOR_BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    FUB SCHEDULER v$FUB_SCHEDULER_VERSION                      ║"
    echo "║              Fast Ubuntu Utility Toolkit Scheduler            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo "${COLOR_RESET}"
    echo
}

# Show detailed scheduler status
show_scheduler_status_detailed() {
    clear
    show_scheduler_header

    echo "${COLOR_BOLD}Scheduler Status${COLOR_RESET}"
    echo "=================="
    echo

    # Get scheduler status
    get_scheduler_status
    echo

    # Show system information
    echo "${COLOR_BOLD}System Information${COLOR_RESET}"
    echo "-------------------"
    echo "OS: $(get_ubuntu_version 2>/dev/null || echo "Unknown")"
    echo "User: $(whoami)"
    echo "Shell: $SHELL"
    echo "Systemd: $(is_systemd_user_available && echo "Available" || echo "Not available")"
    echo "Desktop: ${DESKTOP_SESSION:-"None"}"
    echo

    # Show recent activity
    echo "${COLOR_BOLD}Recent Activity${COLOR_RESET}"
    echo "---------------"
    get_notification_history "" "" "5"
    echo

    show_pause "Press Enter to return to main menu..."
}

# Show profile management menu
show_profile_management_menu() {
    while true; do
        clear
        show_scheduler_header

        echo "${COLOR_BOLD}Profile Management${COLOR_RESET}"
        echo "==================="
        echo

        # List available profiles
        echo "${COLOR_BOLD}Available Profiles:${COLOR_RESET}"
        list_profiles
        echo

        local options=(
            "1" "Enable Profile"
            "2" "Disable Profile"
            "3" "Create Custom Profile"
            "4" "Delete Custom Profile"
            "5" "View Profile Details"
            "6" "Suggest Profile"
            "0" "Back to Main Menu"
        )

        local choice
        choice=$(show_menu "Profile Management" "Choose an option:" "${options[@]}")

        case "$choice" in
            "1")
                enable_profile_interactive
                ;;
            "2")
                disable_profile_interactive
                ;;
            "3")
                create_profile_interactive
                ;;
            "4")
                delete_profile_interactive
                ;;
            "5")
                view_profile_details_interactive
                ;;
            "6")
                suggest_profile
                show_pause "Press Enter to continue..."
                ;;
            "0")
                break
                ;;
            *)
                show_error "Invalid option: $choice"
                show_pause "Press Enter to continue..."
                ;;
        esac
    done
}

# Enable profile interactively
enable_profile_interactive() {
    echo
    echo "${COLOR_BOLD}Enable Profile${COLOR_RESET}"
    echo "==============="
    echo

    # Get available profiles
    local profiles=()
    local profile_files=()

    for profile_file in "${FUB_PROFILE_CONFIG_DIR}"/*.yaml "${FUB_PROFILE_USER_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
            profile_files+=("$profile_file")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        show_error "No profiles found"
        return 1
    fi

    # Show profiles with status
    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        local profile="${profiles[$i]}"
        local status="Inactive"
        if systemctl --user is-active --quiet "fub-${profile}.timer" 2>/dev/null; then
            status="Active"
        fi
        printf "  %d) %s (%s)\n" $((i+1)) "$profile" "$status"
    done
    echo

    local profile_choice
    read -p "Enter profile number to enable: " profile_choice

    if [[ ! "$profile_choice" =~ ^[0-9]+$ ]] || [[ $profile_choice -lt 1 ]] || [[ $profile_choice -gt ${#profiles[@]} ]]; then
        show_error "Invalid profile selection"
        return 1
    fi

    local selected_profile="${profiles[$((profile_choice-1))]}"

    echo "Enabling profile: $selected_profile"
    if enable_profile "$selected_profile"; then
        show_success "Profile '$selected_profile' enabled successfully"
    else
        show_error "Failed to enable profile '$selected_profile'"
    fi

    show_pause "Press Enter to continue..."
}

# Disable profile interactively
disable_profile_interactive() {
    echo
    echo "${COLOR_BOLD}Disable Profile${COLOR_RESET}"
    echo "================"
    echo

    # Get active profiles
    local active_profiles
    active_profiles=$(get_active_profiles)

    if [[ -z "$active_profiles" ]]; then
        show_info "No active profiles found"
        return 0
    fi

    echo "Active profiles:"
    local profiles_array=($active_profiles)
    for i in "${!profiles_array[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${profiles_array[$i]}"
    done
    echo

    local profile_choice
    read -p "Enter profile number to disable: " profile_choice

    if [[ ! "$profile_choice" =~ ^[0-9]+$ ]] || [[ $profile_choice -lt 1 ]] || [[ $profile_choice -gt ${#profiles_array[@]} ]]; then
        show_error "Invalid profile selection"
        return 1
    fi

    local selected_profile="${profiles_array[$((profile_choice-1))]}"

    echo "Disabling profile: $selected_profile"
    if disable_profile "$selected_profile"; then
        show_success "Profile '$selected_profile' disabled successfully"
    else
        show_error "Failed to disable profile '$selected_profile'"
    fi

    show_pause "Press Enter to continue..."
}

# Create custom profile interactively
create_profile_interactive() {
    echo
    echo "${COLOR_BOLD}Create Custom Profile${COLOR_RESET}"
    echo "======================="
    echo

    local profile_name
    read -p "Enter profile name: " profile_name

    if [[ -z "$profile_name" ]]; then
        show_error "Profile name cannot be empty"
        return 1
    fi

    if [[ ! "$profile_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        show_error "Profile name must contain only alphanumeric characters, hyphens, and underscores"
        return 1
    fi

    # Check if profile already exists
    if [[ -f "${FUB_PROFILE_CONFIG_DIR}/${profile_name}.yaml" ]] || [[ -f "${FUB_PROFILE_USER_DIR}/${profile_name}.yaml" ]]; then
        show_error "Profile '$profile_name' already exists"
        return 1
    fi

    local description
    read -p "Enter profile description: " description

    echo ""
    echo "Schedule options:"
    echo "  1) Hourly"
    echo "  2) Daily"
    echo "  3) Weekly"
    echo "  4) Custom (e.g., 'daily 18:00', 'weekly', '*-*-* 02:00:00')"
    echo

    local schedule_choice
    read -p "Choose schedule (1-4): " schedule_choice

    local schedule
    case "$schedule_choice" in
        "1")
            schedule="hourly"
            ;;
        "2")
            schedule="daily"
            ;;
        "3")
            schedule="weekly"
            ;;
        "4")
            read -p "Enter custom schedule: " schedule
            ;;
        *)
            show_error "Invalid schedule choice"
            return 1
            ;;
    esac

    local operations
    echo ""
    echo "Available operations:"
    echo "  temp - Clean temporary files"
    echo "  cache - Clean package and system caches"
    echo "  logs - Clean old log files"
    echo "  thumbnails - Clean thumbnail cache"
    echo "  build_cache - Clean build cache"
    echo "  npm_cache - Clean npm cache"
    echo "  docker_cache - Clean Docker cache"
    echo ""

    read -p "Enter operations (space-separated, e.g., 'temp cache'): " operations

    if [[ -z "$operations" ]]; then
        operations="temp cache"  # Default
    fi

    echo ""
    echo "Creating profile with the following settings:"
    echo "  Name: $profile_name"
    echo "  Description: $description"
    echo "  Schedule: $schedule"
    echo "  Operations: $operations"
    echo ""

    local confirm
    read -p "Create this profile? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if create_profile "$profile_name" "$description" "$schedule" "$operations"; then
            show_success "Profile '$profile_name' created successfully"
        else
            show_error "Failed to create profile '$profile_name'"
        fi
    else
        show_info "Profile creation cancelled"
    fi

    show_pause "Press Enter to continue..."
}

# Delete custom profile interactively
delete_profile_interactive() {
    echo
    echo "${COLOR_BOLD}Delete Custom Profile${COLOR_RESET}"
    echo "======================="
    echo

    # Get user profiles
    local user_profiles=()
    for profile_file in "${FUB_PROFILE_USER_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            user_profiles+=("$profile_name")
        fi
    done

    if [[ ${#user_profiles[@]} -eq 0 ]]; then
        show_info "No custom profiles found"
        return 0
    fi

    echo "Custom profiles:"
    for i in "${!user_profiles[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${user_profiles[$i]}"
    done
    echo

    local profile_choice
    read -p "Enter profile number to delete: " profile_choice

    if [[ ! "$profile_choice" =~ ^[0-9]+$ ]] || [[ $profile_choice -lt 1 ]] || [[ $profile_choice -gt ${#user_profiles[@]} ]]; then
        show_error "Invalid profile selection"
        return 1
    fi

    local selected_profile="${user_profiles[$((profile_choice-1))]}"

    echo ""
    echo "WARNING: This will permanently delete profile '$selected_profile'"
    echo ""

    local confirm
    read -p "Are you sure? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if delete_profile "$selected_profile"; then
            show_success "Profile '$selected_profile' deleted successfully"
        else
            show_error "Failed to delete profile '$selected_profile'"
        fi
    else
        show_info "Profile deletion cancelled"
    fi

    show_pause "Press Enter to continue..."
}

# View profile details interactively
view_profile_details_interactive() {
    echo
    echo "${COLOR_BOLD}View Profile Details${COLOR_RESET}"
    echo "====================="
    echo

    # Get available profiles
    local profiles=()
    for profile_file in "${FUB_PROFILE_CONFIG_DIR}"/*.yaml "${FUB_PROFILE_USER_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        show_error "No profiles found"
        return 1
    fi

    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${profiles[$i]}"
    done
    echo

    local profile_choice
    read -p "Enter profile number to view: " profile_choice

    if [[ ! "$profile_choice" =~ ^[0-9]+$ ]] || [[ $profile_choice -lt 1 ]] || [[ $profile_choice -gt ${#profiles[@]} ]]; then
        show_error "Invalid profile selection"
        return 1
    fi

    local selected_profile="${profiles[$((profile_choice-1))]}"

    clear
    show_scheduler_header
    get_profile_status "$selected_profile"

    show_pause "Press Enter to continue..."
}

# Show active timers
show_active_timers() {
    clear
    show_scheduler_header

    echo "${COLOR_BOLD}Active Timers${COLOR_RESET}"
    echo "============="
    echo

    if ! is_systemd_user_available; then
        show_error "Systemd user services not available"
        show_pause "Press Enter to continue..."
        return 1
    fi

    # Show systemd timers
    echo "Systemd Timers:"
    systemctl --user list-timers "${FUB_SYSTEMD_TIMER_PREFIX}*" --no-pager || {
        show_info "No FUB timers found"
    }

    echo
    echo "Timer Status:"
    list_systemd_timers

    show_pause "Press Enter to continue..."
}

# Show run maintenance menu
show_run_maintenance_menu() {
    echo
    echo "${COLOR_BOLD}Run Maintenance${COLOR_RESET}"
    echo "================"
    echo

    # Get available profiles
    local profiles=()
    for profile_file in "${FUB_PROFILE_CONFIG_DIR}"/*.yaml "${FUB_PROFILE_USER_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        show_error "No profiles found"
        return 1
    fi

    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${profiles[$i]}"
    done
    echo

    local profile_choice
    read -p "Enter profile number to run maintenance for: " profile_choice

    if [[ ! "$profile_choice" =~ ^[0-9]+$ ]] || [[ $profile_choice -lt 1 ]] || [[ $profile_choice -gt ${#profiles[@]} ]]; then
        show_error "Invalid profile selection"
        return 1
    fi

    local selected_profile="${profiles[$((profile_choice-1))]}"

    echo ""
    echo "Force execution (skip condition checks)?"
    echo "  1) No (respect conditions)"
    echo "  2) Yes (force execution)"
    echo ""

    local force_choice
    read -p "Choose option (1-2): " force_choice

    local force="false"
    [[ "$force_choice" == "2" ]] && force="true"

    echo ""
    echo "Running maintenance for profile: $selected_profile"
    echo "Force execution: $force"
    echo ""

    if run_scheduled_maintenance "$selected_profile" "$force"; then
        show_success "Maintenance completed successfully"
    else
        show_error "Maintenance failed"
    fi

    show_pause "Press Enter to continue..."
}

# Show history menu
show_history_menu() {
    while true; do
        clear
        show_scheduler_header

        echo "${COLOR_BOLD}Maintenance History${COLOR_RESET}"
        echo "==================="
        echo

        local options=(
            "1" "View All History"
            "2" "View by Profile"
            "3" "View by Status"
            "4" "View Recent (7 days)"
            "5" "Export History"
            "0" "Back to Main Menu"
        )

        local choice
        choice=$(show_menu "Maintenance History" "Choose an option:" "${options[@]}")

        case "$choice" in
            "1")
                clear
                show_history "30"
                show_pause "Press Enter to continue..."
                ;;
            "2")
                view_history_by_profile
                ;;
            "3")
                view_history_by_status
                ;;
            "4")
                clear
                show_history "7"
                show_pause "Press Enter to continue..."
                ;;
            "5")
                export_history_interactive
                ;;
            "0")
                break
                ;;
            *)
                show_error "Invalid option: $choice"
                show_pause "Press Enter to continue..."
                ;;
        esac
    done
}

# View history by profile
view_history_by_profile() {
    echo
    echo "${COLOR_BOLD}History by Profile${COLOR_RESET}"
    echo "=================="
    echo

    # Get available profiles
    local profiles=()
    for profile_file in "${FUB_PROFILE_CONFIG_DIR}"/*.yaml "${FUB_PROFILE_USER_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    echo "Available profiles:"
    for i in "${!profiles[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${profiles[$i]}"
    done
    echo

    local profile_choice
    read -p "Enter profile number to view history for: " profile_choice

    if [[ ! "$profile_choice" =~ ^[0-9]+$ ]] || [[ $profile_choice -lt 1 ]] || [[ $profile_choice -gt ${#profiles[@]} ]]; then
        show_error "Invalid profile selection"
        return 1
    fi

    local selected_profile="${profiles[$((profile_choice-1))]}"

    clear
    show_scheduler_header
    show_history "30" "$selected_profile"

    show_pause "Press Enter to continue..."
}

# View history by status
view_history_by_status() {
    echo
    echo "${COLOR_BOLD}History by Status${COLOR_RESET}"
    echo "=================="
    echo

    echo "Status options:"
    echo "  1) Success"
    echo "  2) Failed"
    echo "  3) All"
    echo

    local status_choice
    read -p "Enter status option (1-3): " status_choice

    local status_filter=""
    case "$status_choice" in
        "1")
            status_filter="success"
            ;;
        "2")
            status_filter="failed"
            ;;
        "3")
            status_filter=""
            ;;
        *)
            show_error "Invalid status choice"
            return 1
            ;;
    esac

    clear
    show_scheduler_header

    if [[ -n "$status_filter" ]]; then
        echo "${COLOR_BOLD}Maintenance History - Status: $status_filter${COLOR_RESET}"
        echo "=========================================="
    else
        echo "${COLOR_BOLD}Maintenance History - All Status${COLOR_RESET}"
        echo "================================="
    fi
    echo

    # Show filtered history (this would need to be implemented in the history module)
    show_history "30"

    show_pause "Press Enter to continue..."
}

# Export history interactively
export_history_interactive() {
    echo
    echo "${COLOR_BOLD}Export History${COLOR_RESET}"
    echo "==============="
    echo

    local format_choice
    echo "Export format:"
    echo "  1) CSV"
    echo "  2) JSON"
    echo

    read -p "Choose format (1-2): " format_choice

    local format="csv"
    case "$format_choice" in
        "1")
            format="csv"
            ;;
        "2")
            format="json"
            ;;
        *)
            show_error "Invalid format choice"
            return 1
            ;;
    esac

    local days
    read -p "Enter number of days to export (default: 30): " days
    days="${days:-30}"

    local output_file
    read -p "Enter output file path: " output_file

    if [[ -z "$output_file" ]]; then
        output_file="fub_history_$(date +%Y%m%d).$format"
    fi

    echo ""
    echo "Exporting history..."
    echo "  Format: $format"
    echo "  Days: $days"
    echo "  Output: $output_file"
    echo ""

    if export_history_data "$format" "$output_file" "$days"; then
        show_success "History exported to: $output_file"
    else
        show_error "Failed to export history"
    fi

    show_pause "Press Enter to continue..."
}

# Show statistics menu
show_statistics_menu() {
    while true; do
        clear
        show_scheduler_header

        echo "${COLOR_BOLD}Maintenance Statistics${COLOR_RESET}"
        echo "======================="
        echo

        local options=(
            "1" "View Statistics (30 days)"
            "2" "View Statistics (7 days)"
            "3" "View Statistics (90 days)"
            "4" "Performance Trends"
            "5" "Predictive Suggestions"
            "0" "Back to Main Menu"
        )

        local choice
        choice=$(show_menu "Maintenance Statistics" "Choose an option:" "${options[@]}")

        case "$choice" in
            "1")
                clear
                show_statistics "30"
                show_pause "Press Enter to continue..."
                ;;
            "2")
                clear
                show_statistics "7"
                show_pause "Press Enter to continue..."
                ;;
            "3")
                clear
                show_statistics "90"
                show_pause "Press Enter to continue..."
                ;;
            "4")
                clear
                analyze_performance_trends "30"
                show_pause "Press Enter to continue..."
                ;;
            "5")
                clear
                generate_maintenance_suggestions
                show_pause "Press Enter to continue..."
                ;;
            "0")
                break
                ;;
            *)
                show_error "Invalid option: $choice"
                show_pause "Press Enter to continue..."
                ;;
        esac
    done
}

# Show notification configuration menu
show_notification_config_menu() {
    while true; do
        clear
        show_scheduler_header

        echo "${COLOR_BOLD}Notification Configuration${COLOR_RESET}"
        echo "==========================="
        echo

        # Show current configuration
        check_notification_status
        echo

        local options=(
            "1" "Configure Notification Settings"
            "2" "Test Notifications"
            "3" "View Notification History"
            "4" "View Notification Statistics"
            "0" "Back to Main Menu"
        )

        local choice
        choice=$(show_menu "Notification Configuration" "Choose an option:" "${options[@]}")

        case "$choice" in
            "1")
                configure_notifications_interactive
                ;;
            "2")
                test_notifications
                show_pause "Press Enter to continue..."
                ;;
            "3")
                clear
                echo "${COLOR_BOLD}Notification History${COLOR_RESET}"
                echo "====================="
                get_notification_history "" "" "20"
                show_pause "Press Enter to continue..."
                ;;
            "4")
                clear
                get_notification_stats
                show_pause "Press Enter to continue..."
                ;;
            "0")
                break
                ;;
            *)
                show_error "Invalid option: $choice"
                show_pause "Press Enter to continue..."
                ;;
        esac
    done
}

# Configure notifications interactively
configure_notifications_interactive() {
    echo
    echo "${COLOR_BOLD}Configure Notifications${COLOR_RESET}"
    echo "========================="
    echo

    # Get current settings
    init_notifications

    echo "Current settings:"
    echo "  Level: $FUB_NOTIFICATION_LEVEL"
    echo "  Desktop notifications: $FUB_NOTIFICATION_DESKTOP_ENABLED"
    echo "  Email notifications: $FUB_NOTIFICATION_EMAIL_ENABLED"
    if [[ "$FUB_NOTIFICATION_EMAIL_ENABLED" == true ]]; then
        echo "  Email to: $FUB_NOTIFICATION_EMAIL_TO"
    fi
    echo

    echo "Notification levels:"
    echo "  1) DEBUG (All notifications)"
    echo "  2) INFO (Informational and above)"
    echo "  3) WARN (Warnings and above)"
    echo "  4) ERROR (Errors only)"
    echo "  5) CRITICAL (Critical errors only)"
    echo

    local level_choice
    read -p "Choose notification level (1-5, current: $FUB_NOTIFICATION_LEVEL): " level_choice

    local notification_level="$FUB_NOTIFICATION_LEVEL"
    case "$level_choice" in
        "1")
            notification_level="DEBUG"
            ;;
        "2")
            notification_level="INFO"
            ;;
        "3")
            notification_level="WARN"
            ;;
        "4")
            notification_level="ERROR"
            ;;
        "5")
            notification_level="CRITICAL"
            ;;
    esac

    local desktop_enabled="$FUB_NOTIFICATION_DESKTOP_ENABLED"
    read -p "Enable desktop notifications? (y/N, current: $desktop_enabled): " desktop_choice
    [[ "$desktop_choice" =~ ^[Yy]$ ]] && desktop_enabled="true" || desktop_enabled="false"

    local email_enabled="$FUB_NOTIFICATION_EMAIL_ENABLED"
    read -p "Enable email notifications? (y/N, current: $email_enabled): " email_choice
    [[ "$email_choice" =~ ^[Yy]$ ]] && email_enabled="true" || email_enabled="false"

    local email_to="$FUB_NOTIFICATION_EMAIL_TO"
    if [[ "$email_enabled" == true ]]; then
        read -p "Enter email address for notifications: " email_to
        if [[ -z "$email_to" ]]; then
            email_enabled="false"
        fi
    fi

    echo ""
    echo "New notification configuration:"
    echo "  Level: $notification_level"
    echo "  Desktop notifications: $desktop_enabled"
    echo "  Email notifications: $email_enabled"
    if [[ "$email_enabled" == true ]]; then
        echo "  Email to: $email_to"
    fi
    echo ""

    local confirm
    read -p "Apply these settings? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        configure_notifications "$desktop_enabled" "$email_enabled" "$email_to" "$notification_level"
        show_success "Notification configuration updated"
    else
        show_info "Configuration cancelled"
    fi

    show_pause "Press Enter to continue..."
}

# Main scheduler UI entry point
scheduler_ui_command() {
    local action="${1:-menu}"

    case "$action" in
        "menu")
            show_scheduler_menu
            ;;
        "status")
            init_scheduler_ui
            show_scheduler_status_detailed
            ;;
        "profiles")
            init_scheduler_ui
            show_profile_management_menu
            ;;
        *)
            echo "Usage: scheduler-ui [menu|status|profiles]"
            return 1
            ;;
    esac
}

# Export functions
export -f init_scheduler_ui
export -f show_scheduler_menu
export -f show_scheduler_status_detailed
export -f show_profile_management_menu
export -f enable_profile_interactive
export -f disable_profile_interactive
export -f create_profile_interactive
export -f delete_profile_interactive
export -f view_profile_details_interactive
export -f show_active_timers
export -f show_run_maintenance_menu
export -f show_history_menu
export -f view_history_by_profile
export -f view_history_by_status
export -f export_history_interactive
export -f show_statistics_menu
export -f show_notification_config_menu
export -f configure_notifications_interactive
export -f scheduler_ui_command