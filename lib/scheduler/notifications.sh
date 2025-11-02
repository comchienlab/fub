#!/usr/bin/env bash

# FUB Scheduler Logging and Notification System
# Comprehensive logging with desktop/email notifications and systemd journal integration

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# Notification system constants
readonly FUB_NOTIFICATION_DB="${HOME}/.local/share/fub/notifications.db"
readonly FUB_NOTIFICATION_CONFIG="${HOME}/.config/fub/notifications.yaml"
readonly FUB_NOTIFICATION_LOG="${FUB_LOG_DIR}/notifications.log"
readonly FUB_SYSTEMD_JOURNAL="fub-scheduler"

# Notification state
FUB_NOTIFICATION_INITIALIZED=false
FUB_NOTIFICATION_LEVEL="INFO"
FUB_NOTIFICATION_DESKTOP_ENABLED=true
FUB_NOTIFICATION_EMAIL_ENABLED=false
FUB_NOTIFICATION_EMAIL_TO=""
FUB_NOTIFICATION_EMAIL_FROM=""

# Notification types
declare -A FUB_NOTIFICATION_LEVELS
FUB_NOTIFICATION_LEVELS[DEBUG]=0
FUB_NOTIFICATION_LEVELS[INFO]=1
FUB_NOTIFICATION_LEVELS[WARN]=2
FUB_NOTIFICATION_LEVELS[ERROR]=3
FUB_NOTIFICATION_LEVELS[CRITICAL]=4

# Initialize notification system
init_notifications() {
    if [[ "$FUB_NOTIFICATION_INITIALIZED" == true ]]; then
        return 0
    fi

    log_debug "Initializing notification system"

    # Create necessary directories
    mkdir -p "$(dirname "$FUB_NOTIFICATION_DB")"
    mkdir -p "$(dirname "$FUB_NOTIFICATION_CONFIG")"
    mkdir -p "$(dirname "$FUB_NOTIFICATION_LOG")"

    # Load notification configuration
    load_notification_config

    # Initialize notification database
    if [[ ! -f "$FUB_NOTIFICATION_DB" ]]; then
        touch "$FUB_NOTIFICATION_DB"
        log_debug "Created notification database: $FUB_NOTIFICATION_DB"
    fi

    FUB_NOTIFICATION_INITIALIZED=true
    log_debug "Notification system initialized"
}

