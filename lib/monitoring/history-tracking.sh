#!/usr/bin/env bash

# FUB History Tracking Module
# Maintains historical database of cleanup operations and system performance

set -euo pipefail

# Source dependencies if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "${FUB_SCRIPT_DIR}/lib/common.sh"
    source "${FUB_SCRIPT_DIR}/lib/ui.sh"
    source "${FUB_SCRIPT_DIR}/lib/config.sh"
fi

# History tracking constants
readonly HISTORY_TRACKING_VERSION="1.0.0"
readonly HISTORY_CACHE_DIR="${FUB_CACHE_DIR}/history"
readonly HISTORY_DB_FILE="${HISTORY_CACHE_DIR}/cleanup-history.json"
readonly HISTORY_PERFORMANCE_FILE="${HISTORY_CACHE_DIR}/performance-history.json"
readonly HISTORY_SUMMARY_FILE="${HISTORY_CACHE_DIR}/summary.json"

# History configuration
HISTORY_MAX_ENTRIES=${HISTORY_MAX_ENTRIES:-1000}
HISTORY_RETENTION_DAYS=${HISTORY_RETENTION_DAYS:-90}
HISTORY_AUTO_ROTATE=${HISTORY_AUTO_ROTATE:-true}

# Initialize history tracking
init_history_tracking() {
    mkdir -p "$HISTORY_CACHE_DIR"

    # Initialize database files
    if [[ ! -f "$HISTORY_DB_FILE" ]]; then
        echo '{"cleanup_operations": []}' > "$HISTORY_DB_FILE"
    fi

    if [[ ! -f "$HISTORY_PERFORMANCE_FILE" ]]; then
        echo '{"performance_snapshots": []}' > "$HISTORY_PERFORMANCE_FILE"
    fi

    log_debug "History tracking initialized"
}

# Record cleanup operation
record_cleanup_operation() {
    local operation_type="$1"
    local operation_id="$2"
    local before_state="$3"
    local after_state="$4"
    local duration="$5"
    local status="$6"
    local details="$7"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Calculate space savings and performance changes
    local space_saved
    local performance_change
    space_saved=$(calculate_space_savings "$before_state" "$after_state")
    performance_change=$(calculate_performance_change "$before_state" "$after_state")

    local operation_record
    operation_record=$(cat << EOF
{
  "operation_id": "$operation_id",
  "timestamp": "$timestamp",
  "operation_type": "$operation_type",
  "duration_seconds": $duration,
  "status": "$status",
  "before_state": $before_state,
  "after_state": $after_state,
  "impact": {
    "space_saved_mb": $space_saved,
    "performance_change": $performance_change
  },
  "details": $details
}
EOF
)

    # Add to history database
    add_to_history_db "$operation_record"

    # Update summary statistics
    update_history_summary

    log_debug "Cleanup operation recorded: $operation_id"
    echo "$operation_record"
}

# Calculate space savings
calculate_space_savings() {
    local before_state="$1"
    local after_state="$2"

    # Extract disk usage from before/after states
    local before_disk
    local after_disk

    before_disk=$(echo "$before_state" | grep -A4 '"disk":' | grep '"used":' | cut -d'"' -f4 | sed 's/[^0-9.]//g' 2>/dev/null || echo "0")
    after_disk=$(echo "$after_state" | grep -A4 '"disk":' | grep '"used":' | cut -d'"' -f4 | sed 's/[^0-9.]//g' 2>/dev/null || echo "0")

    # Convert to MB (simplified - assumes GB input)
    local before_mb
    local after_mb
    before_mb=$(echo "$before_disk" | awk '{print $1 * 1024}')
    after_mb=$(echo "$after_disk" | awk '{print $1 * 1024}')

    local saved_mb
    saved_mb=$(echo "$before_mb $after_mb" | awk '{printf "%.0f", $1 - $2}')

    echo "$saved_mb"
}

