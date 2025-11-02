#!/usr/bin/env bash

# FUB Monitoring System Demonstration
# Shows the capabilities of the new monitoring integration

set -euo pipefail

readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the monitoring integration
source "${FUB_SCRIPT_DIR}/lib/monitoring/monitoring-integration.sh"

# Demo configuration
DEMO_MODE="${DEMO_MODE:-interactive}"  # Options: interactive, batch, test
DEMO_DURATION="${DEMO_DURATION:-30}"

# Initialize demo
init_demo() {
    echo "FUB Monitoring System Demonstration"
    echo "==================================="
    echo

    # Ensure monitoring is enabled
    export MONITORING_ENABLED=true
    export MONITORING_LOG_LEVEL=INFO

    # Initialize monitoring system
    init_monitoring_system

    echo "Monitoring system initialized"
    echo
}

# Show monitoring status
show_monitoring_status() {
    echo "Current Monitoring Status"
    echo "-------------------------"
    echo

    local status
    status=$(get_monitoring_status)

    echo "Monitoring enabled: $(echo "$status" | grep -o '"monitoring_enabled": [^,]*' | cut -d: -f2 | tr -d ' ')"
    echo "Btop status: $(echo "$status" | grep '"status":' | head -1 | cut -d'"' -f4)"
    echo "Last update: $(echo "$status" | grep '"timestamp":' | cut -d'"' -f4)"
    echo

    # Show current metrics
    echo "Current System Metrics:"
    local metrics
    metrics=$(echo "$status" | grep -A10 '"current_metrics":')
    echo "$metrics" | grep -E '"usage_percent"|"load_average"' | sed 's/^[[:space:]]*/  /'
    echo
}

# Demonstrate pre-cleanup analysis
demo_precleanup_analysis() {
    echo "Pre-Cleanup System Analysis"
    echo "----------------------------"
    echo

    local operation_name="demo_cleanup"
    local operation_id="demo_$(date +%s)"

    echo "Running pre-cleanup analysis for operation: $operation_name"
    echo "Operation ID: $operation_id"
    echo

    local before_file
    before_file=$(start_precleanup_analysis "$operation_name" "$operation_id")

    if [[ -f "$before_file" ]]; then
        echo "✓ Pre-cleanup analysis completed"
        echo "Analysis saved to: $before_file"
        echo

        # Show key findings
        echo "Key Findings:"
        echo "- System Score: $(get_system_score "$(cat "$before_file")")/100"
        echo "- Disk Usage: $(grep -A4 '"disk":' "$before_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')%"
        echo "- Memory Usage: $(grep -A2 '"memory":' "$before_file" | grep '"usage_percent":' | cut -d: -f2 | tr -d ' ,')%"
        echo "- CPU Usage: $(grep -o '"usage_percent": [0-9.]*' "$before_file" | head -1 | cut -d: -f2 | tr -d ' ')%"
        echo
    else
        echo "✗ Pre-cleanup analysis failed"
        echo
        return 1
    fi

    echo "$before_file"
}

# Demonstrate real-time monitoring
demo_realtime_monitoring() {
    echo "Real-Time Monitoring Demo"
    echo "--------------------------"
    echo

    echo "Starting real-time monitoring for $DEMO_DURATION seconds..."
    echo "Press Ctrl+C to stop early"
    echo

    # Start monitoring in a way that's compatible with demo mode
    if [[ "$DEMO_MODE" == "interactive" ]]; then
        display_realtime_monitoring "$DEMO_DURATION" true
    else
        # Batch mode - just show current metrics
        local start_time
        start_time=$(date +%s)
        local end_time=$((start_time + DEMO_DURATION))

        while [[ $(date +%s) -lt $end_time ]]; do
            clear
            echo "Real-Time Monitoring (Batch Mode)"
            echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Duration: $DEMO_DURATION seconds"
            echo

            display_monitoring_header
            display_system_metrics "$(get_current_metrics)"
            display_alerts_widget "$(check_performance_alerts "$(get_current_metrics)")"

            echo "Press Ctrl+C to stop..."
            sleep 2
        done
    fi

    echo
    echo "Real-time monitoring demo completed"
    echo
}

