#!/bin/bash
# Build analyze-go binary
# Supports Linux (Ubuntu) and macOS

set -euo pipefail

cd "$(dirname "$0")/.."

# Check if Go is installed
if ! command -v go > /dev/null 2>&1; then
    echo "Error: Go not installed"
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Install: brew install go"
    else
        echo "Install: sudo apt-get install golang-go"
    fi
    exit 1
fi

echo "Building analyze-go..."

# Get version info
VERSION=$(git describe --tags --always --dirty 2> /dev/null || echo "dev")
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
LDFLAGS="-s -w -X main.Version=$VERSION -X main.BuildTime=$BUILD_TIME"

echo "  Version: $VERSION"
echo "  Build time: $BUILD_TIME"
echo ""

# Detect OS and architecture
OS=$(uname)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    # macOS - build universal binary
    echo "  Platform: macOS"
    echo "  → Building for arm64..."
    GOARCH=arm64 go build -ldflags="$LDFLAGS" -trimpath -o bin/analyze-go-arm64 ./cmd/analyze

    echo "  → Building for amd64..."
    GOARCH=amd64 go build -ldflags="$LDFLAGS" -trimpath -o bin/analyze-go-amd64 ./cmd/analyze

    echo "  → Creating Universal Binary..."
    lipo -create bin/analyze-go-arm64 bin/analyze-go-amd64 -output bin/analyze-go

    # Clean up temporary files
    rm bin/analyze-go-arm64 bin/analyze-go-amd64

    echo ""
    echo "✓ Build complete!"
    echo ""
    file bin/analyze-go
    size_bytes=$(stat -f%z bin/analyze-go 2> /dev/null || echo 0)
    size_mb=$((size_bytes / 1024 / 1024))
    printf "Size: %d MB (%d bytes)\n" "$size_mb" "$size_bytes"
    echo ""
    echo "Binary supports: arm64 (Apple Silicon) + x86_64 (Intel)"
else
    # Linux - build for current architecture
    echo "  Platform: Linux"
    echo "  Architecture: $ARCH"
    echo "  → Building for $ARCH..."

    go build -ldflags="$LDFLAGS" -trimpath -o bin/analyze-go ./cmd/analyze

    echo ""
    echo "✓ Build complete!"
    echo ""
    file bin/analyze-go 2>/dev/null || echo "Binary: bin/analyze-go"
    size_bytes=$(stat -c%s bin/analyze-go 2> /dev/null || echo 0)
    size_mb=$((size_bytes / 1024 / 1024))
    printf "Size: %d MB (%d bytes)\n" "$size_mb" "$size_bytes"
    echo ""
    echo "Binary for: Linux $ARCH"
fi
