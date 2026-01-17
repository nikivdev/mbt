#!/bin/bash

# Quick setup script for Maria Java SDK
# Run this after installing Java and Maven

set -e

echo "🚀 Maria Java SDK - Quick Setup"
echo "================================"
echo ""

# Check Java
echo "Checking Java installation..."
if ! command -v java &> /dev/null; then
    echo "❌ Java not found! Please install Java 17 or higher:"
    echo "   brew install openjdk@17"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo "❌ Java version too old (found $JAVA_VERSION, need 17+)"
    echo "   brew install openjdk@17"
    exit 1
fi
echo "✓ Java $JAVA_VERSION found"

# Check Maven
echo "Checking Maven installation..."
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven not found! Please install Maven:"
    echo "   brew install maven"
    exit 1
fi
echo "✓ Maven found"

# Get the SDK directory
SDK_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build the SDK
echo ""
echo "Building Maria Java SDK..."
cd "$SDK_DIR"
mvn clean package -q
echo "✓ SDK built successfully"

# Try to run the example
echo ""
echo "Running example..."
cd "$SDK_DIR/examples"
mvn compile exec:java -q

echo ""
echo "✓ Setup complete! You're ready to use Maria in Java!"
echo ""
echo "Next steps:"
echo "  1. Check out examples/Main.java"
echo "  2. Read README.md for more examples"
echo "  3. Create your own Java programs with Maria!"
