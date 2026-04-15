# WiVRn Full Body Tracking - Documentation

# THIS IS STILL IN PROGRESS AND WILL NOT WORK YET!!
A complete webcam-based full body tracking system for VR on Ubuntu Linux, compatible with WiVRn OpenXR runtime.

## Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Configuration](#configuration)
6. [Calibration](#calibration)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Usage](#advanced-usage)
9. [Architecture](#architecture)
10. [Performance Tips](#performance-tips)

---

## Overview

WiVRn Full Body Tracking (FBT) uses:
- **Webcam input** for real-time pose estimation
- **MediaPipe** for skeleton detection (33-point pose model)
- **OpenXR** integration with WiVRn for VR runtime compatibility
- **Kalman-like filtering** for smooth tracking
- **Depth estimation** based on shoulder width ratio

### Supported Trackers
- Head / Neck
- Chest (mid-shoulder)
- Waist / Hip
- Both Elbows
- Both Knees
- Both Feet
- Both Hands (wrist)

---

## Requirements

### Hardware
- **Webcam**: USB camera, integrated webcam, or IP camera
- **CPU**: Intel i5/i7 or AMD Ryzen 5+ (real-time pose estimation is CPU-intensive)
- **RAM**: 4GB minimum, 8GB recommended
- **GPU**: Optional (MediaPipe can use GPU for faster inference)

### Software
- **OS**: Ubuntu 20.04 LTS or newer
- **Python**: 3.8+
- **WiVRn**: Latest version from [WiVRn releases](https://github.com/WiVRn/WiVRn)
- **OpenXR SDK**: Installed via package manager

### Dependencies (automatically installed)
```
python3
python3-pip
python3-dev
build-essential
cmake
libopenxr-dev
libopencv-dev
```

---

## Installation

### 1. Clone or Download
```bash
cd ~/projects
git clone https://github.com/yourusername/wivrn-fbt.git
cd wivrn-fbt
```

### 2. Run Installation Script
```bash
chmod +x install.sh
sudo bash install.sh
```

This script will:
- Install system dependencies
- Install OpenXR SDK
- Build the C++ OpenXR service
- Install Python packages
- Set up systemd services
- Create configuration files

### 3. Verify Installation
```bash
wivrn-fbt-status
```

You should see both services as "active (running)".

---

## Quick Start

### Basic Setup (First Run)

```bash
# 1. Start the services
wivrn-fbt-start

# 2. Watch the webcam preview (a window should appear)
# Stand in T-pose (arms out)

# 3. Press 'c' to calibrate (will take ~2 seconds)

# 4. Your body position should now be tracked in VR
```

### Monitor Logs
```bash
journalctl -u wivrn-fbt -f      # Core service logs
journalctl -u wivrn-fbt-webcam -f  # Webcam service logs
```

### Stop Services
```bash
wivrn-fbt-stop
```

---

## Configuration

### Config File Location
```
~/.wivrn-fbt/config.json
/etc/wivrn-fbt/config.json
```

### Web UI
Open the config UI in a browser (requires Python web server):
```bash
cd /path/to/wivrn-fbt
python3 -m http.server 8000
# Open http://localhost:8000/config_ui.html
```

### Key Settings

#### Webcam Settings
```json
"webcam": {
  "camera_id": 0,              // Device index (0=default)
  "resolution_width": 1280,    // 640-1920
  "resolution_height": 720,    // 480-1440
  "fps": 30,                   // 15-60 (camera dependent)
  "enable_preview": true,      // Show preview window
  "mirror_image": true         // Mirror for selfie view
}
```

#### Pose Estimation
```json
"pose_estimation": {
  "model_complexity": 1,           // 0=light, 1=full
  "smooth_landmarks": true,        // Reduce jitter
  "min_detection_confidence": 0.5, // 0.0-1.0
  "min_tracking_confidence": 0.5,  // 0.0-1.0
  "smoothing_factor": 0.7          // 0.1-1.0
}
```

**Higher confidence values** = stricter detection but may lose tracking
**Higher smoothing** = more laggy but smoother movement

#### Depth Estimation
```json
"tracking": {
  "depth_calibration_distance": 1.5,    // Standing distance in meters
  "reference_shoulder_width": 0.45,     // In meters
  "depth_min": 0.3,                     // Minimum 30cm
  "depth_max": 4.0                      // Maximum 4 meters
}
```

#### Tracker Selection
```json
"trackers": {
  "head": {"enabled": true, "vr_id": 0},
  "chest": {"enabled": true, "vr_id": 1},
  // ... etc
}
```

Disable trackers you don't need to reduce CPU usage.

---

## Calibration

### Why Calibrate?
Calibration establishes the person's reference position in VR space. It helps:
- Map camera coordinates to VR space
- Set the ground plane level
- Establish posture baseline

### Calibration Process

**Interactive Calibration**
```bash
wivrn-fbt-start
# When preview window shows:
# 1. Stand straight with arms out (T-pose)
# 2. Press 'c'
# 3. Hold position for 2 seconds
# 4. Done - tracking should improve
```

**Manual Calibration**
Edit `~/.wivrn-fbt/config.json`:
```json
"calibration": {
  "auto_calibrate": false,
  "save_calibration": true,
  "calibration_file": "/home/.wivrn-fbt/calibration.json"
}
```

**Reset Calibration**
```bash
rm ~/.wivrn-fbt/calibration.json
# Restart service - will require recalibration
wivrn-fbt-stop
wivrn-fbt-start
```

---

## Troubleshooting

### Camera Not Detected
```bash
# List video devices
ls -la /dev/video*

# Test camera
python3 -c "import cv2; cap = cv2.VideoCapture(0); print(cap.isOpened())"

# Try different camera ID (edit config)
"camera_id": 1  # or 2, 3, etc
```

### Poor Tracking Quality

**Issue**: Tracking is jittery or loses position

**Solutions**:
1. Increase lighting (pose detection needs good visibility)
2. Increase `smoothing_factor` to 0.8-0.9
3. Ensure full body is visible in camera
4. Calibrate again with better T-pose
5. Reduce `detection_confidence` if person keeps disappearing

**Issue**: Tracking lag is noticeable

**Solutions**:
1. Reduce resolution (1280x720 → 960x540)
2. Lower FPS in config (30 → 24)
3. Disable unused trackers
4. Disable preview window (`"enable_preview": false`)
5. Close other CPU-intensive apps

### Service Won't Start
```bash
# Check systemd status
systemctl status wivrn-fbt.service

# View detailed logs
journalctl -u wivrn-fbt -n 50

# Try running directly
/usr/local/bin/wivrn-fbt-service
/usr/bin/python3 /opt/wivrn-fbt/webcam_tracker.py
```

### High CPU Usage
MediaPipe pose estimation is CPU-intensive (~15-30% on modern processors).

**Reduce CPU usage**:
1. Lower resolution: 1280x720 → 960x540
2. Lower FPS: 30 → 15
3. Use `model_complexity: 0` (but less accurate)
4. Disable preview window
5. Disable unused trackers

---

## Advanced Usage

### Gesture Recognition
Enable gesture detection for specific poses:
```json
"advanced": {
  "enable_gesture_recognition": true,
  "gesture_timeout": 2000
}
```

### Rotation Estimation
Control how joint rotation is calculated:
```json
"advanced": {
  "rotation_estimation_method": "imu_fusion"  // or "vector_angle"
}
```

### Network Latency Compensation
Automatically adjust for network delays:
```json
"advanced": {
  "network_latency_compensation": true,
  "velocity_calculation_frames": 5
}
```

### Velocity Smoothing
For physics-based VR interactions:
```json
"advanced": {
  "adaptive_tracking": true
}
```

### Custom Camera Calibration
If shoulder width in your setup differs:
```json
"tracking": {
  "reference_shoulder_width": 0.50  // Adjust per person
}
```

### Logging
```bash
# View service logs in real-time
journalctl -u wivrn-fbt -u wivrn-fbt-webcam -f

# Export logs to file
journalctl -u wivrn-fbt --since "2 hours ago" > ~/fbt_logs.txt

# Debug logging (if enabled in code)
tail -f /var/log/wivrn-fbt.log
```

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────┐
│  WiVRn Runtime (OpenXR)                     │
│  └─ WiVRn Server                            │
└────────────────┬────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────┐
│  OpenXR Service (C++)                       │
│  wivrn-fbt-service                          │
│  └─ Pose Space Mapping                      │
│  └─ Action Space Management                 │
└────────────────┬────────────────────────────┘
                 │ UDP Port 9876
                 ↓
┌─────────────────────────────────────────────┐
│  Pose Tracking Service (Python)             │
│  webcam_tracker.py                          │
│  ├─ Webcam Input                            │
│  ├─ MediaPipe Pose Detection                │
│  ├─ Kalman Filtering                        │
│  ├─ Depth Estimation                        │
│  └─ Quaternion Calculation                  │
└────────────────┬────────────────────────────┘
                 │
                 ↓
            /dev/video0 (Webcam)
```

### Data Flow
1. **Webcam** → RGB frames (1280x720 @ 30fps)
2. **MediaPipe** → 33-point pose skeleton
3. **Filter** → Smooth landmarks with Kalman filter
4. **Map** → Convert to VR tracker coordinates
5. **Pack** → Binary UDP packets (device_id, pos, rot, vel)
6. **Send** → UDP to OpenXR service (localhost:9876)
7. **OpenXR** → Update action spaces for VR application
8. **VR App** → Read controller poses to get full body trackers

### Pose Model (MediaPipe)
33 landmarks covering:
- Face (10)
- Torso (8)
- Arms (10)
- Legs (5)

---

## Performance Tips

### Optimize for Better Tracking
1. **Lighting**: Bright, even lighting improves detection
2. **Clothing**: High contrast helps (wear different color from background)
3. **Space**: At least 2m from camera for full body visibility
4. **Background**: Simple, non-moving backgrounds work best

### Optimize for FPS
1. **Resolution**: 960x540 instead of 1280x720 = 30% faster
2. **Model**: `complexity: 0` for ~40% speed improvement (less accurate)
3. **Smoothing**: Disable `smooth_landmarks` if CPU-bound
4. **Preview**: Disable in config when not needed

### System Requirements by Quality

**Low Quality (Laptops)**
```json
{
  "resolution_width": 640,
  "resolution_height": 480,
  "fps": 15,
  "model_complexity": 0,
  "smooth_landmarks": false,
  "smoothing_factor": 0.8
}
```

**Medium Quality (Desktop)**
```json
{
  "resolution_width": 960,
  "resolution_height": 540,
  "fps": 30,
  "model_complexity": 1,
  "smooth_landmarks": true,
  "smoothing_factor": 0.7
}
```

**High Quality (Gaming PC)**
```json
{
  "resolution_width": 1280,
  "resolution_height": 720,
  "fps": 60,
  "model_complexity": 1,
  "smooth_landmarks": true,
  "smoothing_factor": 0.5
}
```

---

## Uninstallation

```bash
sudo bash uninstall.sh
```

This will:
- Stop and disable services
- Remove binaries
- Remove system configuration
- Optionally remove user config

---

## Support & Troubleshooting Resources

- WiVRn: https://github.com/WiVRn/WiVRn
- MediaPipe: https://mediapipe.dev
- OpenXR: https://www.khronos.org/openxr/
- Ubuntu: https://ubuntu.com

## License

This project is provided as-is for personal use with WiVRn.

---

**Last Updated**: 2026
**Version**: 1.0.0
