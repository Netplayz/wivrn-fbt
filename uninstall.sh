#!/bin/bash

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  WiVRn Full Body Tracking - Uninstallation Script           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Stop services
echo "⏹️  Stopping services..."
systemctl stop wivrn-fbt-webcam.service 2>/dev/null || true
systemctl stop wivrn-fbt.service 2>/dev/null || true
systemctl disable wivrn-fbt-webcam.service 2>/dev/null || true
systemctl disable wivrn-fbt.service 2>/dev/null || true
systemctl daemon-reload
echo "✓ Services stopped"

# Remove systemd services
echo ""
echo "🗑️  Removing systemd services..."
rm -f /etc/systemd/system/wivrn-fbt.service
rm -f /etc/systemd/system/wivrn-fbt-webcam.service
echo "✓ Services removed"

# Remove binaries
echo ""
echo "🗑️  Removing binaries..."
rm -f /usr/local/bin/wivrn-fbt-service
rm -f /usr/local/bin/wivrn-fbt-start
rm -f /usr/local/bin/wivrn-fbt-stop
rm -f /usr/local/bin/wivrn-fbt-status
rm -f /usr/local/bin/wivrn-fbt
echo "✓ Binaries removed"

# Remove directories
echo ""
echo "🗑️  Removing installation directories..."
rm -rf /opt/wivrn-fbt
rm -rf /etc/wivrn-fbt
rm -rf /var/log/wivrn-fbt
echo "✓ Installation directories removed"

# Optionally remove user config
echo ""
read -p "Remove user configuration (~/.wivrn-fbt)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/.wivrn-fbt
    echo "✓ User configuration removed"
else
    echo "⊘ User configuration preserved"
fi

echo ""
echo "✅ Uninstallation complete!"
echo ""
