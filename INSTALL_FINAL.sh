#!/bin/bash

# WiVRn Full Body Tracking - Final Installation Script
# Ubuntu 25.10 compatible, handles all edge cases

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  WiVRn Full Body Tracking - Installation                      ║"
echo "║  Complete VR Pose Estimation System                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Must run with sudo: sudo bash install.sh"
    exit 1
fi

# Detect OS
if ! command -v lsb_release &> /dev/null; then
    echo "❌ lsb_release not found. Unsupported system."
    exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs)
echo "✓ Ubuntu $UBUNTU_VERSION detected"
echo ""

# Step 1: Update package manager
echo "📦 Step 1: Updating package manager..."
apt-get update -qq 2>/dev/null || apt-get update
echo "✓ Package manager updated"
echo ""

# Step 2: Install system dependencies
echo "📦 Step 2: Installing system dependencies..."
PACKAGES="python3 python3-pip python3-dev build-essential cmake git curl wget pkg-config"
PACKAGES="$PACKAGES libglib2.0-0t64 libsm6 libxext6 libxrender-dev"
PACKAGES="$PACKAGES libopencv-dev python3-opencv libopenxr-dev libopenxr1-monado"

apt-get install -y $PACKAGES > /dev/null 2>&1 || {
    echo "Installing with visible output..."
    apt-get install -y $PACKAGES
}
echo "✓ System dependencies installed"
echo ""

# Step 3: Create directories
echo "📁 Step 3: Creating directories..."
mkdir -p /opt/wivrn-fbt
mkdir -p /etc/wivrn-fbt
mkdir -p /var/log/wivrn-fbt
chmod 755 /opt/wivrn-fbt /etc/wivrn-fbt /var/log/wivrn-fbt
echo "✓ Directories created"
echo ""

# Step 4: Install Python packages
echo "🐍 Step 4: Installing Python packages..."
pip3 install --break-system-packages --quiet \
    opencv-python \
    mediapipe \
    numpy \
    protobuf 2>/dev/null || {
    echo "Installing with output..."
    pip3 install --break-system-packages \
        opencv-python \
        mediapipe \
        numpy \
        protobuf
}
echo "✓ Python packages installed"
echo ""

# Step 5: Clean old build
echo "🔨 Step 5: Building C++ service..."
[ -d build ] && rm -rf build
mkdir -p build
cd build

# Step 6: CMake configuration
if ! cmake .. 2>&1 | tee cmake.log; then
    echo "❌ CMake failed. Showing logs:"
    cat cmake.log
    exit 1
fi

# Step 7: Make
if ! make 2>&1 | tee make.log; then
    echo "❌ Make failed. Showing logs:"
    cat make.log
    exit 1
fi

cd ..

# Step 8: Verify binary
if [ ! -f build/wivrn-fbt-service ]; then
    echo "❌ Binary not created. Check logs in build/"
    exit 1
fi
echo "✓ C++ service built successfully"
echo ""

# Step 9: Install binaries
echo "📥 Step 9: Installing binaries..."
cp build/wivrn-fbt-service /usr/local/bin/
chmod +x /usr/local/bin/wivrn-fbt-service

cp webcam_tracker.py /opt/wivrn-fbt/
chmod +x /opt/wivrn-fbt/webcam_tracker.py

cp wivrn_fbt_config.json /etc/wivrn-fbt/config.json
chmod 644 /etc/wivrn-fbt/config.json

echo "✓ Binaries installed"
echo ""

# Step 10: Install systemd services
echo "🔧 Step 10: Installing systemd services..."
cp wivrn-fbt.service /etc/systemd/system/
cp wivrn-fbt-webcam.service /etc/systemd/system/
chmod 644 /etc/systemd/system/wivrn-fbt*.service
systemctl daemon-reload
echo "✓ Systemd services installed"
echo ""

# Step 11: Create helper commands
echo "📝 Step 11: Creating helper commands..."

