#!/bin/bash

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  WiVRn Full Body Tracking - Installation Script             ║"
echo "║  Ubuntu Linux - Webcam-based Pose Estimation               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo "✓ Ubuntu version: $UBUNTU_VERSION"

# Update package manager
echo ""
echo "📦 Updating package manager..."
apt-get update -qq

# Install system dependencies
echo "📦 Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libopencv-dev \
    python3-opencv \
    mesa-utils \
    vulkan-tools > /dev/null 2>&1

echo "✓ System dependencies installed"

# Install OpenXR SDK
echo ""
echo "📦 Installing OpenXR SDK..."
if ! dpkg -l | grep -q "openxr-sdk"; then
    apt-get install -y \
        libopenxr-dev \
        libopenxr1 > /dev/null 2>&1
    echo "✓ OpenXR SDK installed"
else
    echo "✓ OpenXR SDK already installed"
fi

# Create directories
echo ""
echo "📁 Creating directory structure..."
mkdir -p /opt/wivrn-fbt
mkdir -p /etc/wivrn-fbt
mkdir -p /var/log/wivrn-fbt
mkdir -p ~/.wivrn-fbt
chmod 755 /opt/wivrn-fbt
chmod 755 /etc/wivrn-fbt
chmod 755 /var/log/wivrn-fbt
chmod 755 ~/.wivrn-fbt

echo "✓ Directories created"

# Install Python dependencies
echo ""
echo "📦 Installing Python dependencies..."
pip3 install --upgrade pip setuptools wheel > /dev/null 2>&1
pip3 install -r requirements.txt > /dev/null 2>&1
echo "✓ Python dependencies installed"

# Build C++ service
echo ""
echo "🔨 Building C++ OpenXR service..."
if [ -d "build" ]; then
    rm -rf build
fi
mkdir -p build
cd build
cmake .. > /dev/null 2>&1
make > /dev/null 2>&1
cd ..

if [ -f "build/wivrn-fbt-service" ]; then
    echo "✓ C++ service built successfully"
else
    echo "❌ C++ service build failed"
    exit 1
fi

# Install binaries
echo ""
echo "📥 Installing binaries..."
cp build/wivrn-fbt-service /usr/local/bin/
chmod +x /usr/local/bin/wivrn-fbt-service
cp webcam_tracker.py /opt/wivrn-fbt/
chmod +x /opt/wivrn-fbt/webcam_tracker.py
cp wivrn_fbt_config.json /etc/wivrn-fbt/config.json
cp requirements.txt /opt/wivrn-fbt/

echo "✓ Binaries installed"

# Install systemd services
echo ""
echo "🔧 Installing systemd services..."
cp wivrn-fbt.service /etc/systemd/system/
cp wivrn-fbt-webcam.service /etc/systemd/system/
systemctl daemon-reload
echo "✓ Systemd services installed"

# Create startup script
echo ""
echo "📝 Creating startup script..."
cat > /usr/local/bin/wivrn-fbt-start << 'EOF'
#!/bin/bash
echo "Starting WiVRn Full Body Tracking..."
systemctl start wivrn-fbt.service
systemctl start wivrn-fbt-webcam.service
echo "Services started. View logs with: journalctl -u wivrn-fbt -f"
EOF
chmod +x /usr/local/bin/wivrn-fbt-start

cat > /usr/local/bin/wivrn-fbt-stop << 'EOF'
#!/bin/bash
echo "Stopping WiVRn Full Body Tracking..."
systemctl stop wivrn-fbt-webcam.service
systemctl stop wivrn-fbt.service
echo "Services stopped"
EOF
chmod +x /usr/local/bin/wivrn-fbt-stop

cat > /usr/local/bin/wivrn-fbt-status << 'EOF'
#!/bin/bash
echo "=== WiVRn FBT Service Status ==="
systemctl status wivrn-fbt.service --no-pager
echo ""
echo "=== WiVRn FBT Webcam Status ==="
systemctl status wivrn-fbt-webcam.service --no-pager
EOF
chmod +x /usr/local/bin/wivrn-fbt-status

echo "✓ Startup scripts created"

# Test camera access
echo ""
echo "📹 Testing camera access..."
if [ -c /dev/video0 ]; then
    echo "✓ Camera device /dev/video0 found"
else
    echo "⚠️  Camera device /dev/video0 not found"
    echo "   Available video devices:"
    ls -la /dev/video* 2>/dev/null || echo "   None found"
fi

# Create config file in user home
echo ""
echo "⚙️  Initializing configuration..."
cp /etc/wivrn-fbt/config.json ~/.wivrn-fbt/config.json
chmod 644 ~/.wivrn-fbt/config.json
echo "✓ Configuration file created: ~/.wivrn-fbt/config.json"

# Verification
echo ""
echo "✅ Installation complete!"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Next Steps:                                                 ║"
echo "║  1. Verify WiVRn is installed: wivrn-server --version        ║"
echo "║  2. Start the service: wivrn-fbt-start                       ║"
echo "║  3. Monitor logs: journalctl -u wivrn-fbt -f                 ║"
echo "║  4. Check status: wivrn-fbt-status                           ║"
echo "║  5. Edit config: nano ~/.wivrn-fbt/config.json               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Uninstall: sudo bash uninstall.sh                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
