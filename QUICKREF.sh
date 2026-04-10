#!/bin/bash

# WiVRn Full Body Tracking - Quick Reference
# ============================================

cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════╗
║                    WiVRn FBT - Quick Reference                        ║
╚════════════════════════════════════════════════════════════════════════╝

INSTALLATION & SETUP
────────────────────────────────────────────────────────────────────────

Install:
    sudo bash install.sh

Uninstall:
    sudo bash uninstall.sh

Verify Installation:
    wivrn-fbt-status


SERVICE MANAGEMENT
────────────────────────────────────────────────────────────────────────

Start Services:
    wivrn-fbt-start
    # or manually:
    systemctl start wivrn-fbt.service
    systemctl start wivrn-fbt-webcam.service

Stop Services:
    wivrn-fbt-stop
    # or manually:
    systemctl stop wivrn-fbt-webcam.service
    systemctl stop wivrn-fbt.service

Restart Services:
    systemctl restart wivrn-fbt.service
    systemctl restart wivrn-fbt-webcam.service

Enable Auto-start:
    systemctl enable wivrn-fbt.service
    systemctl enable wivrn-fbt-webcam.service

Check Status:
    wivrn-fbt-status
    # or:
    systemctl status wivrn-fbt.service


LOGS & DEBUGGING
────────────────────────────────────────────────────────────────────────

View Core Service Logs (Real-time):
    journalctl -u wivrn-fbt -f

View Webcam Service Logs (Real-time):
    journalctl -u wivrn-fbt-webcam -f

View Both Services:
    journalctl -u wivrn-fbt -u wivrn-fbt-webcam -f

Last 50 Log Lines:
    journalctl -u wivrn-fbt -n 50
    journalctl -u wivrn-fbt-webcam -n 50

Logs from Last 2 Hours:
    journalctl -u wivrn-fbt --since "2 hours ago"

Save Logs to File:
    journalctl -u wivrn-fbt > ~/fbt_core_logs.txt
    journalctl -u wivrn-fbt-webcam > ~/fbt_webcam_logs.txt

Logs with Timestamps:
    journalctl -u wivrn-fbt --no-pager -o short-iso

Follow Errors Only:
    journalctl -u wivrn-fbt -p err -f


CONFIGURATION
────────────────────────────────────────────────────────────────────────

Edit Configuration:
    nano ~/.wivrn-fbt/config.json

View System Config:
    cat /etc/wivrn-fbt/config.json

Reset Configuration:
    cp /etc/wivrn-fbt/config.json ~/.wivrn-fbt/config.json

Backup Configuration:
    cp ~/.wivrn-fbt/config.json ~/.wivrn-fbt/config.json.backup

Restore Configuration:
    cp ~/.wivrn-fbt/config.json.backup ~/.wivrn-fbt/config.json

Open Web UI (if running):
    python3 -m http.server 8000
    # Open http://localhost:8000/config_ui.html


CAMERA TESTING
────────────────────────────────────────────────────────────────────────

List Video Devices:
    ls -la /dev/video*

Test Camera with OpenCV:
    python3 << 'PYTHON'
import cv2
cap = cv2.VideoCapture(0)
if cap.isOpened():
    print("✓ Camera 0 is available")
    ret, frame = cap.read()
    print(f"  Resolution: {frame.shape[1]}x{frame.shape[0]}")
else:
    print("✗ Camera 0 not available")
cap.release()
PYTHON

Test All Cameras:
    for i in {0..3}; do
        echo "Testing camera $i:"
        python3 -c "import cv2; cap = cv2.VideoCapture($i); print('Available' if cap.isOpened() else 'Unavailable'); cap.release()"
    done

Check Camera Permissions:
    groups $USER | grep video
    # If not present, add user to video group:
    sudo usermod -aG video $USER
    # Then log out and back in


CALIBRATION
────────────────────────────────────────────────────────────────────────

Interactive Calibration:
    wivrn-fbt-start
    # In preview window: press 'c', hold T-pose for 2 seconds

Reset Calibration:
    rm ~/.wivrn-fbt/calibration.json
    systemctl restart wivrn-fbt.service

View Calibration Data:
    cat ~/.wivrn-fbt/calibration.json

