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
cp "$LAMBDA_DIR/tsconfig.json" "$BUILD_DIR/"
cp "$LAMBDA_DIR/.npmrc" "$BUILD_DIR/"

# Install all dependencies (including devDependencies for TypeScript compilation)
cd "$BUILD_DIR"
npm install --no-package-lock

# Compile TypeScript to JavaScript
echo "Compiling TypeScript..."
npx tsc

# Remove TypeScript source and dev dependencies
rm -f index.ts tsconfig.json
npm prune --production

# Create zip with compiled handler and node_modules
cd "$BUILD_DIR"
zip -r "$OUTPUT_ZIP" index.js node_modules/

echo "Lambda package created: $OUTPUT_ZIP"
echo "Size: $(du -h "$OUTPUT_ZIP" | cut -f1)"

# Clean up build directory
rm -rf "$BUILD_DIR"
