#!/usr/bin/env bash

# FUB Maintenance History Tracking System
# Historical data about scheduled operations with performance analysis and predictive maintenance

set -euo pipefail

# Source parent libraries
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_SCRIPT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
fi

# History system constants
readonly FUB_HISTORY_DB="${HOME}/.local/share/fub/maintenance_history.db"
readonly FUB_HISTORY_CONFIG="${HOME}/.config/fub/history.yaml"
readonly FUB_HISTORY_ANALYSIS="${HOME}/.local/share/fub/analysis"
readonly FUB_HISTORY_STATS="${FUB_HISTORY_ANALYSIS}/stats"

# History state
FUB_HISTORY_INITIALIZED=false
FUB_HISTORY_RETENTION_DAYS=90
FUB_HISTORY_ANALYSIS_ENABLED=true

# Initialize history system
init_history() {
    if [[ "$FUB_HISTORY_INITIALIZED" == true ]]; then
        return 0
    fi

    log_debug "Initializing maintenance history system"

    # Create necessary directories
    mkdir -p "$(dirname "$FUB_HISTORY_DB")"
    mkdir -p "$(dirname "$FUB_HISTORY_CONFIG")"
    mkdir -p "$FUB_HISTORY_ANALYSIS"
    mkdir -p "$FUB_HISTORY_STATS"

    # Load history configuration
    load_history_config

    # Initialize history database if it doesn't exist
    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        create_history_database
        log_debug "Created history database: $FUB_HISTORY_DB"
    fi

    # Run maintenance on history data
    cleanup_old_history_records

    FUB_HISTORY_INITIALIZED=true
    log_debug "History system initialized"
}

# Load history configuration
load_history_config() {
    # Set default values
    FUB_HISTORY_RETENTION_DAYS=90
    FUB_HISTORY_ANALYSIS_ENABLED=true

    # Load from config file if it exists
    if [[ -f "$FUB_HISTORY_CONFIG" ]]; then
        if grep -q "retention_days:" "$FUB_HISTORY_CONFIG"; then
            FUB_HISTORY_RETENTION_DAYS=$(grep "^retention_days:" "$FUB_HISTORY_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "90")
        fi

        if grep -q "analysis_enabled:" "$FUB_HISTORY_CONFIG"; then
            FUB_HISTORY_ANALYSIS_ENABLED=$(grep "^analysis_enabled:" "$FUB_HISTORY_CONFIG" | cut -d' ' -f2- | tr -d '"' || echo "true")
        fi
    fi

    # Override with environment variables
    FUB_HISTORY_RETENTION_DAYS="${FUB_HISTORY_RETENTION_DAYS:-90}"
    FUB_HISTORY_ANALYSIS_ENABLED="${FUB_HISTORY_ANALYSIS_ENABLED:-true}"
}

# Create history database with schema
create_history_database() {
    # Create CSV header for maintenance history
    cat > "$FUB_HISTORY_DB" << 'EOF'
timestamp|operation_type|profile|status|duration|space_freed|files_processed|error_count|system_load|memory_usage|trigger|details
EOF
}

# Record maintenance operation
record_maintenance_operation() {
    local operation_type="$1"
    local profile="$2"
    local status="$3"
    local duration="$4"
    local space_freed="${5:-0}"
    local files_processed="${6:-0}"
    local error_count="${7:-0}"
    local system_load="${8:-0}"
    local memory_usage="${9:-0}"
    local trigger="${10:-scheduled}"
    local details="${11:-}"

    init_history

    local timestamp
    timestamp=$(date -Iseconds)

    # Escape special characters in details
    local escaped_details
    escaped_details=$(echo "$details" | sed 's/|/\\|/g' | sed 's/\n/\\n/g')

    # Add record to database
    echo "$timestamp|$operation_type|$profile|$status|$duration|$space_freed|$files_processed|$error_count|$system_load|$memory_usage|$trigger|$escaped_details" >> "$FUB_HISTORY_DB"

    log_debug "Recorded maintenance operation: $operation_type ($profile) - $status (${duration}s)"

    # Trigger analysis if enabled
    if [[ "$FUB_HISTORY_ANALYSIS_ENABLED" == true ]]; then
        schedule_analysis
    fi
}

# Get maintenance history
get_maintenance_history() {
    local operation_type="${1:-}"
    local profile="${2:-}"
    local status="${3:-}"
    local days="${4:-30}"
    local limit="${5:-50}"

    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        echo "No maintenance history found"
        return 0
    fi

    local filter="cat"
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds)

    # Apply filters
    [[ -n "$operation_type" ]] && filter="$filter | grep \"|$operation_type|\""
    [[ -n "$profile" ]] && filter="$filter | grep \"|$profile|\""
    [[ -n "$status" ]] && filter="$filter | grep \"|$status|\""

    # Apply date filter and limit
    filter="$filter | awk -F'|' -v cutoff='$cutoff_date' '\$1 >= cutoff' | tail -n $limit"

    echo "Maintenance History (last $days days):"
    echo "====================================="
    printf "%-20s %-15s %-10s %-8s %-8s %-12s %-8s\n" "Timestamp" "Operation" "Profile" "Status" "Duration" "Space Freed" "Errors"
    echo "--------------------------------------------------------------------------------"

    eval "$filter" "$FUB_HISTORY_DB" | while IFS='|' read -r timestamp operation_type profile status duration space_freed files_processed error_count system_load memory_usage trigger details; do
        # Format timestamp
        local formatted_timestamp
        formatted_timestamp=$(date -d "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$timestamp")

        # Format space freed
        local space_display
        if [[ $space_freed -gt 0 ]]; then
            space_display=$(format_bytes "$space_freed")
        else
            space_display="-"
        fi

        printf "%-20s %-15s %-10s %-8s %-8ss %-12s %-8s\n" \
            "$formatted_timestamp" "$operation_type" "$profile" "$status" "$duration" "$space_display" "$error_count"
    done
}

