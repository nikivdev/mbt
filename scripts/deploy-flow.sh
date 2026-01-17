#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BIN_DIR="${HOME}/bin"
BIN_NAME="mbtflow"

echo "Building MoonBit flow CLI..."
cd lib/flow
moon build --target native -q

# Find the built binary
BUILD_DIR="${ROOT_DIR}/lib/flow/_build/native/release/build/cli"
SOURCE_BIN="${BUILD_DIR}/cli.exe"

if [[ ! -f "${SOURCE_BIN}" ]]; then
    echo "Error: Binary not found at ${SOURCE_BIN}"
    exit 1
fi

# Install
mkdir -p "${BIN_DIR}"
cp -f "${SOURCE_BIN}" "${BIN_DIR}/${BIN_NAME}"
chmod +x "${BIN_DIR}/${BIN_NAME}"

echo "Installed ${BIN_NAME} to ${BIN_DIR}/${BIN_NAME}"

# Check PATH
case ":${PATH}:" in
  *:"${BIN_DIR}":*) ;;
  *)
    echo ""
    echo "Note: ${BIN_DIR} is not on PATH."
    echo "Add with: fish_add_path ${BIN_DIR}"
    ;;
esac
