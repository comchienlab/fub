#!/bin/bash
# Entry point for the Go-based disk analyzer binary bundled with Fub.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_BIN="$SCRIPT_DIR/analyze-go"
if [[ -x "$GO_BIN" ]]; then
    exec "$GO_BIN" "$@"
fi

echo "Bundled analyzer binary not found. Please reinstall Fub or run fub update to restore it." >&2
exit 1