Clear All Data:
    rm -r ~/.wivrn-fbt/*
    mkdir -p ~/.wivrn-fbt


PERFORMANCE OPTIMIZATION
────────────────────────────────────────────────────────────────────────

Check CPU Usage:
    top -p $(pgrep -f webcam_tracker)

Monitor FPS Real-time:
    journalctl -u wivrn-fbt-webcam -f | grep FPS

Reduce Resolution (Edit ~/.wivrn-fbt/config.json):
    "resolution_width": 960,
    "resolution_height": 540

Lower Framerate:
    "fps": 24

Disable Unused Trackers:
    "enabled": false  # Set for trackers you don't use

Disable Preview:
    "enable_preview": false

Increase Smoothing:
    "smoothing_factor": 0.9


NETWORK & CONNECTIVITY
────────────────────────────────────────────────────────────────────────

Check Service Port:
    lsof -i :9876
    netstat -tlnp | grep 9876

Test Local Connection:
    echo "test" | nc -u 127.0.0.1 9876

Monitor Network:
    watch -n 1 'lsof -i :9876'


ENVIRONMENT VARIABLES
────────────────────────────────────────────────────────────────────────

Set Camera ID (before starting):
    export WIVRN_CAMERA_ID=1

Set Config File:
    export WIVRN_FBT_CONFIG=~/.wivrn-fbt/custom_config.json

Enable Debug Logging:
    export WIVRN_DEBUG=1

Run Service with Environment:
    WIVRN_CAMERA_ID=1 systemctl restart wivrn-fbt-webcam.service


COMMON ISSUES & FIXES
────────────────────────────────────────────────────────────────────────

Camera Not Found:
    → Check with: ls -la /dev/video*
    → Change camera_id in config.json
    → Check permissions: groups $USER | grep video

Poor Tracking:
    → Increase lighting
    → Run calibration: press 'c' in preview
    → Increase smoothing_factor (0.7 → 0.9)
    → Lower detection_confidence (0.5 → 0.3)

Tracking Lag:
    → Reduce resolution and/or FPS
    → Disable preview (enable_preview: false)
    → Close background apps
    → Check CPU usage: top

Service Crashes:
    → Check logs: journalctl -u wivrn-fbt -n 50
    → Restart service: systemctl restart wivrn-fbt.service
    → Check disk space: df -h

High CPU Usage:
    → Reduce model_complexity: 1 → 0
    → Lower resolution
    → Disable smooth_landmarks
    → Disable unused trackers


FILE LOCATIONS
────────────────────────────────────────────────────────────────────────

User Config:
    ~/.wivrn-fbt/config.json

System Config:
    /etc/wivrn-fbt/config.json

Calibration Data:
    ~/.wivrn-fbt/calibration.json

Service Binaries:
    /usr/local/bin/wivrn-fbt-service
    /opt/wivrn-fbt/webcam_tracker.py

Systemd Services:
    /etc/systemd/system/wivrn-fbt.service
    /etc/systemd/system/wivrn-fbt-webcam.service

Logs:
    /var/log/wivrn-fbt.log
    journalctl (recommended)

Python Requirements:
    /opt/wivrn-fbt/requirements.txt


MANUAL SERVICE STARTUP
────────────────────────────────────────────────────────────────────────

Run Core Service Directly:
    /usr/local/bin/wivrn-fbt-service

Run Webcam Tracking Directly:
    /usr/bin/python3 /opt/wivrn-fbt/webcam_tracker.py

With Debug Output:
    /usr/bin/python3 -u /opt/wivrn-fbt/webcam_tracker.py 2>&1 | tee ~/fbt_debug.log


WIVRN INTEGRATION
────────────────────────────────────────────────────────────────────────

Check WiVRn Version:
    wivrn-server --version

Start WiVRn Server:
    wivrn-server

Verify OpenXR Runtime:
    cat /etc/xdg/openxr/1/active_runtime.json

List OpenXR Layers:
    echo $XR_API_LAYER_PATH


UTILITIES
────────────────────────────────────────────────────────────────────────

Backup Everything:
    mkdir -p ~/wivrn-fbt-backup
    cp ~/.wivrn-fbt/* ~/wivrn-fbt-backup/
    cp /etc/wivrn-fbt/* ~/wivrn-fbt-backup/

Restore from Backup:
    cp ~/wivrn-fbt-backup/* ~/.wivrn-fbt/

System Info:
    lsb_release -a
    uname -a
    lsb_release -cs

Check Dependencies:
    dpkg -l | grep -E 'opencv|openxr|libgl'

Full System Check:
    wivrn-fbt-status
    journalctl -u wivrn-fbt --no-pager -n 5
    journalctl -u wivrn-fbt-webcam --no-pager -n 5
    echo "Camera test:"; ls -la /dev/video0
    echo "Disk usage:"; df -h | grep -E '/$|/home'


ADVANCED
────────────────────────────────────────────────────────────────────────

Rebuild from Source:
    cd ~/wivrn-fbt
    mkdir -p build
    cd build
    cmake .. && make
    sudo make install

Enable Persistent Logging:
    sudo mkdir -p /var/log/wivrn-fbt
    sudo chown root:root /var/log/wivrn-fbt
    sudo chmod 755 /var/log/wivrn-fbt

Monitor All Processes:
    ps aux | grep wivrn

Kill Service Forcefully:
    pkill -9 wivrn-fbt-service
    pkill -9 webcam_tracker.py

Reset All Settings:
    sudo bash uninstall.sh
    rm -rf ~/.wivrn-fbt
    sudo bash install.sh


════════════════════════════════════════════════════════════════════════

For more help:
    - Check README.md
    - View logs: journalctl -u wivrn-fbt -f
    - Test manually: python3 /opt/wivrn-fbt/webcam_tracker.py

════════════════════════════════════════════════════════════════════════

EOF
