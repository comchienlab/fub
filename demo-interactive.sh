#!/usr/bin/env bash

# Interactive UI System Demo
# Shows the key features of the interactive components

set -eo pipefail

# Source the libraries
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/theme.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/interactive.sh"

# Initialize systems
init_theme
init_ui true false true
init_interactive

echo ""
print_header "FUB Interactive UI System Demo" "Comprehensive interactive components with gum integration"

echo ""
print_section "System Status"

echo "Gum Integration: $([[ "$FUB_GUM_AVAILABLE" == true ]] && echo "${GREEN}Available${RESET}" || echo "${YELLOW}Not Available${RESET}")"
echo "Terminal Colors: $([[ $(supports_colors) == true ]] && echo "${GREEN}Available${RESET}" || echo "${YELLOW}Not Available${RESET}")"
echo "Escape Sequences: $([[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]] && echo "${GREEN}Available${RESET}" || echo "${YELLOW}Not Available${RESET}")"

echo ""
print_section "Visual Components Demo"

echo "1. Status Display Examples:"
show_operation_result "System scan completed" "success" "All systems operational"
show_operation_result "Package update" "warning" "Some packages skipped"
show_operation_result "Service restart" "error" "Failed to restart nginx"

echo ""
echo "2. Progress Indicators:"
echo "   Simulating progress bars..."
for i in {1..10}; do
    show_progress_interactive $i 10 "Processing files" 30
    sleep 0.2
done
echo ""

echo "3. Confirmation Dialog Demo:"
export FUB_INTERACTIVE_MODE=false
echo "   Non-interactive mode:"
if confirm_with_warning "Delete all temporary files?" "This action cannot be undone" "n" false; then
    echo "   → Would proceed with deletion"
else
    echo "   → Would cancel (expected)"
fi

echo ""
echo "   Expert warning dialog:"
if confirm_with_warning "Modify system configuration?" "This may affect system stability" "n" true; then
    echo "   → Would proceed with expert action"
else
    echo "   → Would cancel expert action (expected)"
fi

echo ""
print_section "Component Capabilities"

echo "✓ Arrow key navigation (when terminal supports escape sequences)"
echo "✓ Multi-select interfaces with checkboxes"
echo "✓ Progress bars and spinners with gum integration"
echo "✓ Confirmation dialogs with expert warnings"
echo "✓ Tokyo Night theme integration"
echo "✓ Graceful degradation without external dependencies"
echo "✓ Cross-platform compatibility (Linux/macOS)"

echo ""
print_section "Interactive Features"

if [[ "$FUB_GUM_AVAILABLE" == true ]]; then
    echo "🎯 Gum-enhanced UI available:"
    echo "   • Interactive menus with gum choose"
    echo "   • Enhanced confirmation dialogs"
    echo "   • Animated progress indicators"
    echo "   • Styled help system"
else
    echo "🔧 Pure bash mode active:"
    echo "   • Basic keyboard navigation"
    echo "   • Simple confirmation prompts"
    echo "   • Text-based progress indicators"
    echo "   • Built-in help system"
fi

echo ""
if [[ "$FUB_INTERACTIVE_ESC_SEQS" == true ]]; then
    echo "⌨️  Full keyboard navigation available"
    echo "   • Arrow keys for menu navigation"
    echo "   • Home/End for quick jumps"
    echo "   • Number keys for quick selection"
    echo "   • Special keys (Space, Tab, etc.)"
else
    echo "📝 Limited keyboard navigation"
    echo "   • Basic number selection"
    echo "   • Enter to confirm"
    echo "   • Simple text input"
fi

echo ""
print_section "Usage Examples"

echo "The interactive system provides these main functions:"
echo ""
echo "1. Main Menu Interface:"
echo "   show_main_menu"
echo ""
echo "2. Category Selection:"
echo "   select_cleanup_categories"
echo ""
echo "3. Interactive Menu (custom):"
echo "   interactive_menu options_array \"Title\" default_index"
echo ""
echo "4. Multi-Select Interface:"
echo "   interactive_multiselect options_array defaults_array \"Title\""
echo ""
echo "5. Progress Display:"
echo "   show_progress_interactive current total \"message\""
echo ""
echo "6. Confirmation Dialog:"
echo "   confirm_with_warning \"Action?\" \"Warning\" default require_expert"

echo ""
print_section "Integration"

echo "To use the interactive system in your scripts:"
echo ""
echo "1. Source the libraries:"
echo "   source lib/interactive.sh"
echo ""
echo "2. Initialize the system:"
echo "   init_interactive"
echo ""
echo "3. Use the interactive functions:"
echo "   local choice"
echo "   choice=\$(show_main_menu)"
echo "   case \"\$choice\" in"
echo "     \"cleanup\") echo \"Running cleanup...\" ;;"
echo "     \"quit\") exit 0 ;;"
echo "   esac"

echo ""
print_success "Interactive UI system demo completed!"
echo ""
echo "The system is ready for integration into FUB components."
echo "All interactive components work with or without gum dependencies."