cat > /usr/local/bin/wivrn-fbt-start << 'STARTSCRIPT'
#!/bin/bash
echo "Starting WiVRn Full Body Tracking..."
systemctl start wivrn-fbt.service
sleep 1
systemctl start wivrn-fbt-webcam.service
sleep 1
echo ""
echo "✓ Services started"
echo ""
echo "View logs:"
echo "  journalctl -u wivrn-fbt -f"
echo "  journalctl -u wivrn-fbt-webcam -f"
STARTSCRIPT
chmod +x /usr/local/bin/wivrn-fbt-start

cat > /usr/local/bin/wivrn-fbt-stop << 'STOPSCRIPT'
#!/bin/bash
echo "Stopping WiVRn Full Body Tracking..."
systemctl stop wivrn-fbt-webcam.service
systemctl stop wivrn-fbt.service
echo "✓ Services stopped"
STOPSCRIPT
chmod +x /usr/local/bin/wivrn-fbt-stop

cat > /usr/local/bin/wivrn-fbt-status << 'STATUSSCRIPT'
#!/bin/bash
echo "=== WiVRn FBT Status ==="
echo ""
systemctl status wivrn-fbt.service --no-pager 2>&1 | head -5
echo ""
systemctl status wivrn-fbt-webcam.service --no-pager 2>&1 | head -5
echo ""
echo "Installed files:"
echo "  Binary: $(ls -lh /usr/local/bin/wivrn-fbt-service 2>/dev/null | awk '{print $NF, $5}' || echo 'NOT FOUND')"
echo "  Tracker: $(ls -lh /opt/wivrn-fbt/webcam_tracker.py 2>/dev/null | awk '{print $NF, $5}' || echo 'NOT FOUND')"
echo "  Config: $(ls -lh /etc/wivrn-fbt/config.json 2>/dev/null | awk '{print $NF, $5}' || echo 'NOT FOUND')"
STATUSSCRIPT
chmod +x /usr/local/bin/wivrn-fbt-status

echo "✓ Helper commands installed"
echo ""

# Step 12: User configuration
echo "⚙️  Step 12: Initializing user configuration..."
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
else
    USER_HOME=$HOME
fi

mkdir -p "$USER_HOME/.wivrn-fbt"
cp /etc/wivrn-fbt/config.json "$USER_HOME/.wivrn-fbt/config.json"
chmod 644 "$USER_HOME/.wivrn-fbt/config.json"
echo "✓ User config: $USER_HOME/.wivrn-fbt/config.json"
echo ""

# Step 13: Verify installation
echo "✅ Verification..."
FAILED=0

[ -f /usr/local/bin/wivrn-fbt-service ] && echo "  ✓ Core service binary" || { echo "  ❌ Core service binary"; FAILED=1; }
[ -f /opt/wivrn-fbt/webcam_tracker.py ] && echo "  ✓ Webcam tracker" || { echo "  ❌ Webcam tracker"; FAILED=1; }
[ -f /etc/systemd/system/wivrn-fbt.service ] && echo "  ✓ Systemd service files" || { echo "  ❌ Systemd service files"; FAILED=1; }
[ -f /usr/local/bin/wivrn-fbt-start ] && echo "  ✓ Start/stop commands" || { echo "  ❌ Start/stop commands"; FAILED=1; }

if [ $FAILED -eq 1 ]; then
    echo ""
    echo "❌ Installation incomplete. Check errors above."
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Installation Complete!                                    ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Quick Start:                                                  ║"
echo "║                                                                ║"
echo "║  $ wivrn-fbt-start              # Start services              ║"
echo "║  $ wivrn-fbt-status             # Check status                ║"
echo "║  $ journalctl -u wivrn-fbt -f   # View logs                   ║"
echo "║  $ wivrn-fbt-stop               # Stop services               ║"
echo "║                                                                ║"
echo "║  Configuration:                                                ║"
echo "║  $ nano ~/.wivrn-fbt/config.json                              ║"
echo "║                                                                ║"
echo "║  Uninstall:                                                    ║"
echo "║  $ sudo bash uninstall.sh                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
