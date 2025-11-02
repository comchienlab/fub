#!/usr/bin/env bash

# Simple test for interactive system

set -euo pipefail

# Source the libraries
source /Users/tinhtute/Lab/Ubuntu/fub/lib/common.sh
source /Users/tinhtute/Lab/Ubuntu/fub/lib/theme.sh
source /Users/tinhtute/Lab/Ubuntu/fub/lib/ui.sh
source /Users/tinhtute/Lab/Ubuntu/fub/lib/interactive.sh

# Initialize systems
init_theme
init_ui true false true
init_interactive

echo "=== Interactive System Test ==="
echo "Gum available: $FUB_GUM_AVAILABLE"
echo "Escape sequences: $FUB_INTERACTIVE_ESC_SEQS"

# Test basic functions
echo ""
echo "Testing repeat_char function:"
echo "$(repeat_char "─" 20)"

echo ""
echo "Testing confirmation dialog:"
export FUB_INTERACTIVE_MODE=false
if confirm_with_warning "Test message?" "Test warning" "n" false; then
    echo "Would proceed"
else
    echo "Would cancel"
fi

echo ""
echo "=== Test completed successfully ==="