# Demonstrate post-cleanup analysis
demo_postcleanup_analysis() {
    echo "Post-Cleanup Analysis Demo"
    echo "---------------------------"
    echo

    local operation_name="demo_cleanup"
    local operation_id="demo_$(date +%s)"
    local before_file
    before_file=$(demo_precleanup_analysis)

    # Simulate some cleanup activity
    echo "Simulating cleanup operation..."
    sleep 2

    # Complete post-cleanup analysis
    echo "Running post-cleanup analysis..."
    local after_file
    after_file=$(complete_postcleanup_analysis "$operation_name" "$operation_id" "success" "$before_file")

    if [[ -f "$after_file" ]]; then
        echo "✓ Post-cleanup analysis completed"
        echo "Analysis saved to: $after_file"
        echo

        # Show comparison results
        echo "Cleanup Impact Analysis:"
        local comparison
        comparison=$(compare_analyses "$before_file" "$after_file")
        echo "$comparison" | grep -E "cpu_change|memory_change|disk_change" | sed 's/^[[:space:]]*/  /'
        echo
    else
        echo "✗ Post-cleanup analysis failed"
        echo
        return 1
    fi
}

# Demonstrate alert system
demo_alert_system() {
    echo "Alert System Demo"
    echo "------------------"
    echo

    # Get current metrics and check for alerts
    local current_metrics
    current_metrics=$(get_current_metrics)

    echo "Checking current system for alerts..."
    echo

    local alerts
    alerts=$(check_performance_alerts "$current_metrics")

    if [[ "$alerts" == "[]" ]]; then
        echo "✓ No active alerts - System is running normally"
    else
        echo "⚠️  Active alerts detected:"
        echo "$alerts" | jq -r '.[] | "  \(.severity): \(.message)"' 2>/dev/null || echo "$alerts"
    fi

    echo

    # Show alert configuration
    echo "Current Alert Thresholds:"
    echo "- CPU Warning: ${ALERT_CPU_WARNING}%"
    echo "- CPU Critical: ${ALERT_CPU_CRITICAL}%"
    echo "- Memory Warning: ${ALERT_MEMORY_WARNING}%"
    echo "- Memory Critical: ${ALERT_MEMORY_CRITICAL}%"
    echo "- Disk Warning: ${ALERT_DISK_WARNING}%"
    echo "- Disk Critical: ${ALERT_DISK_CRITICAL}%"
    echo
}

# Demonstrate history tracking
demo_history_tracking() {
    echo "History Tracking Demo"
    echo "---------------------"
    echo

    # Get history summary
    local summary
    summary=$(get_history_summary)

    echo "Cleanup History Summary:"
    echo "- Total Operations: $(echo "$summary" | grep '"total":' | cut -d: -f2 | tr -d ' ,')"
    echo "- Successful: $(echo "$summary" | grep '"successful":' | cut -d: -f2 | tr -d ' ,')"
    echo "- Failed: $(echo "$summary" | grep '"failed":' | cut -d: -f2 | tr -d ' ,')"
    echo "- Success Rate: $(echo "$summary" | grep '"success_rate":' | cut -d: -f2 | tr -d ' ,')%"
    echo

    # Get performance trends
    echo "Performance Trends (Last 7 Days):"
    local trends
    trends=$(get_performance_trends 7)
    echo "$trends" | grep -E '"cpu"|"memory"|"disk"' | sed 's/^[[:space:]]*/  /'
    echo

    # Get maintenance suggestions
    echo "Maintenance Suggestions:"
    local suggestions
    suggestions=$(generate_maintenance_suggestions)
    if echo "$suggestions" | grep -q '"suggestions": \['; then
        echo "  No specific suggestions at this time"
    else
        echo "$suggestions" | jq -r '.suggestions[] | "  • \(.message)"' 2>/dev/null || echo "  Suggestions available"
    fi
    echo
}

# Demonstrate btop integration
demo_btop_integration() {
    echo "Btop Integration Demo"
    echo "---------------------"
    echo

    local btop_status
    btop_status=$(get_btop_status)

    echo "Btop Status:"
    echo "- Available: $(echo "$btop_status" | grep '"status":' | cut -d'"' -f4)"
    echo "- Version: $(echo "$btop_status" | grep '"version":' | cut -d'"' -f4)"

    if echo "$btop_status" | grep -q '"status": "available"'; then
        echo "- Path: $(echo "$btop_status" | grep '"path":' | cut -d'"' -f4)"
        echo "✓ Btop integration is ready"
        echo

        if [[ "$DEMO_MODE" == "interactive" ]]; then
            echo "Would you like to start btop now? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo "Starting btop..."
                if command -v btop >/dev/null 2>&1; then
                    btop
                else
                    echo "btop command not found"
                fi
            fi
        fi
    else
        echo "⚠️  Btop is not available - Using fallback monitoring"
        echo
    fi
}