# Load notification configuration
load_notification_config() {
    # Set default values
    FUB_NOTIFICATION_LEVEL="INFO"
    FUB_NOTIFICATION_DESKTOP_ENABLED=true
    FUB_NOTIFICATION_EMAIL_ENABLED=false

    # Load from config file if it exists
    if [[ -f "$FUB_NOTIFICATION_CONFIG" ]]; then
        # Simple parsing (could be enhanced with proper YAML parser)
        if grep -q "level:" "$FUB_NOTIFICATION_CONFIG"; then
            FUB_NOTIFICATION_LEVEL=$(grep "^level:" "$FUB_NOTIFICATION_CONFIG" | cut -d' ' -f2- | tr -d '"' | tr '[:lower:]' '[:upper:]' || echo "INFO")
        fi

        if grep -q "desktop_enabled:" "$FUB_NOTIFICATION_CONFIG"; then
            FUB_NOTIFICATION_DESKTOP_ENABLED=$(grep "^desktop_enabled:" "$FUB_NOTIFICATION_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "true")
        fi

        if grep -q "email_enabled:" "$FUB_NOTIFICATION_CONFIG"; then
            FUB_NOTIFICATION_EMAIL_ENABLED=$(grep "^email_enabled:" "$FUB_NOTIFICATION_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "false")
        fi

        if grep -q "email_to:" "$FUB_NOTIFICATION_CONFIG"; then
            FUB_NOTIFICATION_EMAIL_TO=$(grep "^email_to:" "$FUB_NOTIFICATION_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "")
        fi

        if grep -q "email_from:" "$FUB_NOTIFICATION_CONFIG"; then
            FUB_NOTIFICATION_EMAIL_FROM=$(grep "^email_from:" "$FUB_NOTIFICATION_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "")
        fi
    fi

    # Override with environment variables
    FUB_NOTIFICATION_LEVEL="${FUB_NOTIFICATION_LEVEL:-INFO}"
    FUB_NOTIFICATION_DESKTOP_ENABLED="${FUB_NOTIFICATION_DESKTOP_ENABLED:-true}"
    FUB_NOTIFICATION_EMAIL_ENABLED="${FUB_NOTIFICATION_EMAIL_ENABLED:-false}"
}

# Send notification
send_notification() {
    local level="$1"
    local title="$2"
    local message="$3"
    local operation="${4:-unknown}"

    init_notifications

    # Check if level meets threshold
    local level_value="${FUB_NOTIFICATION_LEVELS[$level]:-1}"
    local threshold_value="${FUB_NOTIFICATION_LEVELS[$FUB_NOTIFICATION_LEVEL]:-1}"

    if [[ $level_value -lt $threshold_value ]]; then
        return 0  # Skip notification below threshold
    fi

    local timestamp
    timestamp=$(date -Iseconds)

    # Log to notification log file
    echo "[$timestamp] [$level] [$operation] $title: $message" >> "$FUB_NOTIFICATION_LOG"

    # Log to systemd journal
    log_to_systemd_journal "$level" "$title" "$message" "$operation"

    # Send desktop notification
    if [[ "$FUB_NOTIFICATION_DESKTOP_ENABLED" == true ]]; then
        send_desktop_notification "$level" "$title" "$message"
    fi

    # Send email notification
    if [[ "$FUB_NOTIFICATION_EMAIL_ENABLED" == true && -n "$FUB_NOTIFICATION_EMAIL_TO" ]]; then
        send_email_notification "$level" "$title" "$message" "$operation"
    fi

    # Record in notification database
    record_notification "$level" "$title" "$message" "$operation" "$timestamp"

    log_debug "Notification sent: $level - $title"
}

# Log to systemd journal
log_to_systemd_journal() {
    local level="$1"
    local title="$2"
    local message="$3"
    local operation="$4"

    # Map notification levels to systemd priorities
    local systemd_priority
    case "$level" in
        "DEBUG")
            systemd_priority="7"
            ;;
        "INFO")
            systemd_priority="6"
            ;;
        "WARN")
            systemd_priority="4"
            ;;
        "ERROR")
            systemd_priority="3"
            ;;
        "CRITICAL")
            systemd_priority="2"
            ;;
        *)
            systemd_priority="6"
            ;;
    esac

    # Use systemd-cat if available
    if command -v systemd-cat >/dev/null 2>&1; then
        echo "[$operation] $title: $message" | systemd-cat -t "$FUB_SYSTEMD_JOURNAL" -p "$systemd_priority" 2>/dev/null || true
    fi
}

# Send desktop notification
send_desktop_notification() {
    local level="$1"
    local title="$2"
    local message="$3"

    # Check if we're in a graphical session
    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        return 0  # No display available
    fi

    # Determine urgency based on level
    local urgency="normal"
    case "$level" in
        "WARN")
            urgency="normal"
            ;;
        "ERROR"|"CRITICAL")
            urgency="critical"
            ;;
        *)
            urgency="low"
            ;;
    esac

    # Use notify-send if available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -i "fub" "FUB: $title" "$message" 2>/dev/null || true
    fi

    # Use zenity as fallback for critical notifications
    if [[ "$urgency" == "critical" ]] && command -v zenity >/dev/null 2>&1; then
        zenity --warning --title="FUB: $title" --text="$message" --no-wrap 2>/dev/null || true &
    fi
}

