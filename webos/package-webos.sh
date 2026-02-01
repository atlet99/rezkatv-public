#!/bin/bash

# ============================================
# WebOS Packaging Script for RezkaTV
# Supports both Legacy and Modern builds
# ============================================
# 
# Usage:
#   ./package-webos.sh          - Package modern build (default)
#   ./package-webos.sh modern   - Package modern build (Vue 3)
#   ./package-webos.sh legacy   - Package legacy build (Vanilla JS)
#
# ============================================

set -e

# Build type: "legacy" or "modern" (default)
BUILD_TYPE=${1:-modern}

# Navigate to project root
cd "$(dirname "$0")/.."

echo ""
echo "============================================"
echo "📦 Packaging RezkaTV for webOS ($BUILD_TYPE)"
echo "============================================"

# Determine source directory and IPK suffix based on build type
if [ "$BUILD_TYPE" = "legacy" ]; then
    SOURCE_DIR="dist-legacy"
    IPK_SUFFIX="_legacy"
    APP_TITLE="RezkaTV"
    echo "Target: webOS 3.x-4.x (Chrome 38-53)"
else
    SOURCE_DIR="dist"
    IPK_SUFFIX=""
    APP_TITLE="RezkaTV"
    echo "Target: webOS 5.x+ (Chrome 68+)"
fi

echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ ERROR: $SOURCE_DIR not found!"
    echo ""
    if [ "$BUILD_TYPE" = "legacy" ]; then
        echo "   Run: node scripts/build-legacy.js"
    else
        echo "   Run: npm run build"
    fi
    exit 1
fi

# Step 1: Clean previous webOS build files (except static assets)
echo "🧹 Step 1: Cleaning previous build..."
rm -rf webos/assets
rm -f webos/index.html
rm -f webos/*.js
rm -f webos/*.css
# Keep: appinfo.json, icon.png, largeIcon.png, splash.png, etc.

# Step 2: Copy build output to webOS directory
echo "📋 Step 2: Copying $BUILD_TYPE build output..."
cp -r "$SOURCE_DIR"/* webos/

# Step 3: Fix paths for WebOS file:// protocol
echo "🔧 Step 3: Fixing paths for file:// protocol..."

# Fix HTML paths (ensure relative paths)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    find webos -name "*.html" -type f -exec sed -i '' 's|href="/|href="./|g; s|src="/|src="./|g' {} \;
    find webos -name "*.html" -type f -exec sed -i '' 's| crossorigin=""||g; s| crossorigin||g' {} \;
else
    # Linux
    find webos -name "*.html" -type f -exec sed -i 's|href="/|href="./|g; s|src="/|src="./|g' {} \;
    find webos -name "*.html" -type f -exec sed -i 's| crossorigin=""||g; s| crossorigin||g' {} \;
fi

# Remove modulepreload links for modern build (file:// protocol compatibility)
if [ "$BUILD_TYPE" = "modern" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find webos -name "*.html" -type f -exec sed -i '' 's|<link rel="modulepreload"[^>]*>||g' {} \;
    else
        find webos -name "*.html" -type f -exec sed -i 's|<link rel="modulepreload"[^>]*>||g' {} \;
    fi
fi

# Step 4: Inject polyfills (if exists)
echo "🔧 Step 4: Adding polyfills (if available)..."
if [ -f "webos/palmservicebridge-polyfill.js" ] && [ -f "webos/index.html" ]; then
    # Check if already injected
    if ! grep -q "palmservicebridge-polyfill.js" webos/index.html; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/webOSTV\.js/i\
    <script src="./palmservicebridge-polyfill.js" charset="utf-8"></script>
' webos/index.html
        else
            sed -i '/webOSTV\.js/i\    <script src="./palmservicebridge-polyfill.js" charset="utf-8"></script>' webos/index.html
        fi
        echo "   ✅ PalmServiceBridge polyfill injected"
    fi
fi

# Step 5: Validate icon formats
echo "🔍 Step 5: Validating icon formats..."

validate_png() {
    local file=$1
    local name=$2
    
    if [ ! -f "$file" ]; then
        echo "   ❌ ERROR: $file not found!"
        return 1
    fi
    
    format=$(file -b "$file" | head -1)
    if [[ ! "$format" =~ "PNG image data" ]]; then
        echo "   ❌ ERROR: $file is NOT a PNG file!"
        echo "      Detected: $format"
        return 1
    fi
    
    echo "   ✅ $name: valid PNG"
    return 0
}

ICONS_VALID=true
validate_png "webos/icon.png" "icon.png (80x80)" || ICONS_VALID=false
validate_png "webos/largeIcon.png" "largeIcon.png (130x130)" || ICONS_VALID=false

if [ "$ICONS_VALID" = false ]; then
    echo ""
    echo "❌ Icon validation failed!"
    exit 1
fi

# Step 6: Update appinfo.json with version and title
echo "🔧 Step 6: Updating appinfo.json..."

# Get version from package.json
VERSION=$(node -p "require('./package.json').version")

# Update appinfo.json version and title
if [ -f "webos/appinfo.json" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" webos/appinfo.json
        sed -i '' "s/\"title\": \"[^\"]*\"/\"title\": \"$APP_TITLE\"/g" webos/appinfo.json
    else
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" webos/appinfo.json
        sed -i "s/\"title\": \"[^\"]*\"/\"title\": \"$APP_TITLE\"/g" webos/appinfo.json
    fi
    echo "   ✅ Version: $VERSION"
    echo "   ✅ Title: $APP_TITLE"
fi

# Step 7: Package for webOS
echo "📦 Step 7: Creating webOS package..."

if npx ares-package --version &> /dev/null; then
    # Create package
    # Check if service directory exists
    if [ -d "service" ]; then
        npx ares-package webos service --outdir ./ --no-minify
    else
        npx ares-package webos --outdir ./ --no-minify
    fi
    
    # Rename IPK if legacy build
    if [ "$BUILD_TYPE" = "legacy" ]; then
        # Find the generated IPK and rename it
        IPK_FILE=$(ls -t com.rezkatv.app_*.ipk 2>/dev/null | grep -v "_legacy" | head -1)
        if [ -n "$IPK_FILE" ]; then
            NEW_NAME="${IPK_FILE%.ipk}_legacy.ipk"
            mv "$IPK_FILE" "$NEW_NAME"
            IPK_FILE="$NEW_NAME"
        fi
    else
        IPK_FILE=$(ls -t com.rezkatv.app_*.ipk 2>/dev/null | grep -v "_legacy" | head -1)
    fi
    
    echo ""
    echo "============================================"
    echo "✅ Package created successfully!"
    echo ""
    if [ -n "$IPK_FILE" ]; then
        echo "📦 File: $IPK_FILE"
        echo "📊 Size: $(du -h "$IPK_FILE" | cut -f1)"
        echo ""
        echo "To install:"
        if [ "$BUILD_TYPE" = "legacy" ]; then
            echo "   make install-legacy"
        else
            echo "   make install-modern"
        fi
        echo ""
        echo "SHA256:"
        shasum -a 256 "$IPK_FILE"
    fi
    echo "============================================"
else
    echo ""
    echo "⚠️  ares-package not found!"
    echo "   Install: npm install -D @webos-tools/cli"
    exit 1
fi
