#!/bin/bash

# WebOS Packaging Script for RezkaTV
# This script builds the Vue app and packages it for WebOS TV

set -e

echo "🚀 Building RezkaTV for WebOS..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Step 1: Build the Vue app
echo "📦 Step 1: Building Vue app..."
npm run build

# Step 2: Clean previous webOS build files
echo "🧹 Step 2: Cleaning previous build..."
rm -rf webos/dist webos/assets webos/*.html webos/*.js webos/*.css

# Step 3: Copy build output to webOS directory
echo "📋 Step 3: Copying build output..."
cp -r dist/* webos/

# Step 4: Fix paths for WebOS file:// protocol
echo "🔧 Step 4: Fixing paths for file:// protocol..."

# Fix HTML paths (already using relative paths from vite.config.ts base: './')
# Just ensure no absolute paths remain
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  find webos -name "*.html" -type f -exec sed -i '' 's|href="/|href="./|g; s|src="/|src="./|g' {} \;
  find webos -name "*.html" -type f -exec sed -i '' 's| crossorigin=""||g; s| crossorigin||g' {} \;
else
  # Linux
  find webos -name "*.html" -type f -exec sed -i 's|href="/|href="./|g; s|src="/|src="./|g' {} \;
  find webos -name "*.html" -type f -exec sed -i 's| crossorigin=""||g; s| crossorigin||g' {} \;
fi

# Remove modulepreload links (file:// protocol compatibility)
if [[ "$OSTYPE" == "darwin"* ]]; then
  find webos -name "*.html" -type f -exec sed -i '' 's|<link rel="modulepreload"[^>]*>||g' {} \;
else
  find webos -name "*.html" -type f -exec sed -i 's|<link rel="modulepreload"[^>]*>||g' {} \;
fi

# Step 5: Generate placeholder icons if not present
echo "🎨 Step 5: Checking icons..."
if [ ! -f "webos/icon.png" ]; then
  echo "⚠️  Warning: webos/icon.png not found. Please add an 80x80 PNG icon."
fi
if [ ! -f "webos/largeIcon.png" ]; then
  echo "⚠️  Warning: webos/largeIcon.png not found. Please add a 130x130 PNG icon."
fi

# Step 6: Package for WebOS (using npx ares-package)
echo "📦 Step 6: Creating webOS package..."
if npx ares-package --version &> /dev/null; then
  # Package app (webos directory) AND service (service directory)
  npx ares-package webos service --outdir ./ --no-minify
  echo "✅ webOS package created successfully!"
  
  # Get package filename
  IPK_FILE=$(ls -t com.rezkatv.app_*.ipk 2>/dev/null | head -1)
  
  if [ -n "$IPK_FILE" ]; then
    echo ""
    echo "📦 Package: $IPK_FILE"
    echo ""
    echo "To install on your TV:"
    echo "  make install"
    echo ""
    echo "To generate SHA256 hash for repository.json:"
    echo "  make hash"
  fi
else
  echo "⚠️  ares-package not found via npx."
  echo "   Use: npm install -D @webos-tools/cli"
fi

echo ""
echo "✅ Build complete! webOS app files are in: webos/"