# Send email notification
send_email_notification() {
    local level="$1"
    local title="$2"
    local message="$3"
    local operation="$4"

    # Check if email command is available
    local email_cmd=""
    if command -v mail >/dev/null 2>&1; then
        email_cmd="mail"
    elif command -v sendmail >/dev/null 2>&1; then
        email_cmd="sendmail"
    elif command -v mutt >/dev/null 2>&1; then
        email_cmd="mutt"
    fi

    if [[ -z "$email_cmd" ]]; then
        log_debug "No email command available, skipping email notification"
        return 0
    fi

    local subject="[FUB $level] $title"
    local email_body
    email_body=$(cat << EOF
FUB Scheduler Notification

Operation: $operation
Level: $level
Title: $title
Message: $message
Timestamp: $(date)

---
This notification was sent by FUB (Fast Ubuntu Utility Toolkit)
EOF
)

    # Send email
    case "$email_cmd" in
        "mail")
            echo "$email_body" | mail -s "$subject" "$FUB_NOTIFICATION_EMAIL_TO" 2>/dev/null || true
            ;;
        "mutt")
            echo "$email_body" | mutt -s "$subject" "$FUB_NOTIFICATION_EMAIL_TO" 2>/dev/null || true
            ;;
        "sendmail")
            {
                echo "To: $FUB_NOTIFICATION_EMAIL_TO"
                echo "From: ${FUB_NOTIFICATION_EMAIL_FROM:-fub@$(hostname)}"
                echo "Subject: $subject"
                echo ""
                echo "$email_body"
            } | sendmail -t 2>/dev/null || true
            ;;
    esac

    log_debug "Email notification sent: $subject"
}

# Record notification in database
record_notification() {
    local level="$1"
    local title="$2"
    local message="$3"
    local operation="$4"
    local timestamp="$5"

    # Escape special characters for database
    local escaped_title
    local escaped_message
    escaped_title=$(echo "$title" | sed 's/"/\\"/g')
    escaped_message=$(echo "$message" | sed 's/"/\\"/g')

    # Add to database
    echo "$timestamp|$level|$operation|$escaped_title|$escaped_message" >> "$FUB_NOTIFICATION_DB"
}

# Get notification history
get_notification_history() {
    local operation="${1:-}"
    local level="${2:-}"
    local limit="${3:-50}"

    if [[ ! -f "$FUB_NOTIFICATION_DB" ]]; then
        echo "No notification history found"
        return 0
    fi

    local filter="cat"
    if [[ -n "$operation" ]]; then
        filter="grep \"|$operation|\""
    fi

    if [[ -n "$level" ]]; then
        filter="$filter | grep \"|$level|\""
    fi

    eval "$filter" "$FUB_NOTIFICATION_DB" | tail -n "$limit" | while IFS='|' read -r timestamp level operation title message; do
        printf "%s  [%-8s] [%-12s] %s: %s\n" "$timestamp" "$level" "$operation" "$title" "$message"
    done
}

# Get notification statistics
get_notification_stats() {
    local days="${1:-7}"

    if [[ ! -f "$FUB_NOTIFICATION_DB" ]]; then
        echo "No notification history found"
        return 0
    fi

    local cutoff_date
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds)

    echo "Notification Statistics (last $days days):"
    echo "=========================================="

    # Total notifications
    local total
    total=$(awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff' "$FUB_NOTIFICATION_DB" | wc -l)
    echo "Total notifications: $total"

    # By level
    echo ""
    echo "By level:"
    for level in DEBUG INFO WARN ERROR CRITICAL; do
        local count
        count=$(awk -F'|' -v cutoff="$cutoff_date" -v lvl="$level" '$1 >= cutoff && $2 == lvl' "$FUB_NOTIFICATION_DB" | wc -l)
        echo "  $level: $count"
    done

    # By operation
    echo ""
    echo "Top operations:"
    awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff {print $4}' "$FUB_NOTIFICATION_DB" | \
    sort | uniq -c | sort -nr | head -5 | while read -r count operation; do
        printf "  %-20s: %d\n" "$operation" "$count"
    done

    # Recent notifications
    echo ""
    echo "Recent notifications:"
    get_notification_history "" "" "5"
}