# Generate monitoring report
demo_monitoring_report() {
    echo "Monitoring Report Generation"
    echo "----------------------------"
    echo

    local report_file="fub-monitoring-report-$(date +%Y%m%d-%H%M%S).json"

    echo "Generating comprehensive monitoring report..."
    generate_monitoring_report "$report_file"

    if [[ -f "$report_file" ]]; then
        echo "✓ Report generated successfully"
        echo "File: $report_file"
        echo

        echo "Report contents:"
        echo "- System analysis"
        echo "- Monitoring status"
        echo "- Performance trends"
        echo "- Cleanup history"
        echo "- Alert summary"
        echo "- Maintenance suggestions"
        echo

        # Show report size
        local file_size
        file_size=$(ls -lh "$report_file" | awk '{print $5}')
        echo "Report size: $file_size"
    else
        echo "✗ Report generation failed"
    fi
    echo
}

# Run monitoring system test
demo_monitoring_test() {
    echo "Monitoring System Test"
    echo "----------------------"
    echo

    echo "Running comprehensive monitoring system tests..."
    echo

    if ./test-monitoring-system.sh; then
        echo "✓ All monitoring tests passed"
    else
        echo "✗ Some monitoring tests failed"
    fi
    echo
}

# Interactive demo menu
interactive_demo_menu() {
    while true; do
        clear
        echo "FUB Monitoring System Demonstration"
        echo "==================================="
        echo
        echo "Select a demo option:"
        echo
        echo "1. Show Monitoring Status"
        echo "2. Pre-Cleanup Analysis Demo"
        echo "3. Real-Time Monitoring Demo"
        echo "4. Post-Cleanup Analysis Demo"
        echo "5. Alert System Demo"
        echo "6. History Tracking Demo"
        echo "7. Btop Integration Demo"
        echo "8. Generate Monitoring Report"
        echo "9. Run Monitoring System Test"
        echo "10. Run All Demos"
        echo "0. Exit"
        echo

        read -p "Enter your choice (0-10): " choice

        case "$choice" in
            1)
                show_monitoring_status
                read -p "Press Enter to continue..."
                ;;
            2)
                demo_precleanup_analysis
                read -p "Press Enter to continue..."
                ;;
            3)
                demo_realtime_monitoring
                read -p "Press Enter to continue..."
                ;;
            4)
                demo_postcleanup_analysis
                read -p "Press Enter to continue..."
                ;;
            5)
                demo_alert_system
                read -p "Press Enter to continue..."
                ;;
            6)
                demo_history_tracking
                read -p "Press Enter to continue..."
                ;;
            7)
                demo_btop_integration
                read -p "Press Enter to continue..."
                ;;
            8)
                demo_monitoring_report
                read -p "Press Enter to continue..."
                ;;
            9)
                demo_monitoring_test
                read -p "Press Enter to continue..."
                ;;
            10)
                run_all_demos
                read -p "Press Enter to continue..."
                ;;
            0)
                echo "Exiting demo..."
                return 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Run all demos
run_all_demos() {
    echo "Running All Monitoring Demos"
    echo "============================="
    echo

    show_monitoring_status
    sleep 2

    demo_precleanup_analysis
    sleep 2

    demo_alert_system
    sleep 2

    demo_history_tracking
    sleep 2

    demo_btop_integration
    sleep 2

    demo_monitoring_report

    echo
    echo "✓ All demos completed successfully"
}

# Main demo function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode=*)
                DEMO_MODE="${1#*=}"
                shift
                ;;
            --duration=*)
                DEMO_DURATION="${1#*=}"
                shift
                ;;
            --help|-h)
                cat << 'EOF'
FUB Monitoring System Demonstration

Usage: ./demo-monitoring.sh [OPTIONS]

Options:
  --mode=MODE        Demo mode: interactive (default), batch, test
  --duration=SECONDS Duration for real-time monitoring demo (default: 30)
  --help, -h         Show this help message

Demo Modes:
  interactive: Interactive menu-driven demo
  batch:       Run demos automatically without user input
  test:        Run monitoring system tests only

Examples:
  ./demo-monitoring.sh                    # Interactive demo
  ./demo-monitoring.sh --mode=batch       # Batch demo
  ./demo-monitoring.sh --duration=60     # 60-second monitoring demo
EOF
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done

    # Initialize demo
    init_demo

    # Run based on mode
    case "$DEMO_MODE" in
        "interactive")
            interactive_demo_menu
            ;;
        "batch")
            run_all_demos
            ;;
        "test")
            demo_monitoring_test
            ;;
        *)
            echo "Unknown demo mode: $DEMO_MODE"
            echo "Available modes: interactive, batch, test"
            return 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi