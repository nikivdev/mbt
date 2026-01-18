#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Building ctx..."
moon build --target native

echo "Installing to ~/bin..."
cp _build/native/release/build/cli/cli.exe ~/bin/ctx
chmod +x ~/bin/ctx

echo "ctx installed"
