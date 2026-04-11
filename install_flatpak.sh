#!/bin/bash

# WiVRn Full Body Tracking - WiVRn Flatpak Integration
# Detects and installs into WiVRn Flatpak environment
# App ID: io.github.wivrn.wivrn

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  WiVRn FBT - Flatpak Integration                              ║"
echo "║  Installing into io.github.wivrn.wivrn                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Detect WiVRn Flatpak (correct app ID)
WIVRN_FLATPAK_DIR="${HOME}/.var/app/io.github.wivrn.wivrn"
WIVRN_DATA_DIR="${WIVRN_FLATPAK_DIR}/data"
WIVRN_CONFIG_DIR="${WIVRN_FLATPAK_DIR}/config"

if [ ! -d "$WIVRN_FLATPAK_DIR" ]; then
    echo "❌ WiVRn Flatpak not found at: $WIVRN_FLATPAK_DIR"
    echo ""
    echo "Install WiVRn first:"
    echo "  flatpak install flathub io.github.wivrn.wivrn"
    echo ""
    exit 1
fi

echo "✓ Found WiVRn Flatpak at: $WIVRN_FLATPAK_DIR"
echo ""

# Create FBT directories inside Flatpak structure
echo "📁 Creating FBT directories in Flatpak..."
mkdir -p "$WIVRN_DATA_DIR/wivrn-fbt"
mkdir -p "$WIVRN_CONFIG_DIR/wivrn-fbt"
echo "✓ Directories created"
echo ""

# Copy Python tracker to Flatpak data directory
echo "📦 Installing Python tracker..."
if [ -f "./webcam_tracker_flatpak.py" ]; then
    cp webcam_tracker_flatpak.py "$WIVRN_DATA_DIR/wivrn-fbt/"
    chmod +x "$WIVRN_DATA_DIR/wivrn-fbt/webcam_tracker_flatpak.py"
    echo "✓ Tracker installed"
else
    echo "❌ webcam_tracker_flatpak.py not found in current directory"
    exit 1
fi
echo ""

# Copy configuration
echo "⚙️  Installing configuration..."
if [ -f "./wivrn_fbt_config.json" ]; then
    cp wivrn_fbt_config.json "$WIVRN_CONFIG_DIR/wivrn-fbt/config.json"
    chmod 644 "$WIVRN_CONFIG_DIR/wivrn-fbt/config.json"
    echo "✓ Configuration installed"
else
    echo "❌ wivrn_fbt_config.json not found"
    exit 1
fi
echo ""

# Create Flatpak launcher script
echo "📝 Creating Flatpak launcher..."
mkdir -p "${HOME}/.local/bin"

cat > "${HOME}/.local/bin/wivrn-fbt-flatpak" << 'LAUNCHER'
#!/bin/bash

# WiVRn FBT Launcher for Flatpak
# Runs tracker inside WiVRn Flatpak sandbox
# App ID: io.github.wivrn.wivrn

WIVRN_FLATPAK_DIR="${HOME}/.var/app/io.github.wivrn.wivrn"
TRACKER_PATH="${WIVRN_FLATPAK_DIR}/data/wivrn-fbt/webcam_tracker_flatpak.py"
CONFIG_PATH="${WIVRN_FLATPAK_DIR}/config/wivrn-fbt/config.json"

if [ ! -f "$TRACKER_PATH" ]; then
    echo "❌ Tracker not found at: $TRACKER_PATH"
    echo "Run: bash install_flatpak.sh"
    exit 1
fi

echo "🎮 Starting WiVRn FBT in Flatpak..."
echo "Config: $CONFIG_PATH"
echo ""

# Run inside Flatpak with host access
flatpak run \
    --share=network \
    --device=all \
    --filesystem=host \
    --env=PYTHONUNBUFFERED=1 \
    --env=XR_RUNTIME_JSON=/run/user/1000/wivrn-openxr.json \
    io.github.wivrn.wivrn \
    python3 "$TRACKER_PATH" \
    --config "$CONFIG_PATH" \
    --camera-id 0 \
    --enable-preview
