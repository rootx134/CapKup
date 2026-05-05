#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building release binary..."
swift build -c release 2>&1

echo "📦 Creating CapKupSync.app bundle..."
rm -rf CapKupSync.app CapKupSync.dmg
mkdir -p CapKupSync.app/Contents/MacOS
mkdir -p CapKupSync.app/Contents/Resources

cp .build/release/CapKup CapKupSync.app/Contents/MacOS/CapKupSync
cp Info.plist CapKupSync.app/Contents/
cp CapKup.icns CapKupSync.app/Contents/Resources/AppIcon.icns

# Bundle OAuth config
if [ -f "OAuthConfig.plist" ]; then
    cp OAuthConfig.plist CapKupSync.app/Contents/Resources/OAuthConfig.plist
    echo "🔑 OAuthConfig.plist bundled into app."
else
    echo "⚠️  OAuthConfig.plist not found! App won't authenticate."
fi

# Cập nhật CFBundleExecutable để khớp với tên binary mới
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable CapKupSync" CapKupSync.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName CapKupSync" CapKupSync.app/Contents/Info.plist

touch CapKupSync.app

echo "🗂  Preparing DMG contents..."
rm -rf dmg_staging
mkdir -p dmg_staging
mv CapKupSync.app dmg_staging/
ln -s /Applications dmg_staging/Applications

echo "💿 Creating DMG..."
hdiutil create -volname "CapKupSync" -srcfolder dmg_staging -ov -format UDZO CapKupSync.dmg

# Copy ra Desktop
cp CapKupSync.dmg ~/Desktop/CapKupSync.dmg

echo ""
echo "✅ Hoàn tất! DMG đã được tạo:"
echo "   $(pwd)/CapKupSync.dmg"
echo "   ~/Desktop/CapKupSync.dmg"
