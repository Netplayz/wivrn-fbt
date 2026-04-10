#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  WiVRn Full Body Tracking - Ubuntu Installer                  ║"
echo "║  Webcam-based Pose Estimation for VR                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"

[ "$EUID" -eq 0 ] || { echo "❌ Run with sudo"; exit 1; }

UBUNTU_VERSION=$(lsb_release -rs)
echo "✓ Ubuntu $UBUNTU_VERSION"

# Update & install system packages
echo "📦 Installing dependencies..."
apt-get update -qq
apt-get install -y \
  python3 python3-pip python3-dev python3-venv \
  build-essential cmake git curl wget pkg-config \
  libglib2.0-0t64 libsm6 libxext6 libxrender-dev \
  libopencv-dev python3-opencv \
  libopenxr-dev libopenxr1-monado > /dev/null 2>&1

# Create directories
echo "📁 Setting up directories..."
mkdir -p /opt/wivrn-fbt /etc/wivrn-fbt /var/log/wivrn-fbt
chmod 755 /opt/wivrn-fbt /etc/wivrn-fbt /var/log/wivrn-fbt

# Install Python deps (flexible versions, skip apt management)
echo "🐍 Installing Python packages..."
pip3 install --break-system-packages --quiet \
  opencv-python \
  mediapipe \
  numpy \
  protobuf 2>/dev/null || pip3 install --break-system-packages \
  opencv-python \
  mediapipe \
  numpy \
  protobuf

# Build C++ service
echo "🔨 Building OpenXR service..."
rm -rf build
mkdir build && cd build
cmake .. > /dev/null 2>&1 && make > /dev/null 2>&1
if [ ! -f wivrn-fbt-service ]; then
  echo "❌ Build failed"
  exit 1
fi
cd ..

# Install binaries
echo "📥 Installing binaries..."
cp build/wivrn-fbt-service /usr/local/bin/
chmod +x /usr/local/bin/wivrn-fbt-service
cp webcam_tracker.py /opt/wivrn-fbt/
chmod +x /opt/wivrn-fbt/webcam_tracker.py
cp wivrn_fbt_config.json /etc/wivrn-fbt/config.json

# Install systemd services
echo "🔧 Installing systemd services..."
cp wivrn-fbt.service wivrn-fbt-webcam.service /etc/systemd/system/
systemctl daemon-reload

# Create helper commands
echo "📝 Creating commands..."
cat > /usr/local/bin/wivrn-fbt-start << 'HELPER'
#!/bin/bash
systemctl start wivrn-fbt.service wivrn-fbt-webcam.service
echo "✓ Services started"
echo "View logs: journalctl -u wivrn-fbt -f"
HELPER
chmod +x /usr/local/bin/wivrn-fbt-start

cat > /usr/local/bin/wivrn-fbt-stop << 'HELPER'
#!/bin/bash
systemctl stop wivrn-fbt-webcam.service wivrn-fbt.service
echo "✓ Services stopped"
HELPER
chmod +x /usr/local/bin/wivrn-fbt-stop

cat > /usr/local/bin/wivrn-fbt-status << 'HELPER'
#!/bin/bash
echo "=== Core Service ===" && systemctl status wivrn-fbt.service --no-pager 2>&1 | head -3
echo "=== Webcam Service ===" && systemctl status wivrn-fbt-webcam.service --no-pager 2>&1 | head -3
HELPER
chmod +x /usr/local/bin/wivrn-fbt-status

# User config
mkdir -p ~/.wivrn-fbt
cp /etc/wivrn-fbt/config.json ~/.wivrn-fbt/config.json

echo ""
echo "✅ Installation complete!"
echo ""
echo "Start:  wivrn-fbt-start"
echo "Stop:   wivrn-fbt-stop"
echo "Status: wivrn-fbt-status"
echo "Logs:   journalctl -u wivrn-fbt -f"
echo ""