# Format bytes for human readable display
format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0

    while [[ $bytes -gt 1024 && $unit -lt $((${#units[@]} - 1)) ]]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done

    echo "${bytes}${units[$unit]}"
}

# Get operation statistics
get_operation_statistics() {
    local days="${1:-30}"

    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        echo "No maintenance history found"
        return 0
    fi

    local cutoff_date
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds)

    echo "Maintenance Statistics (last $days days):"
    echo "=========================================="

    # Filter for recent records
    local recent_data
    recent_data=$(awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff' "$FUB_HISTORY_DB")

    if [[ -z "$recent_data" ]]; then
        echo "No maintenance operations in the specified period"
        return 0
    fi

    # Total operations
    local total_operations
    total_operations=$(echo "$recent_data" | wc -l)
    echo "Total operations: $total_operations"

    # Success rate
    local successful_operations
    successful_operations=$(echo "$recent_data" | awk -F'|' '$4 == "success" {count++} END {print count+0}')
    local success_rate
    if [[ $total_operations -gt 0 ]]; then
        success_rate=$(awk "BEGIN {printf \"%.1f\", ($successful_operations/$total_operations)*100}")
    else
        success_rate="0.0"
    fi
    echo "Success rate: $success_rate% ($successful_operations/$total_operations)"

    # By operation type
    echo ""
    echo "By operation type:"
    echo "$recent_data" | awk -F'|' '
    {
        type[$2]++
        duration[$2] += $5
        space[$2] += $6
        errors[$2] += $8
    }
    END {
        for (type in type) {
            printf "  %-15s: %d operations, avg %.1fs, total %s, %d errors\n",
                   type, type[type], duration[type]/type[type], format_bytes(space[type]), errors[type]
        }
    }' format_bytes=format_bytes

    # By profile
    echo ""
    echo "By profile:"
    echo "$recent_data" | awk -F'|' '
    {
        profile[$3]++
        duration[$3] += $5
        space[$3] += $6
    }
    END {
        for (prof in profile) {
            printf "  %-12s: %d operations, avg %.1fs, total %s\n",
                   prof, profile[prof], duration[prof]/profile[prof], format_bytes(space[prof])
        }
    }' format_bytes=format_bytes

    # Performance metrics
    echo ""
    echo "Performance metrics:"
    local avg_duration
    avg_duration=$(echo "$recent_data" | awk -F'|' '{sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
    local total_space_freed
    total_space_freed=$(echo "$recent_data" | awk -F'|' '{sum+=$6} END {print sum+0}')
    local total_files_processed
    total_files_processed=$(echo "$recent_data" | awk -F'|' '{sum+=$7} END {print sum+0}')

    echo "  Average duration: ${avg_duration}s"
    echo "  Total space freed: $(format_bytes $total_space_freed)"
    echo "  Total files processed: $total_files_processed"
}

# Analyze performance trends
analyze_performance_trends() {
    local days="${1:-30}"

    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        echo "No maintenance history found for trend analysis"
        return 0
    fi

    echo "Performance Trend Analysis (last $days days):"
    echo "=============================================="

    local cutoff_date
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds)

    # Group by day and calculate daily averages
    echo "Daily averages:"
    awk -F'|' -v cutoff="$cutoff_date" '
    $1 >= cutoff {
        date = substr($1, 1, 10)
        duration[date] += $5
        space[date] += $6
        count[date]++
    }
    END {
        for (date in duration) {
            printf "%s: %.1fs avg, %s total\n",
                   date, duration[date]/count[date], format_bytes(space[date])
        }
    }' format_bytes=format_bytes "$FUB_HISTORY_DB" | sort

    # Identify trends
    echo ""
    echo "Trend analysis:"
    # Get recent vs older performance comparison
    local recent_cutoff
    recent_cutoff=$(date -d "7 days ago" -Iseconds 2>/dev/null || date -v-7d -Iseconds)
    local older_cutoff
    older_cutoff=$(date -d "21 days ago" -Iseconds 2>/dev/null || date -v-21d -Iseconds)

    local recent_avg
    recent_avg=$(awk -F'|' -v cutoff="$recent_cutoff" '$1 >= cutoff && $4 == "success" {sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}' "$FUB_HISTORY_DB")

    local older_avg
    older_avg=$(awk -F'|' -v start="$older_cutoff" -v end="$recent_cutoff" '$1 >= start && $1 < end && $4 == "success" {sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}' "$FUB_HISTORY_DB")

    if [[ "$recent_avg" != "0" && "$older_avg" != "0" ]]; then
        local trend
        if command -v bc >/dev/null 2>&1; then
            trend=$(echo "scale=2; (($recent_avg - $older_avg) / $older_avg) * 100" | bc)
            echo "  Duration trend: $trend% (recent: ${recent_avg}s, older: ${older_avg}s)"
        else
            echo "  Recent avg duration: ${recent_avg}s, Older avg: ${older_avg}s"
        fi
    fi
}

# Generate predictive maintenance suggestions
generate_maintenance_suggestions() {
    echo "Predictive Maintenance Suggestions:"
    echo "==================================="

    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        echo "Insufficient data for predictions"
        return 0
    fi

    local cutoff_date
    cutoff_date=$(date -d "30 days ago" -Iseconds 2>/dev/null || date -v-30d -Iseconds)

    # Analyze failure patterns
    echo "Failure analysis:"
    local failed_operations
    failed_operations=$(awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff && $4 == "failed" {print $2}' "$FUB_HISTORY_DB" | sort | uniq -c | sort -nr)

    if [[ -n "$failed_operations" ]]; then
        echo "$failed_operations" | while read -r count operation; do
            echo "  Warning: $operation failed $count times in last 30 days"
            echo "  Suggestion: Review $operation configuration and system conditions"
        done
    else
        echo "  ✓ No failure patterns detected"
    fi

    # Analyze performance degradation
    echo ""
    echo "Performance analysis:"
    local slow_operations
    slow_operations=$(awk -F'|' -v cutoff="$cutoff_date" '
    $1 >= cutoff && $4 == "success" && $5 > 300 {
        count[$2]++
    }
    END {
        for (op in count) {
            if (count[op] >= 3) {
                printf "%s %d\n", op, count[op]
            }
        }
    }' "$FUB_HISTORY_DB")

    if [[ -n "$slow_operations" ]]; then
        echo "$slow_operations" | while read -r operation count; do
            echo "  Warning: $operation took over 5 minutes $count times"
            echo "  Suggestion: Consider optimizing $operation or adjusting schedule"
        done
    else
        echo "  ✓ No performance degradation detected"
    fi

    # Check for unused profiles
    echo ""
    echo "Profile utilization:"
    local cutoff_days
    cutoff_days=$(date -d "14 days ago" -Iseconds 2>/dev/null || date -v-14d -Iseconds)

    awk -F'|' -v cutoff="$cutoff_days" '$1 >= cutoff {print $3}' "$FUB_HISTORY_DB" | sort | uniq -c | while read -r count profile; do
        if [[ $count -eq 0 ]]; then
            echo "  Info: Profile '$profile' has not been used recently"
        elif [[ $count -lt 3 ]]; then
            echo "  Info: Profile '$profile' used only $count times in last 14 days"
        else
            echo "  ✓ Profile '$profile' actively used ($count times)"
        fi
    done

    # System resource suggestions
    echo ""
    echo "Resource utilization:"
    local high_load_operations
    high_load_operations=$(awk -F'|' -v cutoff="$cutoff_date" '
    $1 >= cutoff && $9 > 1.0 {
        count[$2]++
    }
    END {
        for (op in count) {
            if (count[op] >= 2) {
                printf "%s %d\n", op, count[op]
            }
        }
    }' "$FUB_HISTORY_DB")

    if [[ -n "$high_load_operations" ]]; then
        echo "$high_load_operations" | while read -r operation count; do
            echo "  Info: $operation frequently runs under high system load"
            echo "  Suggestion: Consider scheduling $operation during off-peak hours"
        done
    else
        echo "  ✓ Operations are running under acceptable load conditions"
    fi
}

# Schedule background analysis
schedule_analysis() {
    # This function would schedule analysis to run in the background
    # For now, we'll run it immediately (could be enhanced with actual scheduling)
    generate_maintenance_report >/dev/null 2>&1 &
}

# Generate comprehensive maintenance report
generate_maintenance_report() {
    local report_file
    report_file="${FUB_HISTORY_STATS}/report_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "FUB Maintenance Report"
        echo "======================"
        echo "Generated: $(date)"
        echo ""

        get_operation_statistics 30
        echo ""

        analyze_performance_trends 30
        echo ""

        generate_maintenance_suggestions
        echo ""

        # Recent failures
        echo "Recent Failures (last 7 days):"
        echo "==============================="
        get_maintenance_history "" "" "failed" "7" "10"
        echo ""

        # Top space-saving operations
        echo "Top Space-Saving Operations (last 30 days):"
        echo "============================================"
        if [[ -f "$FUB_HISTORY_DB" ]]; then
            awk -F'|' '$4 == "success" && $6 > 0 {print $2, $6}' "$FUB_HISTORY_DB" | \
            awk '{space[$1] += $2} END {for (op in space) printf "%-20s %s\n", op, space[op]}' | \
            sort -k2 -nr | head -5 | while read -r operation space; do
                printf "%-20s %s\n" "$operation" "$(format_bytes "$space")"
            done
        fi

    } > "$report_file"

    log_debug "Maintenance report generated: $report_file"
    echo "$report_file"
}

# Export history data
export_history_data() {
    local format="${1:-csv}"
    local output_file="$2"
    local days="${3:-90}"

    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        echo "No maintenance history to export"
        return 1
    fi

    local cutoff_date
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds)

    case "$format" in
        "csv")
            awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff' "$FUB_HISTORY_DB" > "$output_file"
            ;;
        "json")
            echo "[" > "$output_file"
            local first=true
            awk -F'|' -v cutoff="$cutoff_date" '
            $1 >= cutoff {
                if (!first) print ","
                printf "{\n"
                printf "  \"timestamp\": \"%s\",\n", $1
                printf "  \"operation_type\": \"%s\",\n", $2
                printf "  \"profile\": \"%s\",\n", $3
                printf "  \"status\": \"%s\",\n", $4
                printf "  \"duration\": %s,\n", $5
                printf "  \"space_freed\": %s,\n", $6
                printf "  \"files_processed\": %s,\n", $7
                printf "  \"error_count\": %s,\n", $8
                printf "  \"system_load\": %s,\n", $9
                printf "  \"memory_usage\": %s,\n", $10
                printf "  \"trigger\": \"%s\",\n", $11
                printf "  \"details\": \"%s\"\n", $12
                printf "}"
                first=false
            }' "$FUB_HISTORY_DB" >> "$output_file"
            echo "]" >> "$output_file"
            ;;
        *)
            echo "Unsupported export format: $format. Use 'csv' or 'json'"
            return 1
            ;;
    esac

    log_info "History data exported to: $output_file"
}

# Clean up old history records
cleanup_old_history_records() {
    if [[ ! -f "$FUB_HISTORY_DB" ]]; then
        return 0
    fi

    local cutoff_date
    cutoff_date=$(date -d "$FUB_HISTORY_RETENTION_DAYS days ago" -Iseconds 2>/dev/null || date -v-${FUB_HISTORY_RETENTION_DAYS}d -Iseconds)

    # Keep header and recent records
    local temp_file
    temp_file=$(mktemp)
    head -n 1 "$FUB_HISTORY_DB" > "$temp_file"
    awk -F'|' -v cutoff="$cutoff_date" '$1 >= cutoff || NR == 1' "$FUB_HISTORY_DB" >> "$temp_file"

    mv "$temp_file" "$FUB_HISTORY_DB"

    # Clean up old analysis files
    find "$FUB_HISTORY_STATS" -name "report_*.txt" -mtime +$((FUB_HISTORY_RETENTION_DAYS/2)) -delete 2>/dev/null || true

    log_debug "Cleaned up history records older than $FUB_HISTORY_RETENTION_DAYS days"
}

# Export functions
export -f init_history
export -f load_history_config
export -f create_history_database
export -f record_maintenance_operation
export -f get_maintenance_history
export -f get_operation_statistics
export -f analyze_performance_trends
export -f generate_maintenance_suggestions
export -f generate_maintenance_report
export -f export_history_data
export -f cleanup_old_history_records
export -f format_bytes