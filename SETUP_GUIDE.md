# WiVRn Full Body Tracking - Complete Setup Guide

## System Requirements

- **OS**: Ubuntu 20.04 LTS or newer (tested on Ubuntu 25.10)
- **CPU**: Intel i5+ or AMD Ryzen 5+
- **RAM**: 4GB minimum, 8GB recommended
- **Webcam**: Any USB webcam
- **WiVRn**: Latest version installed and running

## Files You Need

All files should be in one directory (`~/wivrn-fbt`):

```
wivrn-fbt/
├── INSTALL_FINAL.sh              ← Run this
├── uninstall.sh
├── wivrn_fbt_core.cpp            (C++ OpenXR service)
├── CMakeLists.txt                (Build config)
├── webcam_tracker.py             (Python pose tracker)
├── wivrn_fbt_config.json         (Configuration)
├── wivrn-fbt.service             (Systemd)
├── wivrn-fbt-webcam.service      (Systemd)
├── requirements.txt              (Python deps)
├── config_ui.html                (Web UI)
├── README.md                      (Documentation)
└── QUICKREF.sh                   (Quick commands)
```

## Installation (3 Steps)

### Step 1: Clone or Download Files

Option A - Clone from GitHub:
```bash
git clone https://github.com/netplayz/wivrn-fbt.git
cd wivrn-fbt
```

Option B - Manually copy all files to a directory:
```bash
mkdir -p ~/wivrn-fbt
cd ~/wivrn-fbt
# Copy all files here
```

### Step 2: Run Installation

```bash
cd ~/wivrn-fbt
sudo bash INSTALL_FINAL.sh
```

This script will:
- ✓ Update package manager
- ✓ Install system dependencies (OpenXR, OpenCV, Python)
- ✓ Create /opt/wivrn-fbt, /etc/wivrn-fbt directories
- ✓ Install Python packages (MediaPipe, OpenCV, NumPy, Protobuf)
- ✓ Build C++ OpenXR service
- ✓ Install binaries to /usr/local/bin
- ✓ Install systemd services
- ✓ Create helper commands (wivrn-fbt-start, etc.)

**If script fails**: Check error output, show CMake/make logs from `build/` directory.

### Step 3: Start Services

```bash
wivrn-fbt-start
```

This will:
- Start the C++ OpenXR core service
- Start the Python webcam tracker (preview window appears)
- Show log location

## Usage

### Start / Stop

```bash
wivrn-fbt-start      # Start both services
wivrn-fbt-stop       # Stop both services
wivrn-fbt-status     # Check status
```

### View Logs

```bash
# Real-time logs (both services)
journalctl -u wivrn-fbt -u wivrn-fbt-webcam -f

# Last 50 lines
journalctl -u wivrn-fbt -n 50

# Specific service
journalctl -u wivrn-fbt-webcam -f
```

### Calibration

When the preview window appears:
1. Stand in **T-pose** (arms out to sides)
2. Press **'c'** on keyboard
3. Hold position for **2 seconds**
4. Tracking should improve

Press **'q'** to quit preview window.

### Configuration

Edit settings:
```bash
nano ~/.wivrn-fbt/config.json
```

Key settings:
- `camera_id`: 0 (or 1, 2, 3 if multiple webcams)
- `resolution_width`: 1280 (reduce to 960 for lower CPU)
- `resolution_height`: 720 (reduce to 540 for lower CPU)
- `smoothing_factor`: 0.7 (increase to 0.9 for smoother)
- `min_detection_confidence`: 0.5 (lower if person disappears)

Restart to apply changes:
```bash
systemctl restart wivrn-fbt-webcam.service
```

## Troubleshooting

### Installation Fails at CMake/Make

**Error**: "undefined reference to `xrCreateInstance`"

**Fix**: Ensure OpenXR dev package installed:
```bash
sudo apt-get install -y libopenxr-dev libopenxr1-monado
```

Then rebuild:
```bash
cd ~/wivrn-fbt
rm -rf build
mkdir build && cd build
cmake ..
make
cd ..
sudo cp build/wivrn-fbt-service /usr/local/bin/
sudo systemctl restart wivrn-fbt.service
```

### Service Fails to Start

**Error**: "Unit wivrn-fbt.service not found"

**Fix**: Reinstall service files:
```bash
cd ~/wivrn-fbt
sudo cp wivrn-fbt*.service /etc/systemd/system/
sudo systemctl daemon-reload
wivrn-fbt-start
```

### No Webcam / Camera Not Found

**Error**: Camera device /dev/video0 not found

**Fix**: 
```bash
ls -la /dev/video*              # Check available devices
# Edit config to use different camera_id (0, 1, 2, 3...)
nano ~/.wivrn-fbt/config.json
# Set "camera_id": 1  (or whichever number your camera has)
```

