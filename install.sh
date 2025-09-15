#!/bin/bash

# This script compiles a universal binary and installs the volume_limiter daemon.

# Configuration
BINARY_NAME="volume_limiter"
SOURCE_FILE="volume_limiter.go"
PLIST_NAME="com.user.volumelimiter.plist"
INSTALL_DIR="/usr/local/bin"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST_PATH="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"
LABEL="com.user.volumelimiter"

echo "Starting installation of Volume Limiter..."

# Step 1: Check for Go compiler
if ! command -v go &> /dev/null
then
    echo "Go compiler not found. Please install Go (https://golang.org/doc/install) and try again."
    exit 1
fi

# Step 2: Compile universal binary for both ARM64 (Apple Silicon) and AMD64 (Intel)
ARM64_BINARY="${BINARY_NAME}_arm64"
AMD64_BINARY="${BINARY_NAME}_amd64"

echo "Compiling for Apple Silicon (arm64)..."
GOOS=darwin GOARCH=arm64 go build -o ${ARM64_BINARY} ${SOURCE_FILE}
if [ $? -ne 0 ]; then
    echo "ARM64 compilation failed."
    exit 1
fi

echo "Compiling for Intel (amd64)..."
GOOS=darwin GOARCH=amd64 go build -o ${AMD64_BINARY} ${SOURCE_FILE}
if [ $? -ne 0 ]; then
    echo "AMD64 compilation failed."
    rm ${ARM64_BINARY} # Clean up the successful arm build
    exit 1
fi

echo "Creating Universal Binary with lipo..."
lipo -create -output ${BINARY_NAME} ${ARM64_BINARY} ${AMD64_BINARY}
if [ $? -ne 0 ]; then
    echo "Failed to create universal binary with lipo."
    rm ${ARM64_BINARY} ${AMD64_BINARY}
    exit 1
fi

echo "Cleaning up intermediate binaries..."
rm ${ARM64_BINARY} ${AMD64_BINARY}
echo "Universal binary created successfully."

# Step 3: Move the binary to the installation directory
echo "Installing binary to ${INSTALL_DIR}..."
# The mv command might require admin privileges.
sudo mv ${BINARY_NAME} ${INSTALL_DIR}/
if [ $? -ne 0 ]; then
    echo "Failed to move binary. You may be prompted for your password."
    sudo mv ${BINARY_NAME} ${INSTALL_DIR}/
fi

# Step 4: Create LaunchAgents directory if it doesn't exist
mkdir -p "${LAUNCH_AGENTS_DIR}"

# Step 5: Update and install the plist file
echo "Installing launchd agent configuration to ${PLIST_DEST_PATH}..."
# Use sed to replace the placeholder path with the actual install directory
sed "s|<string>/usr/local/bin/volume_limiter</string>|<string>${INSTALL_DIR}/${BINARY_NAME}</string>|g" ${PLIST_NAME} > "${PLIST_DEST_PATH}"

# Step 6: Unload any existing version of the agent to ensure a clean start
echo "Unloading any existing agent..."
launchctl unload "${PLIST_DEST_PATH}" 2>/dev/null

# Step 7: Load the launch agent
echo "Loading the new agent..."
launchctl load "${PLIST_DEST_PATH}"

if launchctl list | grep -q ${LABEL}; then
    echo "✅ Volume Limiter daemon has been successfully installed and started!"
    echo "To set a volume limit, use: ${BINARY_NAME} -p <percentage>"
    echo "For example, to limit volume to 75%: ${BINARY_NAME} -p 75"
else
    echo "❌ Installation failed. The launchd agent could not be started."
    echo "Check logs at /tmp/volume_limiter_error.log for details."
fi

