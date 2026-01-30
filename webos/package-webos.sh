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
rm -rf webos/dist webos/assets webos/index.html webos/*.js webos/*.css

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

# Step 5: Copy PalmServiceBridge polyfill and inject into index.html (optional)
echo "🔧 Step 5: Adding PalmServiceBridge polyfill (optional)..."
if [ -f "webos/palmservicebridge-polyfill.js" ] && [ -f "webos/index.html" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Use sed with backup
    sed -i '' '/webOSTV\.js/i\
    <script src="./palmservicebridge-polyfill.js" charset="utf-8"></script>
' webos/index.html
  else
    # Linux: Use sed
    sed -i '/webOSTV\.js/i\    <script src="./palmservicebridge-polyfill.js" charset="utf-8"></script>' webos/index.html
  fi
  echo "✅ PalmServiceBridge polyfill injected into index.html"
fi

# Step 6: Validate icon formats (must be real PNG, not JPEG with .png extension)
echo "🔍 Step 6: Validating icon formats..."

validate_png() {
  local file=$1
  local name=$2
  
  if [ ! -f "$file" ]; then
    echo "❌ ERROR: $file not found!"
    echo "   Please add a PNG icon for $name."
    return 1
  fi
  
  format=$(file -b "$file" | head -1)
  if [[ ! "$format" =~ "PNG image data" ]]; then
    echo "❌ ERROR: $file is NOT a PNG file!"
    echo "   Detected: $format"
    echo "   Required: PNG image data with RGBA"
    echo ""
    echo "   To fix, convert the image to PNG:"
    echo "   magick $file -depth 8 PNG32:$file"
    return 1
  fi
  
  # Check for RGBA (alpha channel) - optional warning
  if [[ ! "$format" =~ "RGBA" ]] && [[ ! "$format" =~ "alpha" ]]; then
    echo "⚠️  WARNING: $file may not have transparency (RGBA)"
    echo "   Detected: $format"
    echo "   Icons look better with transparent background in webOS launcher."
  fi
  
  echo "✅ $name: valid PNG ($format)"
  return 0
}

# Validate required icons
ICONS_VALID=true
validate_png "webos/icon.png" "icon.png (80x80)" || ICONS_VALID=false
validate_png "webos/largeIcon.png" "largeIcon.png (130x130)" || ICONS_VALID=false

if [ "$ICONS_VALID" = false ]; then
  echo ""
  echo "❌ Icon validation failed! Fix icons before packaging."
  exit 1
fi

echo "✅ All icons validated successfully"

# Step 7: Package for WebOS (using npx ares-package)
echo "📦 Step 7: Creating webOS package..."
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
