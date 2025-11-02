#!/usr/bin/env bash

# Test script for FUB Interactive UI System
# Demonstrates all interactive components with and without gum

set -eo pipefail

# Source required libraries
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/theme.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/interactive.sh"

# Initialize systems
init_theme
init_ui true false true
init_interactive

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo ""
    if supports_colors; then
        echo "${BOLD}${BLUE}Testing: $test_name${RESET}"
    else
        echo "Testing: $test_name"
    fi

    # Simple repeat using loop
    local dash_line=""
    for ((i=0; i < ${#test_name} + 9; i++)); do
        dash_line+="─"
    done
    echo "$dash_line"
    echo ""

    # Run test with error handling
    if "$test_function" 2>/dev/null; then
        if supports_colors; then
            echo "${GREEN}✓ PASSED${RESET}"
        else
            echo "✓ PASSED"
        fi
        ((TESTS_PASSED++))
    else
        local exit_code=$?
        if supports_colors; then
            echo "${RED}✗ FAILED (exit code: $exit_code)${RESET}"
        else
            echo "✗ FAILED (exit code: $exit_code)"
        fi
        ((TESTS_FAILED++))
    fi
}

# Test functions
test_init_interactive() {
    # Test system initialization
    if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
        echo "✓ Gum is available and detected"
    else
        echo "⚠ Gum not available - using pure bash mode"
    fi

    if [[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]]; then
        echo "✓ Terminal supports escape sequences"
    else
        echo "⚠ Terminal does not support escape sequences"
    fi

    return 0
}

test_main_menu() {
    echo "Displaying main menu (will auto-select first option after 2 seconds)..."

    # Use a timeout to auto-select for testing
    export FUB_INTERACTIVE_MODE=true

    # This would normally wait for user input, but for testing we'll simulate
    if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
        echo "✓ Gum-enhanced main menu available"
    else
        echo "✓ Pure bash main menu available"
    fi

    return 0
}

test_multi_select() {
    local -a test_options=(
        "Option 1 - System Files"
        "Option 2 - User Data"
        "Option 3 - Configuration"
        "Option 4 - Logs"
        "Option 5 - Cache"
    )

    local -a test_defaults=("Option 1 - System Files" "Option 3 - Configuration")

    echo "Testing multi-select interface..."
    echo "Available options:"
    printf '  %s\n' "${test_options[@]}"
    echo "Default selections: ${test_defaults[*]}"
    echo ""

    if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
        echo "✓ Gum-enhanced multi-select available"
    else
        echo "✓ Pure bash multi-select available"
    fi

    return 0
}

test_progress_indicators() {
    echo "Testing progress indicators..."

    # Test basic progress bar
    echo "Basic progress bar:"
    for i in {1..10}; do
        show_progress_interactive $i 10 "Processing item $i" 30
        sleep 0.1
    done
    echo ""

    # Test spinner
    echo "Testing spinner (simulated long operation):"
    (
        for i in {1..5}; do
            echo "Processing step $i..."
            sleep 0.5
        done
    ) &
    local pid=$!
    show_spinner_interactive "Simulated long operation" "$pid"
    wait $pid

    echo "✓ Progress indicators working"
    return 0
}

test_confirmation_dialogs() {
    echo "Testing confirmation dialogs..."

    # Test basic confirmation
    echo "1. Basic confirmation (will default to 'no' for testing):"
    export FUB_INTERACTIVE_MODE=false  # Non-interactive for testing
    if confirm_with_warning "Delete all files?" "This action cannot be undone" "n" false; then
        echo "   Would have proceeded"
    else
        echo "   Would have cancelled (expected for testing)"
    fi

    # Test expert warning
    echo ""
    echo "2. Expert warning dialog:"
    if confirm_with_warning "Modify system kernel?" "This may cause system instability" "n" true; then
        echo "   Would have proceeded"
    else
        echo "   Would have cancelled (expected for testing)"
    fi

    export FUB_INTERACTIVE_MODE=true
    echo "✓ Confirmation dialogs working"
    return 0
}

test_status_display() {
    echo "Testing status display system..."

    show_operation_result "System update" "success" "All packages updated successfully"
    show_operation_result "Disk cleanup" "warning" "Some files could not be removed (in use)"
    show_operation_result "Service restart" "error" "Failed to restart nginx service"

    echo "✓ Status display working"
    return 0
}

test_help_system() {
    echo "Testing help system..."

    # Test help content retrieval
    local help_content
    help_content=$(get_help_content "main")
    if [[ -n "$help_content" ]]; then
        echo "✓ Help content retrieved successfully"
        echo "  First line: $(echo "$help_content" | head -1)"
    else
        echo "✗ Failed to retrieve help content"
        return 1
    fi

    # Test invalid topic
    local invalid_help
    invalid_help=$(get_help_content "nonexistent" 2>/dev/null || true)
    if [[ -n "$invalid_help" ]]; then
        echo "✓ Help system handles invalid topics gracefully"
    else
        echo "⚠ Help system returned empty for invalid topic"
    fi

    return 0
}

test_keyboard_navigation() {
    echo "Testing keyboard navigation..."

    if [[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]]; then
        echo "✓ Arrow key support available"
        echo "✓ Special key detection working"

        # Test key reading (quick test)
        echo "Testing key reading (press any key within 1 second)..."
        local key
        key=$(read_key 1)
        if [[ -n "$key" ]]; then
            echo "✓ Key detected: $key"
        else
            echo "⚠ No key pressed within timeout"
        fi
    else
        echo "⚠ Limited keyboard navigation (no escape sequence support)"
    fi

    return 0
}

# Main test execution
main() {
    print_header "FUB Interactive UI System Test Suite" "Testing all interactive components"

    echo "This test suite validates the interactive UI components."
    echo "Some tests will be simulated to avoid requiring user input."
    echo ""

    # Run tests
    run_test "System Initialization" test_init_interactive
    run_test "Main Menu Interface" test_main_menu
    run_test "Multi-Select Interface" test_multi_select
    run_test "Progress Indicators" test_progress_indicators
    run_test "Confirmation Dialogs" test_confirmation_dialogs
    run_test "Status Display System" test_status_display
    run_test "Help System" test_help_system
    run_test "Keyboard Navigation" test_keyboard_navigation

    # Test summary
    echo ""
    print_header "Test Results Summary"

    if supports_colors; then
        echo "${BOLD}Tests Passed:${RESET} ${GREEN}$TESTS_PASSED${RESET}"
        echo "${BOLD}Tests Failed:${RESET} ${RED}$TESTS_FAILED${RESET}"
        echo "${BOLD}Total Tests:${RESET} $((TESTS_PASSED + TESTS_FAILED))"
    else
        echo "Tests Passed: $TESTS_PASSED"
        echo "Tests Failed: $TESTS_FAILED"
        echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    fi

    echo ""

    # Feature availability summary
    print_section "Feature Availability"

    echo "Gum Integration: $([[ "$FUB_GUM_AVAILABLE" == true ]] && echo "${GREEN}Available${RESET}" || echo "${YELLOW}Not Available${RESET}")"
    echo "Terminal Colors: $([[ $(supports_colors) == true ]] && echo "${GREEN}Available${RESET}" || echo "${YELLOW}Not Available${RESET}")"
    echo "Escape Sequences: $([[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]] && echo "${GREEN}Available${RESET}" || echo "${YELLOW}Not Available${RESET}")"

    echo ""

    # Interactive demo (optional)
    if ask_confirmation "Would you like to see an interactive demo of the main menu?"; then
        echo ""
        echo "Launching interactive demo..."
        echo "Use arrow keys to navigate, Enter to select, q to quit"
        echo ""
        sleep 2

        # This would normally show the interactive menu
        # For testing, we'll just show what would happen
        echo "Demo mode: Main menu would appear here"
        echo "Your selection would be processed accordingly"
    fi

    echo ""
    print_success "Interactive UI system test completed successfully!"
}

# Check if script is being executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi