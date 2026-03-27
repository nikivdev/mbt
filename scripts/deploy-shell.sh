#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BIN_DIR="${HOME}/bin"
BIN_NAME="shell"

echo "Building MoonBit shell CLI..."
moon build cli/shell --target native -q

BUILD_DIR="${ROOT_DIR}/_build/native/release/build/cli/shell"
SOURCE_BIN="${BUILD_DIR}/shell.exe"

if [[ ! -f "${SOURCE_BIN}" ]]; then
  echo "Error: Binary not found at ${SOURCE_BIN}"
  exit 1
fi

mkdir -p "${BIN_DIR}"
cp -f "${SOURCE_BIN}" "${BIN_DIR}/${BIN_NAME}"
chmod +x "${BIN_DIR}/${BIN_NAME}"

echo "Installed ${BIN_NAME} to ${BIN_DIR}/${BIN_NAME}"
