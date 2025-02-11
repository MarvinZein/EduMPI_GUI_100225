#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Set variables
QT_PATH="/home/marv/Qt"
QT_DIR="$QT_PATH/6.8.1/gcc_64"
TOOLS_DIR="$QT_PATH/Tools"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$PROJECT_ROOT/AppDir"
APP_NAME="GUI_Cluster"
EXECUTABLE="appGUI_Cluster"
DESKTOP_FILE="$PROJECT_ROOT/GUI_Cluster.desktop"
ICON_FILE="$PROJECT_ROOT/user.png"
OUTPUT_APPIMAGE="$APP_NAME-x86_64.AppImage"

# Clean up old build and AppDir
echo "Cleaning up old build and AppDir..."
rm -rf "$BUILD_DIR" "$APP_DIR" "$OUTPUT_APPIMAGE"

# Set environment variables for Qt
echo "Setting environment variables for Qt..."
export LD_LIBRARY_PATH="$QT_DIR/lib:$LD_LIBRARY_PATH"
export QMAKE="$QT_DIR/bin/qmake"
export PATH="$QT_DIR/bin:$PATH"

# Set QML_SOURCES_PATHS for linuxdeploy qt plugin
export QML_SOURCES_PATHS="$PROJECT_ROOT"
export DEPLOY_PLATFORM_THEMES=true

# Create build directory
echo "Creating build directory..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Run cmake and build the application
echo "Running cmake..."
"$TOOLS_DIR/CMake/bin/cmake" "$PROJECT_ROOT" -DQT_PATH="$QT_PATH" -DCMAKE_INSTALL_PREFIX=/usr || exit 1

echo "Building the application..."
make -j$(nproc) || exit 1

echo "Installing the application..."
make install DESTDIR="$APP_DIR" || exit 1

# Ensure .desktop file exists
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Error: Desktop file not found at $DESKTOP_FILE"
    exit 1
fi
mkdir -p "$APP_DIR/usr/share/applications/"
cp "$DESKTOP_FILE" "$APP_DIR/usr/share/applications/"

# Ensure icon file exists
if [ ! -f "$ICON_FILE" ]; then
    echo "Error: Icon file not found at $ICON_FILE"
    exit 1
fi
mkdir -p "$APP_DIR/usr/share/icons/hicolor/128x128/apps/"
cp "$ICON_FILE" "$APP_DIR/usr/share/icons/hicolor/128x128/apps/"

# Use linuxdeploy to bundle dependencies
echo "Running linuxdeploy..."
linuxdeploy --appdir "$APP_DIR" --plugin qt -d "$DESKTOP_FILE" -i "$ICON_FILE" --verbosity=2 || exit 1

# Create the AppImage
echo "Creating AppImage..."
linuxdeploy-plugin-appimage --appdir "$APP_DIR" || exit 1

# Completion
echo "AppImage created: $OUTPUT_APPIMAGE"
