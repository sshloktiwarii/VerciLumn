#!/usr/bin/env bash
set -euo pipefail

# VerciLumn Universal Build & Verification Script
# Automatically cleans stale cryptex Metal intermediates and builds release artifacts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "==> Verifying Xcode and Metal toolchain..."
xcrun -f metal > /dev/null 2>&1 || {
    echo "Error: Metal compiler not found. Ensure Xcode is selected via xcode-select."
    exit 1
}

# If .build exists, verify that cached Metal toolchain path matches current cryptex mount
if [ -d ".build" ]; then
    CURRENT_METAL="$(xcrun -f metal 2>/dev/null || true)"
    if [ -n "${CURRENT_METAL}" ]; then
        CACHED_FAILURES=$(grep -rn "No such file or directory.*MetalToolchain" .build 2>/dev/null || true)
        if [ -n "${CACHED_FAILURES}" ]; then
            echo "==> Detected stale Metal toolchain path in build cache. Cleaning .build..."
            rm -rf .build
        fi
    fi
fi

echo "==> Running test suite..."
swift test

echo "==> Building VerciLumn (Release)..."
swift build -c release

echo "==> Building VerciLumnSaver screensaver bundle..."
"${SCRIPT_DIR}/build_screensaver.sh"

echo "==> Build and verification complete!"
