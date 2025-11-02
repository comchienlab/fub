#!/usr/bin/env bash

# FUB Performance Alert System
# Intelligent notifications for system performance issues

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "${FUB_SCRIPT_DIR}/lib/common.sh"
    source "${FUB_SCRIPT_DIR}/lib/ui.sh"
    source "${FUB_SCRIPT_DIR}/lib/config.sh"
    source "${FUB_SCRIPT_DIR}/lib/monitoring/performance-monitor.sh"
fi

# Alert system constants
readonly ALERT_SYSTEM_VERSION="1.0.0"
readonly ALERT_CACHE_DIR="${FUB_CACHE_DIR}/alerts"
readonly ALERT_HISTORY_FILE="${ALERT_CACHE_DIR}/history.json"
readonly ALERT_RULES_FILE="${ALERT_CACHE_DIR}/rules.json"

# Default alert thresholds
ALERT_CPU_WARNING=${ALERT_CPU_WARNING:-80}
ALERT_CPU_CRITICAL=${ALERT_CPU_CRITICAL:-95}
ALERT_MEMORY_WARNING=${ALERT_MEMORY_WARNING:-80}
ALERT_MEMORY_CRITICAL=${ALERT_MEMORY_CRITICAL:-90}
ALERT_DISK_WARNING=${ALERT_DISK_WARNING:-85}
ALERT_DISK_CRITICAL=${ALERT_DISK_CRITICAL:-95}
ALERT_LOAD_WARNING=${ALERT_LOAD_WARNING:-2.0}
ALERT_IO_WAIT_CRITICAL=${ALERT_IO_WAIT_CRITICAL:-20}

# Alert configuration
ALERT_ENABLED=${ALERT_ENABLED:-true}
ALERT_COOLDOWN_MINUTES=${ALERT_COOLDOWN_MINUTES:-5}
ALERT_MAX_HISTORY=${ALERT_MAX_HISTORY:-1000}

# Initialize alert system
init_alert_system() {
    mkdir -p "$ALERT_CACHE_DIR"

    # Initialize alert history
    if [[ ! -f "$ALERT_HISTORY_FILE" ]]; then
        echo '{"alerts": []}' > "$ALERT_HISTORY_FILE"
    fi

    # Initialize alert rules
    if [[ ! -f "$ALERT_RULES_FILE" ]]; then
        create_default_alert_rules
    fi

    log_debug "Alert system initialized"
}

# Create default alert rules
create_default_alert_rules() {
    cat > "$ALERT_RULES_FILE" << EOF
{
  "rules": [
    {
      "id": "cpu_warning",
      "name": "High CPU Usage Warning",
      "type": "threshold",
      "metric": "cpu_usage",
      "operator": ">",
      "threshold": $ALERT_CPU_WARNING,
      "severity": "warning",
      "enabled": true,
      "cooldown_minutes": $ALERT_COOLDOWN_MINUTES,
      "message": "CPU usage is high: {{value}}%",
      "recommendation": "Check for CPU-intensive processes"
    },
    {
      "id": "cpu_critical",
      "name": "Critical CPU Usage",
      "type": "threshold",
      "metric": "cpu_usage",
      "operator": ">",
      "threshold": $ALERT_CPU_CRITICAL,
      "severity": "critical",
      "enabled": true,
      "cooldown_minutes": 2,
      "message": "CRITICAL: CPU usage is extremely high: {{value}}%",
      "recommendation": "Immediately investigate CPU usage or system may become unresponsive"
    },
    {
      "id": "memory_warning",
      "name": "High Memory Usage Warning",
      "type": "threshold",
      "metric": "memory_usage",
      "operator": ">",
      "threshold": $ALERT_MEMORY_WARNING,
      "severity": "warning",
      "enabled": true,
      "cooldown_minutes": $ALERT_COOLDOWN_MINUTES,
      "message": "Memory usage is high: {{value}}%",
      "recommendation": "Close memory-intensive applications or add more RAM"
    },
    {
      "id": "memory_critical",
      "name": "Critical Memory Usage",
      "type": "threshold",
      "metric": "memory_usage",
      "operator": ">",
      "threshold": $ALERT_MEMORY_CRITICAL,
      "severity": "critical",
      "enabled": true,
      "cooldown_minutes": 2,
      "message": "CRITICAL: Memory usage is extremely high: {{value}}%",
      "recommendation": "System may become unstable, free memory immediately"
    },
    {
      "id": "disk_warning",
      "name": "High Disk Usage Warning",
      "type": "threshold",
      "metric": "disk_usage",
      "operator": ">",
      "threshold": $ALERT_DISK_WARNING,
      "severity": "warning",
      "enabled": true,
      "cooldown_minutes": 10,
      "message": "Disk usage is high: {{value}}%",
      "recommendation": "Clean up unnecessary files or expand storage"
    },
    {
      "id": "disk_critical",
      "name": "Critical Disk Usage",
      "type": "threshold",
      "metric": "disk_usage",
      "operator": ">",
      "threshold": $ALERT_DISK_CRITICAL,
      "severity": "critical",
      "enabled": true,
      "cooldown_minutes": 5,
      "message": "CRITICAL: Disk usage is extremely high: {{value}}%",
      "recommendation": "System may fail, free disk space immediately"
    },
    {
      "id": "load_average_high",
      "name": "High Load Average",
      "type": "threshold",
      "metric": "load_average",
      "operator": ">",
      "threshold": $ALERT_LOAD_WARNING,
      "severity": "warning",
      "enabled": true,
      "cooldown_minutes": $ALERT_COOLDOWN_MINUTES,
      "message": "System load is high: {{value}}",
      "recommendation": "Check for runaway processes or system overload"
    },
    {
      "id": "io_wait_high",
      "name": "High I/O Wait",
      "type": "threshold",
      "metric": "io_wait",
      "operator": ">",
      "threshold": $ALERT_IO_WAIT_CRITICAL,
      "severity": "warning",
      "enabled": true,
      "cooldown_minutes": 5,
      "message": "I/O wait is high: {{value}}%",
      "recommendation": "Check for disk bottlenecks or storage issues"
    }
  ]
}
EOF

    log_debug "Default alert rules created"
}

