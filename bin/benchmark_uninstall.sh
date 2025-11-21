#!/bin/bash
# Fub Uninstaller Performance Benchmark
# Tests scanning performance with various optimizations

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="$HOME/.cache/fub/apps_list.txt"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Fub Uninstaller Performance Benchmark (Ubuntu 24.04)    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# System information
echo -e "${CYAN}System Information:${NC}"
echo "  OS: $(lsb_release -ds 2>/dev/null || echo "Unknown")"
echo "  Kernel: $(uname -r)"
echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "  CPU Cores: $(nproc)"
echo "  RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo ""

# Package counts
echo -e "${CYAN}Installed Packages:${NC}"
APT_COUNT=$(dpkg -l | grep "^ii" | wc -l)
SNAP_COUNT=$(snap list 2>/dev/null | tail -n +2 | wc -l || echo 0)
FLATPAK_COUNT=$(flatpak list --app 2>/dev/null | wc -l || echo 0)
APPIMAGE_COUNT=$(find "$HOME" -name "*.AppImage" -type f 2>/dev/null | wc -l || echo 0)

echo "  APT packages: $APT_COUNT"
echo "  Snap packages: $SNAP_COUNT"
echo "  Flatpak apps: $FLATPAK_COUNT"
echo "  AppImage files: $APPIMAGE_COUNT"
echo ""

# Benchmark function
benchmark_scan() {
    local label="$1"
    local clear_cache="${2:-false}"

    # Clear cache if requested
    if [[ "$clear_cache" == "true" ]]; then
        rm -f "$CACHE_FILE"
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test: $label${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Get start time
    local start_time=$(date +%s.%N)

    # Source the script functions
    source "$SCRIPT_DIR/../lib/common.sh"
    source "$SCRIPT_DIR/../lib/package_managers.sh"

    # Run the scan
    mkdir -p "$(dirname "$CACHE_FILE")"
    source "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1 <<EOF || true
EOF

    # Use scan function directly
    if [[ "$clear_cache" == "true" ]]; then
        scan_all_applications "$CACHE_FILE" "true" 2>&1 | grep -v "^$" || true
    else
        scan_all_applications "$CACHE_FILE" "false" 2>&1 | grep -v "^$" || true
    fi

    # Get end time
    local end_time=$(date +%s.%N)

    # Calculate duration
    local duration=$(echo "$end_time - $start_time" | bc)

    # Get result count
    local pkg_count=$(wc -l < "$CACHE_FILE" 2>/dev/null || echo 0)

    echo ""
    echo -e "  ${GREEN}✓${NC} Duration: ${GREEN}${duration}s${NC}"
    echo -e "  ${GREEN}✓${NC} Packages found: ${GREEN}${pkg_count}${NC}"

    # Check cache status
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_size=$(du -h "$CACHE_FILE" | awk '{print $1}')
        echo -e "  ${GREEN}✓${NC} Cache size: ${GREEN}${cache_size}${NC}"
    fi

    echo ""
}

# Run benchmarks
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Starting Performance Tests...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Test 1: First scan (no cache)
benchmark_scan "First scan (cold cache, parallel mode)" "true"

sleep 1

# Test 2: Cached scan
benchmark_scan "Second scan (warm cache)" "false"

sleep 1

# Test 3: Force refresh
benchmark_scan "Force refresh (cache bypass)" "true"

sleep 1

# Test 4: Cached again
benchmark_scan "Fourth scan (warm cache again)" "false"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Benchmark Complete!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Summary
echo -e "${CYAN}Summary:${NC}"
echo "  Cache location: $CACHE_FILE"
if [[ -f "$CACHE_FILE" ]]; then
    echo "  Cache age: $(stat -c "%y" "$CACHE_FILE" | awk '{print $1, $2}')"
    echo "  Cache size: $(du -h "$CACHE_FILE" | awk '{print $1}')"
fi
echo ""

echo -e "${YELLOW}Performance Tips:${NC}"
echo "  • First scan builds cache (2-10 seconds)"
echo "  • Cached scans are instant (<1 second)"
echo "  • Cache expires after 5 minutes"
echo "  • Use --refresh to force cache rebuild"
echo ""

echo -e "${GREEN}Run the uninstaller with:${NC}"
echo "  ./bin/uninstall.sh"
echo ""
