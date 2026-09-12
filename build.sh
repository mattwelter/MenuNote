#!/bin/bash
# Builds MenuNote.app — run this from inside the MenuNote folder:
#   chmod +x build.sh && ./build.sh
set -e

APP="MenuNote"
rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS"
mkdir -p "$APP.app/Contents/Resources"

echo "Compiling MenuNote v2.6..."
swiftc -O Sources/*.swift -o "$APP.app/Contents/MacOS/$APP"

cp Info.plist "$APP.app/Contents/Info.plist"

if [ -d AppIcon.iconset ]; then
  echo "Building app icon..."
  iconutil -c icns AppIcon.iconset -o "$APP.app/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signature so macOS will run it locally
codesign --force --sign - "$APP.app"

echo ""
echo "✅ Built $APP.app"
echo "   • Double-click it, or run:  open $APP.app"
echo "   • To keep it: drag $APP.app into /Applications"