# Test notification system
test_notifications() {
    log_info "Testing notification system"

    init_notifications

    echo "Sending test notifications..."

    # Test different notification levels
    send_notification "INFO" "Test Info" "This is a test info notification" "test"
    sleep 1
    send_notification "WARN" "Test Warning" "This is a test warning notification" "test"
    sleep 1
    send_notification "ERROR" "Test Error" "This is a test error notification" "test"

    echo "Test notifications sent. Check your desktop and logs."
}

# Configure notification settings
configure_notifications() {
    local desktop_enabled="${1:-}"
    local email_enabled="${2:-}"
    local email_to="${3:-}"
    local notification_level="${4:-}"

    log_info "Configuring notification settings"

    # Create config directory
    mkdir -p "$(dirname "$FUB_NOTIFICATION_CONFIG")"

    # Create configuration file
    cat > "$FUB_NOTIFICATION_CONFIG" << EOF
# FUB Notification Configuration

# Minimum notification level (DEBUG, INFO, WARN, ERROR, CRITICAL)
level: ${notification_level:-INFO}

# Desktop notifications
desktop_enabled: ${desktop_enabled:-true}

# Email notifications
email_enabled: ${email_enabled:-false}
email_to: "${email_to:-}"
email_from: "fub@$(hostname)"
EOF

    log_info "Notification configuration saved to: $FUB_NOTIFICATION_CONFIG"
    log_info "Reload configuration to apply changes"
}

# Check notification delivery status
check_notification_status() {
    echo "Notification System Status:"
    echo "=========================="

    init_notifications

    echo "Configuration:"
    echo "  Level: $FUB_NOTIFICATION_LEVEL"
    echo "  Desktop notifications: $FUB_NOTIFICATION_DESKTOP_ENABLED"
    echo "  Email notifications: $FUB_NOTIFICATION_EMAIL_ENABLED"
    if [[ "$FUB_NOTIFICATION_EMAIL_ENABLED" == true ]]; then
        echo "  Email to: $FUB_NOTIFICATION_EMAIL_TO"
    fi

    echo ""
    echo "Capabilities:"
    if command -v notify-send >/dev/null 2>&1; then
        echo "  ✓ Desktop notifications (notify-send)"
    else
        echo "  ✗ Desktop notifications (notify-send not found)"
    fi

    if command -v mail >/dev/null 2>&1 || command -v sendmail >/dev/null 2>&1; then
        echo "  ✓ Email notifications"
    else
        echo "  ✗ Email notifications (no email command found)"
    fi

    if command -v systemd-cat >/dev/null 2>&1; then
        echo "  ✓ Systemd journal logging"
    else
        echo "  ✗ Systemd journal logging (systemd-cat not found)"
    fi

    echo ""
    echo "Recent activity:"
    get_notification_history "" "" "5"
}

# Cleanup old notifications
cleanup_notifications() {
    local days="${1:-30}"

    log_info "Cleaning up notifications older than $days days"

    if [[ ! -f "$FUB_NOTIFICATION_DB" ]]; then
        return 0
    fi

    local cutoff_date
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds)

    # Create temporary file with recent entries
    local temp_file
    temp_file=$(mktemp)
    awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff' "$FUB_NOTIFICATION_DB" > "$temp_file"

    # Replace original file
    mv "$temp_file" "$FUB_NOTIFICATION_DB"

    log_info "Notification cleanup completed"
}

# Export functions
export -f init_notifications
export -f load_notification_config
export -f send_notification
export -f log_to_systemd_journal
export -f send_desktop_notification
export -f send_email_notification
export -f record_notification
export -f get_notification_history
export -f get_notification_stats
export -f test_notifications
export -f configure_notifications
export -f check_notification_status
export -f cleanup_notifications