### Poor Tracking Quality

**Problem**: Jittery or loses tracking

**Solutions**:
1. Increase lighting (pose detection needs visibility)
2. Increase smoothing:
   ```json
   "smoothing_factor": 0.85
   ```
3. Lower confidence threshold:
   ```json
   "min_detection_confidence": 0.3
   ```
4. Calibrate again (press 'c' in preview)

**Problem**: Tracking lag / slow response

**Solutions**:
1. Reduce resolution:
   ```json
   "resolution_width": 960,
   "resolution_height": 540
   ```
2. Lower FPS:
   ```json
   "fps": 24
   ```
3. Disable preview:
   ```json
   "enable_preview": false
   ```

### High CPU Usage

**Solution**: Reduce quality settings:
```json
{
  "resolution_width": 960,
  "resolution_height": 540,
  "fps": 24,
  "model_complexity": 0,
  "enable_preview": false,
  "smoothing_factor": 0.8
}
```

## File Locations

| Item | Location |
|------|----------|
| Core service binary | `/usr/local/bin/wivrn-fbt-service` |
| Python tracker | `/opt/wivrn-fbt/webcam_tracker.py` |
| System config | `/etc/wivrn-fbt/config.json` |
| User config | `~/.wivrn-fbt/config.json` |
| Systemd services | `/etc/systemd/system/wivrn-fbt*.service` |
| Logs | `journalctl -u wivrn-fbt` |

## Uninstall

```bash
cd ~/wivrn-fbt
sudo bash uninstall.sh
```

Or manually:
```bash
sudo systemctl stop wivrn-fbt-webcam.service
sudo systemctl stop wivrn-fbt.service
sudo rm -rf /opt/wivrn-fbt /etc/wivrn-fbt
sudo rm /usr/local/bin/wivrn-fbt*
sudo rm /etc/systemd/system/wivrn-fbt*.service
sudo systemctl daemon-reload
rm -rf ~/.wivrn-fbt
```

## Performance Optimization

### For Laptops (Low Power)

```json
{
  "resolution_width": 640,
  "resolution_height": 480,
  "fps": 15,
  "model_complexity": 0,
  "enable_preview": false,
  "smoothing_factor": 0.8
}
```

### For Desktops (Balanced)

```json
{
  "resolution_width": 960,
  "resolution_height": 540,
  "fps": 30,
  "model_complexity": 1,
  "enable_preview": true,
  "smoothing_factor": 0.7
}
```

### For Gaming PCs (High Quality)

```json
{
  "resolution_width": 1280,
  "resolution_height": 720,
  "fps": 60,
  "model_complexity": 1,
  "enable_preview": true,
  "smoothing_factor": 0.5
}
```

## Advanced Configuration

### Enable Multiple Trackers

Disable trackers you don't need in `~/.wivrn-fbt/config.json`:

```json
"trackers": {
  "head": {"enabled": true},
  "chest": {"enabled": true},
  "waist": {"enabled": true},
  "left_foot": {"enabled": false},      # Disable unused
  "right_foot": {"enabled": false},
  "left_elbow": {"enabled": true},
  "right_elbow": {"enabled": true}
}
```

### Network Configuration

If tracking receiver on different IP:
```json
"service": {
  "tracking_server_host": "192.168.1.100",
  "tracking_server_port": 9876
}
```

### Depth Calibration

If tracker Z-depth is wrong, adjust:
```json
"tracking": {
  "depth_calibration_distance": 1.5,    # Your standing distance in meters
  "reference_shoulder_width": 0.45      # Your shoulder width in meters
}
```

## Testing

### Test Camera
```bash
python3 << 'EOF'
import cv2
cap = cv2.VideoCapture(0)
if cap.isOpened():
    ret, frame = cap.read()
    print(f"✓ Camera working: {frame.shape}")
else:
    print("✗ Camera not available")
cap.release()
EOF
```

### Test OpenXR
```bash
dpkg -l | grep openxr
# Should show libopenxr-dev and libopenxr1-monado
```

### Test Installation
```bash
wivrn-fbt-status
# Should show both services running or ready
```

## Support

- Check logs: `journalctl -u wivrn-fbt -f`
- Review config: `cat ~/.wivrn-fbt/config.json`
- OpenXR docs: https://www.khronos.org/openxr/
- WiVRn: https://github.com/WiVRn/WiVRn
- MediaPipe: https://mediapipe.dev

## Summary

**Installation**: `sudo bash INSTALL_FINAL.sh`  
**Start**: `wivrn-fbt-start`  
**Logs**: `journalctl -u wivrn-fbt -f`  
**Config**: `nano ~/.wivrn-fbt/config.json`  
**Stop**: `wivrn-fbt-stop`
