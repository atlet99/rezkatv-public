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
    SOURCE_DIR="src/legacy/dist"
    IPK_SUFFIX="_legacy"
    APP_TITLE="RezkaTV"
    echo "Target: webOS 3.x-4.x (Chrome 38-53)"
else
    SOURCE_DIR="dist"
    IPK_SUFFIX=""
    APP_TITLE="RezkaTV"
    echo "Target: webOS 5+ (Chrome 68+)"
fi

echo ""

# Static metadata directory in repository
WEBOS_STATIC_DIR="webos"

# Isolated staging directory (prevents polluting webos/)
STAGING_DIR=$(mktemp -d "/tmp/rezkatv-webos-${BUILD_TYPE}.XXXXXX")
cleanup() {
    if [ -n "${STAGING_DIR:-}" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ ERROR: $SOURCE_DIR not found!"
    echo ""
    if [ "$BUILD_TYPE" = "legacy" ]; then
        echo "   Run: make -C src/legacy build"
    else
        echo "   Run: npm run build"
    fi
    exit 1
fi

echo "📁 Preparing staging directory..."
cp -R "$WEBOS_STATIC_DIR"/. "$STAGING_DIR"/

# Step 1: Clean previous webOS build files (except static assets)
echo "🧹 Step 1: Cleaning staging build files..."
rm -rf "$STAGING_DIR"/assets
rm -f "$STAGING_DIR"/index.html
rm -f "$STAGING_DIR"/*.js
rm -f "$STAGING_DIR"/*.css

# Step 2: Copy build output to webOS directory
echo "📋 Step 2: Copying $BUILD_TYPE build output..."
cp -r "$SOURCE_DIR"/* "$STAGING_DIR"/

# Step 3: Fix paths for WebOS file:// protocol
echo "🔧 Step 3: Fixing paths for file:// protocol..."

# Fix HTML paths (ensure relative paths)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    find "$STAGING_DIR" -name "*.html" -type f -exec sed -i '' 's|href="/|href="./|g; s|src="/|src="./|g' {} \;
    find "$STAGING_DIR" -name "*.html" -type f -exec sed -i '' 's| crossorigin=""||g; s| crossorigin||g' {} \;
else
    # Linux
    find "$STAGING_DIR" -name "*.html" -type f -exec sed -i 's|href="/|href="./|g; s|src="/|src="./|g' {} \;
    find "$STAGING_DIR" -name "*.html" -type f -exec sed -i 's| crossorigin=""||g; s| crossorigin||g' {} \;
fi

# Remove modulepreload links for modern build (file:// protocol compatibility)
if [ "$BUILD_TYPE" = "modern" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find "$STAGING_DIR" -name "*.html" -type f -exec sed -i '' 's|<link rel="modulepreload"[^>]*>||g' {} \;
    else
        find "$STAGING_DIR" -name "*.html" -type f -exec sed -i 's|<link rel="modulepreload"[^>]*>||g' {} \;
    fi
fi

# Step 3.5: Sync runtime files into ./webos for Simulator compatibility
echo "🔧 Step 3.5: Syncing runtime files to ./webos (Simulator)..."
rm -rf "$WEBOS_STATIC_DIR"/assets
rm -f "$WEBOS_STATIC_DIR"/index.html
rm -f "$WEBOS_STATIC_DIR"/*.js
rm -f "$WEBOS_STATIC_DIR"/*.css

if [ -d "$STAGING_DIR/assets" ]; then
    cp -R "$STAGING_DIR/assets" "$WEBOS_STATIC_DIR"/
fi
if [ -f "$STAGING_DIR/index.html" ]; then
    cp "$STAGING_DIR/index.html" "$WEBOS_STATIC_DIR"/index.html
fi
if compgen -G "$STAGING_DIR/*.js" > /dev/null; then
    cp "$STAGING_DIR"/*.js "$WEBOS_STATIC_DIR"/
fi
if compgen -G "$STAGING_DIR/*.css" > /dev/null; then
    cp "$STAGING_DIR"/*.css "$WEBOS_STATIC_DIR"/
fi

echo "   ✅ Runtime files synced to $WEBOS_STATIC_DIR"

# Step 4: Inject polyfills (if exists)
echo "🔧 Step 4: Adding polyfills (if available)..."
if [ -f "$STAGING_DIR/palmservicebridge-polyfill.js" ] && [ -f "$STAGING_DIR/index.html" ]; then
    # Check if already injected
    if ! grep -q "palmservicebridge-polyfill.js" "$STAGING_DIR/index.html"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/webOSTV\.js/i\
    <script src="./palmservicebridge-polyfill.js" charset="utf-8"></script>
' "$STAGING_DIR/index.html"
        else
            sed -i '/webOSTV\.js/i\    <script src="./palmservicebridge-polyfill.js" charset="utf-8"></script>' "$STAGING_DIR/index.html"
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
validate_png "$STAGING_DIR/icon.png" "icon.png (80x80)" || ICONS_VALID=false
validate_png "$STAGING_DIR/largeIcon.png" "largeIcon.png (130x130)" || ICONS_VALID=false

if [ "$ICONS_VALID" = false ]; then
    echo ""
    echo "❌ Icon validation failed!"
    exit 1
fi

# Step 6: Update appinfo.json with version and title
echo "🔧 Step 6: Updating appinfo.json..."

# Get version from package.json
VERSION=$(node -p "require('./package.json').version")

# Use different appinfo for different builds
if [ "$BUILD_TYPE" = "legacy" ] && [ -f "$STAGING_DIR/appinfo-legacy.json" ]; then
    echo "   📋 Using appinfo-legacy.json for webOS 3.x-4.x compatibility"
    cp "$STAGING_DIR/appinfo-legacy.json" "$STAGING_DIR/appinfo.json"
elif [ "$BUILD_TYPE" = "modern" ] && [ -f "$STAGING_DIR/appinfo-modern.json" ]; then
    echo "   📋 Using appinfo-modern.json for webOS 5+"
    cp "$STAGING_DIR/appinfo-modern.json" "$STAGING_DIR/appinfo.json"
fi

# Update appinfo.json version and title
if [ -f "$STAGING_DIR/appinfo.json" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" "$STAGING_DIR/appinfo.json"
        sed -i '' "s/\"title\": \"[^\"]*\"/\"title\": \"$APP_TITLE\"/g" "$STAGING_DIR/appinfo.json"
    else
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" "$STAGING_DIR/appinfo.json"
        sed -i "s/\"title\": \"[^\"]*\"/\"title\": \"$APP_TITLE\"/g" "$STAGING_DIR/appinfo.json"
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
        # ALWAYS use the unified service (ES5 compatible with Node.js v0.12.2)
        # We have replaced the ES6 service with the legacy one in the source tree.
        echo "   📋 Packaging service..."
        npx ares-package "$STAGING_DIR" service --outdir ./ --no-minify
    else
        npx ares-package "$STAGING_DIR" --outdir ./ --no-minify
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
