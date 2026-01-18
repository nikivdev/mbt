#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BIN_DIR="${HOME}/bin"
BIN_NAME="zed-help"

echo "Building MoonBit zed-help CLI..."
moon build help/zed --target native -q

BUILD_DIR="${ROOT_DIR}/_build/native/release/build/help/zed"
SOURCE_BIN="${BUILD_DIR}/zed.exe"

if [[ ! -f "${SOURCE_BIN}" ]]; then
  echo "Error: Binary not found at ${SOURCE_BIN}"
  exit 1
fi

mkdir -p "${BIN_DIR}"
cp -f "${SOURCE_BIN}" "${BIN_DIR}/${BIN_NAME}"
chmod +x "${BIN_DIR}/${BIN_NAME}"

echo "Installed ${BIN_NAME} to ${BIN_DIR}/${BIN_NAME}"

case ":${PATH}:" in
  *:"${BIN_DIR}":*) ;;
  *)
    echo ""
    echo "Note: ${BIN_DIR} is not on PATH."
    echo "Add with: fish_add_path ${BIN_DIR}"
    ;;
esac