# Calculate performance change
calculate_performance_change() {
    local before_state="$1"
    local after_state="$2"

    # Extract CPU and memory usage
    local before_cpu
    local after_cpu
    local before_memory
    local after_memory

    before_cpu=$(echo "$before_state" | grep -o '"usage_percent": [0-9.]*' | head -1 | cut -d: -f2 | tr -d ' ')
    after_cpu=$(echo "$after_state" | grep -o '"usage_percent": [0-9.]*' | head -1 | cut -d: -f2 | tr -d ' ')

    before_memory=$(echo "$before_state" | grep -A2 '"memory":' | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')
    after_memory=$(echo "$after_state" | grep -A2 '"memory":' | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')

    # Calculate average improvement
    local cpu_change
    local memory_change
    cpu_change=$(echo "$before_cpu $after_cpu" | awk '{printf "%.1f", $1 - $2}')
    memory_change=$(echo "$before_memory $after_memory" | awk '{printf "%.1f", $1 - $2}')

    local avg_change
    avg_change=$(echo "$cpu_change $memory_change" | awk '{printf "%.1f", ($1 + $2) / 2}')

    echo "$avg_change"
}

# Add record to history database
add_to_history_db() {
    local record="$1"

    local temp_file
    temp_file=$(mktemp)

    # Read existing database and add new record
    if [[ -f "$HISTORY_DB_FILE" ]]; then
        # Remove closing bracket and add comma
        sed '$ s/}]$/,/' "$HISTORY_DB_FILE" > "$temp_file"
        echo "$record" >> "$temp_file"
        echo ']}' >> "$temp_file"
    else
        echo '{"cleanup_operations": [' > "$temp_file"
        echo "$record" >> "$temp_file"
        echo ']}' >> "$temp_file"
    fi

    # Check if rotation is needed
    if [[ "$HISTORY_AUTO_ROTATE" == "true" ]]; then
        local entry_count
        entry_count=$(grep -c '"operation_id":' "$temp_file" 2>/dev/null || echo "0")

        if [[ $entry_count -gt $HISTORY_MAX_ENTRIES ]]; then
            # Keep only the most recent entries
            tail -n "$HISTORY_MAX_ENTRIES" "$temp_file" > "${temp_file}.rotated"
            mv "${temp_file}.rotated" "$temp_file"
        fi
    fi

    mv "$temp_file" "$HISTORY_DB_FILE"
}

# Record performance snapshot
record_performance_snapshot() {
    local operation_id="$1"
    local timestamp="$2"
    local metrics="$3"

    local snapshot_record
    snapshot_record=$(cat << EOF
{
  "operation_id": "$operation_id",
  "timestamp": "$timestamp",
  "metrics": $metrics
}
EOF
)

    # Add to performance history
    local temp_file
    temp_file=$(mktemp)

    if [[ -f "$HISTORY_PERFORMANCE_FILE" ]]; then
        sed '$ s/}]$/,/' "$HISTORY_PERFORMANCE_FILE" > "$temp_file"
        echo "$snapshot_record" >> "$temp_file"
        echo ']}' >> "$temp_file"
    else
        echo '{"performance_snapshots": [' > "$temp_file"
        echo "$snapshot_record" >> "$temp_file"
        echo ']}' >> "$temp_file"
    fi

    mv "$temp_file" "$HISTORY_PERFORMANCE_FILE"
}

# Get cleanup history
get_cleanup_history() {
    local days="${1:-30}"
    local operation_type="${2:-}"

    local since_timestamp
    since_timestamp=$(date -d "$days days ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${days}d -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ ! -f "$HISTORY_DB_FILE" ]]; then
        echo '{"operations": []}'
        return
    fi

    # Extract recent operations (simplified approach)
    local recent_ops
    recent_ops=$(mktemp)

    echo '{"operations": [' > "$recent_ops"

    # Filter by date and type if specified
    if [[ -n "$operation_type" ]]; then
        grep -A20 "$since_timestamp" "$HISTORY_DB_FILE" | grep -A20 "\"operation_type\": \"$operation_type\"" >> "$recent_ops" 2>/dev/null || true
    else
        grep -A20 "$since_timestamp" "$HISTORY_DB_FILE" >> "$recent_ops" 2>/dev/null || true
    fi

    # Clean up the output
    sed -i '' '1d;$d' "$recent_ops" 2>/dev/null || true
    sed -i '' 's/,$//' "$recent_ops" 2>/dev/null || true

    echo ']}' >> "$recent_ops"

    cat "$recent_ops"
    rm -f "$recent_ops"
}

# Get performance trends
get_performance_trends() {
    local days="${1:-7}"

    if [[ ! -f "$HISTORY_PERFORMANCE_FILE" ]]; then
        echo '{"trends": "No performance data available"}'
        return
    fi

    # This is a simplified trend analysis
    # In a full implementation, you'd do more sophisticated statistical analysis
    local cpu_trend="stable"
    local memory_trend="stable"
    local disk_trend="stable"

    # Extract recent performance data
    local recent_data
    recent_data=$(tail -n 50 "$HISTORY_PERFORMANCE_FILE" 2>/dev/null || echo "")

    if [[ -n "$recent_data" ]]; then
        # Simple trend detection (would be more sophisticated in practice)
        local cpu_values
        cpu_values=$(echo "$recent_data" | grep -o '"usage_percent": [0-9.]*' | head -10 | cut -d: -f2 | tr -d ' ')

        if [[ -n "$cpu_values" ]]; then
            # Calculate trend
            local first_cpu
            local last_cpu
            first_cpu=$(echo "$cpu_values" | head -1)
            last_cpu=$(echo "$cpu_values" | tail -1)

            if (( $(echo "$last_cpu > $first_cpu + 5" | bc -l 2>/dev/null || echo "0") )); then
                cpu_trend="increasing"
            elif (( $(echo "$first_cpu > $last_cpu + 5" | bc -l 2>/dev/null || echo "0") )); then
                cpu_trend="decreasing"
            fi
        fi
    fi

    cat << EOF
{
  "period_days": $days,
  "trends": {
    "cpu": "$cpu_trend",
    "memory": "$memory_trend",
    "disk": "$disk_trend"
  }
}
EOF
}

# Update history summary statistics
update_history_summary() {
    if [[ ! -f "$HISTORY_DB_FILE" ]]; then
        return
    fi

    local total_operations
    local successful_operations
    local failed_operations
    local total_space_saved
    local total_duration

    # Count operations
    total_operations=$(grep -c '"operation_id":' "$HISTORY_DB_FILE" 2>/dev/null || echo "0")
    successful_operations=$(grep -c '"status": "success"' "$HISTORY_DB_FILE" 2>/dev/null || echo "0")
    failed_operations=$(grep -c '"status": "failed"' "$HISTORY_DB_FILE" 2>/dev/null || echo "0")

    # Sum space saved and duration
    total_space_saved=$(grep '"space_saved_mb":' "$HISTORY_DB_FILE" | awk '{sum += $2} END {print sum}' 2>/dev/null || echo "0")
    total_duration=$(grep '"duration_seconds":' "$HISTORY_DB_FILE" | awk '{sum += $2} END {print sum}' 2>/dev/null || echo "0")

    # Generate summary
    local summary
    summary=$(cat << EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "operations": {
    "total": $total_operations,
    "successful": $successful_operations,
    "failed": $failed_operations,
    "success_rate": $(echo "$successful_operations $total_operations" | awk '{if($2 > 0) printf "%.1f", ($1/$2)*100; else print "0"}')
  },
  "impact": {
    "total_space_saved_mb": $total_space_saved,
    "total_duration_seconds": $total_duration,
    "average_duration_seconds": $(echo "$successful_operations $total_duration" | awk '{if($1 > 0) printf "%.1f", $2/$1; else print "0"}')
  }
}
EOF
)

    echo "$summary" > "$HISTORY_SUMMARY_FILE"
}

# Get history summary
get_history_summary() {
    if [[ ! -f "$HISTORY_SUMMARY_FILE" ]]; then
        update_history_summary
    fi

    cat "$HISTORY_SUMMARY_FILE"
}

# Cleanup old history
cleanup_old_history() {
    local days="${1:-$HISTORY_RETENTION_DAYS}"

    local cutoff_timestamp
    cutoff_timestamp=$(date -d "$days days ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${days}d -u +"%Y-%m-%dT%H:%M:%SZ")

    # Cleanup cleanup history
    if [[ -f "$HISTORY_DB_FILE" ]]; then
        local temp_file
        temp_file=$(mktemp)

        # Keep only recent entries
        grep -A50 "$cutoff_timestamp" "$HISTORY_DB_FILE" > "$temp_file" 2>/dev/null || echo '{"cleanup_operations": []}' > "$temp_file"

        mv "$temp_file" "$HISTORY_DB_FILE"
    fi

    # Cleanup performance history
    if [[ -f "$HISTORY_PERFORMANCE_FILE" ]]; then
        local temp_file
        temp_file=$(mktemp)

        grep -A20 "$cutoff_timestamp" "$HISTORY_PERFORMANCE_FILE" > "$temp_file" 2>/dev/null || echo '{"performance_snapshots": []}' > "$temp_file"

        mv "$temp_file" "$HISTORY_PERFORMANCE_FILE"
    fi

    log_info "Cleaned history older than $days days"
}

# Export history data
export_history() {
    local format="${1:-json}"
    local output_file="$2"

    local export_data
    case "$format" in
        "json")
            export_data=$(cat << EOF
{
  "exported_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "cleanup_history": $(cat "$HISTORY_DB_FILE" 2>/dev/null || echo '{"cleanup_operations": []}'),
  "performance_history": $(cat "$HISTORY_PERFORMANCE_FILE" 2>/dev/null || echo '{"performance_snapshots": []}'),
  "summary": $(get_history_summary)
}
EOF
            ;;
        "csv")
            # Simplified CSV export
            export_data="operation_id,timestamp,operation_type,duration,status,space_saved_mb\n"
            export_data+=$(grep -A2 '"operation_id":' "$HISTORY_DB_FILE" | grep -E '"operation_id"|"timestamp"|"operation_type"|"duration"|"status"|"space_saved_mb"' | paste - - - - - - | sed 's/"//g; s/, /,/g' 2>/dev/null || echo "No data available")
            ;;
        *)
            log_error "Unsupported export format: $format"
            return 1
            ;;
    esac

    if [[ -n "$output_file" ]]; then
        echo -e "$export_data" > "$output_file"
        log_info "History exported to $output_file"
    else
        echo -e "$export_data"
    fi
}

# Generate predictive maintenance suggestions
generate_maintenance_suggestions() {
    local suggestions_file="${HISTORY_CACHE_DIR}/suggestions.json"

    # Analyze history patterns
    local summary
    summary=$(get_history_summary)

    local suggestions="[]"

    # Generate suggestions based on patterns
    if [[ -f "$HISTORY_DB_FILE" ]]; then
        # Check cleanup frequency
        local recent_cleanups
        recent_cleanups=$(grep -c "$(date -d '7 days ago' -u '+%Y-%m-%d')" "$HISTORY_DB_FILE" 2>/dev/null || echo "0")

        if [[ $recent_cleanups -lt 1 ]]; then
            suggestions=$(add_suggestion "$suggestions" "low_cleanup_frequency" "Consider running weekly cleanup to maintain system performance")
        fi

        # Check space saving patterns
        local avg_space_saved
        avg_space_saved=$(grep '"space_saved_mb":' "$HISTORY_DB_FILE" | awk '{sum += $2; count++} END {if(count > 0) print sum/count; else print 0}')

        if (( $(echo "$avg_space_saved < 100" | bc -l 2>/dev/null || echo "0") )); then
            suggestions=$(add_suggestion "$suggestions" "low_space_savings" "Space savings are below average. Consider reviewing cleanup targets")
        fi
    fi

    cat << EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "suggestions": $suggestions
}
EOF
}

# Add suggestion to array
add_suggestion() {
    local existing="$1"
    local type="$2"
    local message="$3"

    if [[ "$existing" == "[]" ]]; then
        cat << EOF
[
  {
    "type": "$type",
    "message": "$message",
    "priority": "medium"
  }
]
EOF
    else
        # Remove closing bracket and add new suggestion
        echo "${existing%?]}" | sed '$ s/$/,/' && cat << EOF
  {
    "type": "$type",
    "message": "$message",
    "priority": "medium"
  }
]
EOF
    fi
}

# Initialize module
init_history_tracking