#!/bin/bash
set -euo pipefail

# VerciLumnSaver Native Screen Saver Bundle Packager (.saver)
# Conforms to docs/screensaver_architecture.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building VerciLumnSaver dynamic library target..."
cd "${ROOT_DIR}"
swift build -c release --product VerciLumnSaver

# Locate the compiled dylib in SPM build directory
BUILD_DIR="${ROOT_DIR}/.build"
DYLIB_PATH=$(find "${BUILD_DIR}" -name "libVerciLumnSaver.dylib" | grep -E "release|Debug" | head -n 1)

if [[ -z "${DYLIB_PATH}" || ! -f "${DYLIB_PATH}" ]]; then
    echo "Error: libVerciLumnSaver.dylib not found."
    exit 1
fi

echo "==> Found library: ${DYLIB_PATH}"

BUNDLE_DIR="${ROOT_DIR}/Products/VerciLumnSaver.saver"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Assembling ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary to MacOS/VerciLumnSaver
cp "${DYLIB_PATH}" "${MACOS_DIR}/VerciLumnSaver"
chmod +x "${MACOS_DIR}/VerciLumnSaver"

# Copy Info.plist
cp "${ROOT_DIR}/Sources/VerciLumnSaver/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Code sign bundle ad-hoc
echo "==> Code signing bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo "==> Verifying bundle structure..."
ls -laR "${BUNDLE_DIR}"

# Install if requested
if [[ "${1:-}" == "--install" ]]; then
    DEST_DIR="${HOME}/Library/Screen Savers"
    mkdir -p "${DEST_DIR}"
    echo "==> Installing to ${DEST_DIR}..."
    rm -rf "${DEST_DIR}/VerciLumnSaver.saver"
    cp -R "${BUNDLE_DIR}" "${DEST_DIR}/VerciLumnSaver.saver"
    echo "==> Installed VerciLumnSaver.saver to ${DEST_DIR}/VerciLumnSaver.saver"
fi

echo "==> Done! Screen Saver bundle successfully created at: ${BUNDLE_DIR}"
