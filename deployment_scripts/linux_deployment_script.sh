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

# Step 1: Create build directory
echo "Creating build directory..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Step 2: Run cmake and build the application
# Keep Mimer plugin present so CMake doesn't fail.
echo "Running cmake..."
"$TOOLS_DIR/CMake/bin/cmake" "$PROJECT_ROOT" -DQT_PATH="$QT_PATH" -DCMAKE_INSTALL_PREFIX=/usr || exit 1

echo "Building the application..."
make -j$(nproc) || exit 1

echo "Installing the application..."
make install DESTDIR="$APP_DIR" || exit 1

# Step 3: Verify AppDir Structure
echo "Verifying AppDir structure..."
if [ ! -f "$APP_DIR/usr/bin/$EXECUTABLE" ]; then
    echo "Error: Executable $EXECUTABLE not found in $APP_DIR/usr/bin/"
    exit 1
fi

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

# Step 4: Create Correct AppRun File
echo "Creating AppRun file..."
cat <<EOF > "$APP_DIR/AppRun"
#!/bin/bash
export QT_QPA_PLATFORMTHEME=GTK3
export GTK_THEME=Adwaita:dark
exec "\$APPDIR/usr/bin/$EXECUTABLE" "\$@"
EOF
chmod +x "$APP_DIR/AppRun"

MIMER_PLUGIN_SYS="$QT_DIR/plugins/sqldrivers/libqsqlmimer.so"
MIMER_PLUGIN_SYS_BAK_DIR="$QT_DIR/plugins/disabled_plugins"
MIMER_PLUGIN_SYS_BAK="$MIMER_PLUGIN_SYS_BAK_DIR/libqsqlmimer.so.bak"

MIMER_PLUGIN_APP="$APP_DIR/usr/lib/qt6/plugins/sqldrivers/libqsqlmimer.so"
MIMER_PLUGIN_APP_BAK_DIR="$APP_DIR/usr/lib/qt6/disabled_plugins"
MIMER_PLUGIN_APP_BAK="$MIMER_PLUGIN_APP_BAK_DIR/libqsqlmimer.so.bak"

# Move the Mimer SQL plugin out of the sqldrivers directory to avoid linuxdeploy detecting it
if [ -f "$MIMER_PLUGIN_SYS" ]; then
    echo "Moving Mimer SQL plugin out of sqldrivers directory (system)..."
    mkdir -p "$MIMER_PLUGIN_SYS_BAK_DIR"
    if [ ! -f "$MIMER_PLUGIN_SYS_BAK" ]; then
        mv "$MIMER_PLUGIN_SYS" "$MIMER_PLUGIN_SYS_BAK"
    else
        echo "System backup already exists, leaving original as is."
    fi
fi

if [ -f "$MIMER_PLUGIN_APP" ]; then
    echo "Moving Mimer SQL plugin out of sqldrivers directory (AppDir)..."
    mkdir -p "$MIMER_PLUGIN_APP_BAK_DIR"
    if [ ! -f "$MIMER_PLUGIN_APP_BAK" ]; then
        mv "$MIMER_PLUGIN_APP" "$MIMER_PLUGIN_APP_BAK"
    else
        echo "AppDir backup already exists, leaving original as is."
    fi
fi

# Step 5: Use linuxdeploy to bundle dependencies
echo "Running linuxdeploy..."
linuxdeploy --appdir "$APP_DIR" --plugin qt -d "$DESKTOP_FILE" -i "$ICON_FILE" --verbosity=2 || exit 1

# Step 6: Create the AppImage
echo "Creating AppImage..."
linuxdeploy-plugin-appimage --appdir "$APP_DIR" || exit 1

# Everything succeeded, restore the Mimer plugin if backups exist
echo "Restoring Mimer SQL plugin..."

if [ -f "$MIMER_PLUGIN_SYS_BAK" ]; then
    mv "$MIMER_PLUGIN_SYS_BAK" "$QT_DIR/plugins/sqldrivers/libqsqlmimer.so"
    echo "Restored Mimer SQL plugin to Qt installation."
fi

if [ -f "$MIMER_PLUGIN_APP_BAK" ]; then
    mv "$MIMER_PLUGIN_APP_BAK" "$APP_DIR/usr/lib/qt6/plugins/sqldrivers/libqsqlmimer.so"
    echo "Restored Mimer SQL plugin to AppDir."
fi

# Completion
echo "AppImage created: $OUTPUT_APPIMAGE"