LAUNCHER

chmod +x "${HOME}/.local/bin/wivrn-fbt-flatpak"
echo "✓ Launcher created: ~/.local/bin/wivrn-fbt-flatpak"
echo ""

# Create systemd user service for Flatpak
echo "🔧 Creating systemd user service..."
mkdir -p "${HOME}/.config/systemd/user"

cat > "${HOME}/.config/systemd/user/wivrn-fbt-flatpak.service" << 'SERVICE'
[Unit]
Description=WiVRn Full Body Tracking (Flatpak)
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/wivrn-fbt-flatpak
Restart=on-failure
RestartSec=5

StandardOutput=journal
StandardError=journal
SyslogIdentifier=wivrn-fbt-flatpak

Environment="PATH=%h/.local/bin:/usr/bin:/bin"

[Install]
WantedBy=default.target
SERVICE

systemctl --user daemon-reload
echo "✓ Systemd user service created"
echo ""

# Create wrapper scripts
echo "📝 Creating wrapper scripts..."

cat > "${HOME}/.local/bin/wivrn-fbt-start-flatpak" << 'STARTWRAPPER'
#!/bin/bash
echo "Starting WiVRn FBT (Flatpak mode)..."
systemctl --user start wivrn-fbt-flatpak.service
sleep 2
echo "✓ Service started"
echo "View logs: journalctl --user -u wivrn-fbt-flatpak -f"
STARTWRAPPER
chmod +x "${HOME}/.local/bin/wivrn-fbt-start-flatpak"

cat > "${HOME}/.local/bin/wivrn-fbt-stop-flatpak" << 'STOPWRAPPER'
#!/bin/bash
echo "Stopping WiVRn FBT (Flatpak mode)..."
systemctl --user stop wivrn-fbt-flatpak.service
echo "✓ Service stopped"
STOPWRAPPER
chmod +x "${HOME}/.local/bin/wivrn-fbt-stop-flatpak"

cat > "${HOME}/.local/bin/wivrn-fbt-status-flatpak" << 'STATUSWRAPPER'
#!/bin/bash
echo "=== WiVRn FBT Status (Flatpak) ==="
systemctl --user status wivrn-fbt-flatpak.service --no-pager
echo ""
echo "Logs:"
journalctl --user -u wivrn-fbt-flatpak -n 20 --no-pager
STATUSWRAPPER
chmod +x "${HOME}/.local/bin/wivrn-fbt-status-flatpak"

echo "✓ Wrapper scripts created"
echo ""

# Create config editor script
cat > "${HOME}/.local/bin/wivrn-fbt-config-flatpak" << 'CONFIGWRAPPER'
#!/bin/bash
CONFIG_PATH="${HOME}/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/config.json"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "❌ Config not found at: $CONFIG_PATH"
    exit 1
fi
${EDITOR:-nano} "$CONFIG_PATH"
CONFIGWRAPPER
chmod +x "${HOME}/.local/bin/wivrn-fbt-config-flatpak"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ WiVRn FBT Flatpak Installation Complete!                  ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Quick Start:                                                  ║"
echo "║                                                                ║"
echo "║  Start:   wivrn-fbt-start-flatpak                             ║"
echo "║  Stop:    wivrn-fbt-stop-flatpak                              ║"
echo "║  Status:  wivrn-fbt-status-flatpak                            ║"
echo "║  Config:  wivrn-fbt-config-flatpak                            ║"
echo "║  Logs:    journalctl --user -u wivrn-fbt-flatpak -f           ║"
echo "║                                                                ║"
echo "║  Direct:  wivrn-fbt-flatpak  (runs once, shows preview)       ║"
echo "║                                                                ║"
echo "║  Paths (io.github.wivrn.wivrn):                                ║"
echo "║  Tracker: $WIVRN_DATA_DIR/wivrn-fbt/webcam_tracker_flatpak.py ║"
echo "║  Config:  $WIVRN_CONFIG_DIR/wivrn-fbt/config.json             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Ensure ~/.local/bin is in your PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
