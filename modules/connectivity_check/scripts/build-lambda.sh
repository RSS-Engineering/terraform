#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
LAMBDA_DIR="$MODULE_DIR/lambda"
BUILD_DIR="$MODULE_DIR/lambda-build"
OUTPUT_ZIP="$MODULE_DIR/lambda.zip"

echo "Building Lambda package with dependencies..."

# Clean previous build
rm -rf "$BUILD_DIR"
rm -f "$OUTPUT_ZIP"

# Create build directory
mkdir -p "$BUILD_DIR"

# Copy Lambda source files
cp "$LAMBDA_DIR/index.ts" "$BUILD_DIR/"
cp "$LAMBDA_DIR/package.json" "$BUILD_DIR/"

# Install production dependencies
cd "$BUILD_DIR"
npm install --production --no-package-lock

# Create zip with handler and node_modules
cd "$BUILD_DIR"
zip -r "$OUTPUT_ZIP" index.ts node_modules/

echo "Lambda package created: $OUTPUT_ZIP"
echo "Size: $(du -h "$OUTPUT_ZIP" | cut -f1)"

# Clean up build directory
rm -rf "$BUILD_DIR"