# Check if alert is in cooldown period
is_alert_in_cooldown() {
    local alert_id="$1"
    local cooldown_minutes="$2"

    local last_alert_time
    last_alert_time=$(grep -o "\"alert_id\": \"$alert_id\"" "$ALERT_HISTORY_FILE" | tail -1 | A=1 2>/dev/null || echo "")

    if [[ -z "$last_alert_time" ]]; then
        return 1  # No previous alert
    fi

    # Extract timestamp from the last alert (simplified approach)
    local timestamp_pattern
    timestamp_pattern=$(grep -B2 "\"alert_id\": \"$alert_id\"" "$ALERT_HISTORY_FILE" | grep "\"timestamp\":" | tail -1 | cut -d'"' -f4 2>/dev/null || echo "")

    if [[ -z "$timestamp_pattern" ]]; then
        return 1  # No timestamp found
    fi

    # Convert to epoch time and check cooldown
    local last_alert_epoch
    last_alert_epoch=$(date -d "$timestamp_pattern" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp_pattern" +%s 2>/dev/null || echo "0")
    local current_epoch
    current_epoch=$(date +%s)
    local cooldown_seconds=$((cooldown_minutes * 60))
    local time_since_alert=$((current_epoch - last_alert_epoch))

    [[ $time_since_alert -lt $cooldown_seconds ]]
}

# Format alert message with metrics
format_alert_message() {
    local message_template="$1"
    local value="$2"

    # Simple template replacement
    echo "${message_template/\{\{value\}\}/$value}"
}

# Create alert object
create_alert() {
    local rule_id="$1"
    local rule_name="$2"
    local severity="$3"
    local message="$4"
    local recommendation="$5"
    local metric_value="$6"
    local metric_name="$7"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat << EOF
{
  "id": "$(date +%s)_${rule_id}",
  "timestamp": "$timestamp",
  "rule_id": "$rule_id",
  "rule_name": "$rule_name",
  "severity": "$severity",
  "message": "$message",
  "recommendation": "$recommendation",
  "metric": {
    "name": "$metric_name",
    "value": "$metric_value"
  },
  "acknowledged": false
}
EOF
}

# Save alert to history
save_alert() {
    local alert="$1"

    # Create temporary file for updated history
    local temp_file
    temp_file=$(mktemp)

    # Read existing history and add new alert
    if [[ -f "$ALERT_HISTORY_FILE" ]]; then
        # Remove closing bracket and add comma
        sed '$ s/}]$/,/' "$ALERT_HISTORY_FILE" > "$temp_file"
        echo "$alert" >> "$temp_file"
        echo ']}' >> "$temp_file"
    else
        echo '{"alerts": [' > "$temp_file"
        echo "$alert" >> "$temp_file"
        echo ']}' >> "$temp_file"
    fi

    # Rotate history if too long
    local alert_count
    alert_count=$(grep -c '"id":' "$temp_file" 2>/dev/null || echo "0")
    if [[ $alert_count -gt $ALERT_MAX_HISTORY ]]; then
        # Keep only recent alerts (simplified approach)
        tail -n "$ALERT_MAX_HISTORY" "$temp_file" > "${temp_file}.new"
        mv "${temp_file}.new" "$temp_file"
    fi

    mv "$temp_file" "$ALERT_HISTORY_FILE"
    log_debug "Alert saved to history"
}

# Check and trigger alerts based on metrics
check_alerts() {
    if [[ "$ALERT_ENABLED" != "true" ]]; then
        return 0
    fi

    local metrics="$1"

    if [[ -z "$metrics" || ! -f "$ALERT_RULES_FILE" ]]; then
        log_debug "No metrics or rules available for alert checking"
        return 0
    fi

    # Extract metric values
    local cpu_usage
    local memory_usage
    local disk_usage
    local load_average
    local io_wait

    cpu_usage=$(echo "$metrics" | grep -o '"usage_percent": [0-9.]*' | head -1 | cut -d: -f2 | tr -d ' ')
    memory_usage=$(echo "$metrics" | grep -A2 '"memory":' | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    disk_usage=$(echo "$metrics" | grep -A4 '"disk":' | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    load_average=$(echo "$metrics" | grep '"load_average":' | cut -d'"' -f4 | tr -d ' "')
    io_wait=$(echo "$metrics" | grep '"wait_percent":' | cut -d: -f2 | tr -d ' ,')

    # Read and process rules (simplified approach)
    local temp_rules
    temp_rules=$(mktemp)
    grep -A10 '"type": "threshold"' "$ALERT_RULES_FILE" > "$temp_rules" 2>/dev/null || true

    # Check each rule (simplified logic for demonstration)
    while IFS= read -r rule_line; do
        if [[ "$rule_line" == *"id":"* ]]; then
            local rule_id
            rule_id=$(echo "$rule_line" | cut -d'"' -f4)

            # Get rule details (this is simplified - in practice you'd use proper JSON parsing)
            local threshold
            local metric
            local operator
            local severity
            local message_template
            local recommendation
            local cooldown_minutes

            # Extract rule properties (simplified)
            threshold=$(grep -A5 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"threshold":' | cut -d: -f2 | tr -d ' ,')
            metric=$(grep -A5 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"metric":' | cut -d'"' -f4)
            operator=$(grep -A5 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"operator":' | cut -d'"' -f4)
            severity=$(grep -A5 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"severity":' | cut -d'"' -f4)
            message_template=$(grep -A10 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"message":' | cut -d'"' -f4)
            recommendation=$(grep -A10 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"recommendation":' | cut -d'"' -f4)
            cooldown_minutes=$(grep -A10 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"cooldown_minutes":' | cut -d: -f2 | tr -d ' ,')

            # Get current metric value
            local current_value=""
            case "$metric" in
                "cpu_usage") current_value="$cpu_usage" ;;
                "memory_usage") current_value="$memory_usage" ;;
                "disk_usage") current_value="$disk_usage" ;;
                "load_average") current_value="$load_average" ;;
                "io_wait") current_value="$io_wait" ;;
            esac

            if [[ -n "$current_value" && -n "$threshold" ]]; then
                # Check threshold (simplified comparison)
                local triggered=false
                if [[ "$operator" == ">" ]]; then
                    if (( $(echo "$current_value > $threshold" | bc -l 2>/dev/null || echo "0") )); then
                        triggered=true
                    fi
                fi

                if [[ "$triggered" == "true" ]]; then
                    # Check cooldown
                    if ! is_alert_in_cooldown "$rule_id" "${cooldown_minutes:-$ALERT_COOLDOWN_MINUTES}"; then
                        # Create and trigger alert
                        local rule_name
                        rule_name=$(grep -A5 "\"id\": \"$rule_id\"" "$ALERT_RULES_FILE" | grep '"name":' | cut -d'"' -f4)

                        local formatted_message
                        formatted_message=$(format_alert_message "${message_template:-'Metric exceeded threshold'}" "$current_value")

                        local alert
                        alert=$(create_alert "$rule_id" "${rule_name:-$rule_id}" "${severity:-warning}" "$formatted_message" "${recommendation:-'Check system metrics'}" "$current_value" "$metric")

                        # Save alert
                        save_alert "$alert"

                        # Log alert
                        log_warn "ALERT: $formatted_message"

                        # Display alert if interactive
                        if [[ -t 1 ]]; then
                            display_alert "$alert"
                        fi
                    fi
                fi
            fi
        fi
    done < "$temp_rules"

    rm -f "$temp_rules"
}

# Display alert to user
display_alert() {
    local alert="$1"

    local severity
    local message
    local recommendation

    severity=$(echo "$alert" | grep '"severity":' | cut -d'"' -f4)
    message=$(echo "$alert" | grep '"message":' | cut -d'"' -f4)
    recommendation=$(echo "$alert" | grep '"recommendation":' | cut -d'"' -f4)

    case "$severity" in
        "critical")
            echo "$(ui_set_color red)⚠️  CRITICAL: $message$(ui_reset_color)"
            echo "$(ui_set_color yellow)💡 Recommendation: $recommendation$(ui_reset_color)"
            ;;
        "warning")
            echo "$(ui_set_color yellow)⚡ WARNING: $message$(ui_reset_color)"
            echo "$(ui_set_color dim)💡 Recommendation: $recommendation$(ui_reset_color)"
            ;;
        "info")
            echo "$(ui_set_color blue)ℹ️  INFO: $message$(ui_reset_color)"
            ;;
    esac
}

# Get recent alerts
get_recent_alerts() {
    local hours="${1:-24}"

    local since_timestamp
    since_timestamp=$(date -d "$hours hours ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${hours}H -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ ! -f "$ALERT_HISTORY_FILE" ]]; then
        echo '{"alerts": []}'
        return
    fi

    # Extract recent alerts (simplified approach)
    local recent_alerts
    recent_alerts=$(mktemp)

    echo '{"recent_alerts": [' > "$recent_alerts"

    # This is a simplified extraction - in practice you'd use proper JSON parsing
    grep -B1 -A10 "$since_timestamp" "$ALERT_HISTORY_FILE" >> "$recent_alerts" 2>/dev/null || true

    echo ']}' >> "$recent_alerts"

    cat "$recent_alerts"
    rm -f "$recent_alerts"
}

# Acknowledge alert
acknowledge_alert() {
    local alert_id="$1"

    if [[ ! -f "$ALERT_HISTORY_FILE" ]]; then
        log_error "Alert history file not found"
        return 1
    fi

    # Mark alert as acknowledged (simplified approach)
    local temp_file
    temp_file=$(mktemp)

    sed "s/\"id\": \"$alert_id\"/\"id\": \"$alert_id\", \"acknowledged\": true/" "$ALERT_HISTORY_FILE" > "$temp_file"
    mv "$temp_file" "$ALERT_HISTORY_FILE"

    log_info "Alert $alert_id acknowledged"
}

# Clear old alerts
clear_old_alerts() {
    local days="${1:-30}"

    local cutoff_timestamp
    cutoff_timestamp=$(date -d "$days days ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${days}d -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ ! -f "$ALERT_HISTORY_FILE" ]]; then
        return
    fi

    # Filter out old alerts (simplified approach)
    local temp_file
    temp_file=$(mktemp)

    # Keep only recent alerts
    grep "$cutoff_timestamp" "$ALERT_HISTORY_FILE" > "$temp_file" 2>/dev/null || echo '{"alerts": []}' > "$temp_file"

    mv "$temp_file" "$ALERT_HISTORY_FILE"
    log_info "Cleared alerts older than $days days"
}

# Get alert summary
get_alert_summary() {
    local hours="${1:-24}"

    if [[ ! -f "$ALERT_HISTORY_FILE" ]]; then
        echo '{"total": 0, "critical": 0, "warning": 0, "info": 0}'
        return
    fi

    local total_alerts
    local critical_alerts
    local warning_alerts
    local info_alerts

    # Count alerts by severity (simplified approach)
    total_alerts=$(grep -c '"severity":' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")
    critical_alerts=$(grep -c '"severity": "critical"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")
    warning_alerts=$(grep -c '"severity": "warning"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")
    info_alerts=$(grep -c '"severity": "info"' "$ALERT_HISTORY_FILE" 2>/dev/null || echo "0")

    cat << EOF
{
  "period_hours": $hours,
  "total": $total_alerts,
  "critical": $critical_alerts,
  "warning": $warning_alerts,
  "info": $info_alerts
}
EOF
}

# Initialize module
init_alert_system