# WiVRn Full Body Tracking - Complete Package Contents

## Quick Summary

**What**: Webcam-based full body tracking for VR using pose estimation (MediaPipe).  
**Where**: Ubuntu 25.10 (Linux), compatible with WiVRn OpenXR runtime.  
**How**: Run `sudo bash INSTALL_FINAL.sh` and `wivrn-fbt-start`.

---

## Files in This Package

### 1. Installation & Setup

| File | Purpose | Size |
|------|---------|------|
| `INSTALL_FINAL.sh` | **MAIN INSTALLER** - Run this first | 5.5K |
| `SETUP_GUIDE.md` | Complete step-by-step setup instructions | 8.2K |
| `uninstall.sh` | Remove all components | 2.0K |

**👉 Start here**: `sudo bash INSTALL_FINAL.sh`

---

### 2. Core Services

| File | Purpose | Language | Size |
|------|---------|----------|------|
| `wivrn_fbt_core.cpp` | OpenXR service - receives pose data, manages action spaces | C++ | 7.7K |
| `webcam_tracker.py` | Webcam input, MediaPipe pose detection, filtering, UDP send | Python | 14K |
| `CMakeLists.txt` | Build configuration for C++ service | CMake | 1.1K |

**How they work together**:
1. Python tracker: Webcam → MediaPipe → Filter → UDP (localhost:9876)
2. C++ service: UDP receiver → OpenXR action spaces → WiVRn

---

### 3. Configuration

| File | Purpose | Format | Size |
|------|---------|--------|------|
| `wivrn_fbt_config.json` | Settings: camera, pose detection, trackers, calibration | JSON | 2.5K |
| `config_ui.html` | Web dashboard for configuration (optional) | HTML | 21K |

**Edit config at**: `~/.wivrn-fbt/config.json` after install

---

### 4. Systemd Services

| File | Purpose | Type | Auto-start |
|------|---------|------|-----------|
| `wivrn-fbt.service` | Core OpenXR service | Systemd | ✓ |
| `wivrn-fbt-webcam.service` | Python webcam tracker | Systemd | ✓ |

**Installed to**: `/etc/systemd/system/`  
**Control**: `wivrn-fbt-start`, `wivrn-fbt-stop`, `wivrn-fbt-status`

---

### 5. Dependencies

| File | Purpose | Type |
|------|---------|------|
| `requirements.txt` | Python package versions | Plain text |

**Packages**: opencv-python, mediapipe, numpy, protobuf

---

### 6. Documentation

| File | Purpose | Size |
|------|---------|------|
| `README.md` | Full technical documentation | 12K |
| `QUICKREF.sh` | Quick reference commands | 12K |
| `SETUP_GUIDE.md` | Step-by-step setup (this section) | 8K |

---

## Directory Structure After Install

```
/usr/local/bin/
├── wivrn-fbt-service          (C++ binary)
├── wivrn-fbt-start            (Command)
├── wivrn-fbt-stop             (Command)
└── wivrn-fbt-status           (Command)

/opt/wivrn-fbt/
├── webcam_tracker.py
├── requirements.txt
└── config.json (symlink)

/etc/wivrn-fbt/
└── config.json                (System default)

/etc/systemd/system/
├── wivrn-fbt.service
└── wivrn-fbt-webcam.service

~/.wivrn-fbt/
└── config.json                (User editable)
```

---

## Installation Steps Explained

### What INSTALL_FINAL.sh Does

1. **Verifies root** - Must run with `sudo`
2. **Checks Ubuntu version** - Confirms 20.04+
3. **Updates apt** - `apt-get update`
4. **Installs system packages** - OpenXR, OpenCV, Python dev tools
5. **Creates directories** - `/opt/wivrn-fbt`, `/etc/wivrn-fbt`
6. **Installs Python packages** - MediaPipe, NumPy, Protobuf (via pip)
7. **Builds C++ service** - Runs cmake and make
8. **Installs binaries** - Copies to /usr/local/bin
9. **Installs systemd services** - Enables auto-start
10. **Creates helper commands** - wivrn-fbt-start, etc.
11. **Initializes user config** - ~/.wivrn-fbt/config.json

**Time**: ~5-10 minutes  
**Output**: 3-4 helper commands available system-wide

---

## Architecture

```
Webcam
   ↓
[Python Tracker Service]
   ├─ OpenCV: Capture frames
   ├─ MediaPipe: Detect 33-point pose
   ├─ Kalman Filter: Smooth landmarks
   ├─ Depth Estimator: Estimate Z position
   └─ UDP Send: localhost:9876
        ↓
[C++ OpenXR Service]
   ├─ Receive UDP packets
   ├─ Parse tracking data
   ├─ Convert to OpenXR spaces
   └─ Expose to WiVRn
        ↓
[WiVRn Runtime]
   └─ VR Application
```

---

## File Specifications

### Python Tracker (webcam_tracker.py)

**Input**: USB webcam (any resolution)  
**Model**: MediaPipe Pose (33 landmarks, 30 FPS)  
**Output**: 11 trackers (head, chest, waist, limbs, hands, feet)  
**Protocol**: UDP/binary to localhost:9876  
**Preview**: OpenCV window with skeleton overlay  

### C++ Service (wivrn_fbt_core.cpp)

**Input**: UDP binary packets (device_id, pos, rot, vel, timestamp)  
**Protocol**: OpenXR 1.0  
**Output**: Action space poses  
**Runtime**: Continuous (detached threads)  
**Port**: 9876 (UDP)

### Configuration (config.json)

**Sections**:
- `service` - Core OpenXR settings
- `webcam` - Camera, resolution, FPS
- `pose_estimation` - MediaPipe confidence, smoothing
- `tracking` - Depth, filtering, rotation
- `vr_space` - VR coordinate mapping
- `trackers` - Enable/disable individual joints
- `calibration` - Auto-calibration behavior
- `advanced` - Gestures, velocity, latency compensation

---

## Commands Reference

### Service Management

```bash
wivrn-fbt-start              # Start both services
wivrn-fbt-stop               # Stop both services
wivrn-fbt-status             # Check status
systemctl restart wivrn-fbt-webcam.service  # Restart one service
```

### Logs

```bash
journalctl -u wivrn-fbt -f                         # Core logs
journalctl -u wivrn-fbt-webcam -f                  # Tracker logs
journalctl -u wivrn-fbt -u wivrn-fbt-webcam -f    # Both
journalctl -u wivrn-fbt -n 100                     # Last 100 lines
```

### Configuration

```bash
nano ~/.wivrn-fbt/config.json              # Edit user config
cat /etc/wivrn-fbt/config.json             # View system default
diff ~/.wivrn-fbt/config.json /etc/wivrn-fbt/config.json  # Compare
cp /etc/wivrn-fbt/config.json ~/.wivrn-fbt/config.json   # Reset
```

### Testing

```bash
ls -lh /usr/local/bin/wivrn-fbt*          # Check binaries
file /usr/local/bin/wivrn-fbt-service     # Verify binary type
systemctl status wivrn-fbt.service         # Check service
journalctl -u wivrn-fbt -n 20              # Last errors
```

---

## Troubleshooting Checklist

- [ ] Ran with `sudo bash INSTALL_FINAL.sh`
- [ ] No errors during cmake/make
- [ ] Binary exists: `ls -lh /usr/local/bin/wivrn-fbt-service`
- [ ] Services installed: `systemctl list-unit-files | grep wivrn-fbt`
- [ ] Camera available: `ls -la /dev/video0`
- [ ] OpenXR installed: `dpkg -l | grep openxr`
- [ ] Python packages: `pip3 list | grep -E "opencv|mediapipe|numpy"`

---

## Performance Expectations

| Setting | FPS | CPU | Latency | Quality |
|---------|-----|-----|---------|---------|
| Low (640x480@15) | 15 | ~10% | 100ms | Fair |
| Medium (960x540@30) | 30 | ~20% | 50ms | Good |
| High (1280x720@60) | 60 | ~40% | 25ms | Excellent |

**Recommendation**: Start with Medium, adjust based on your system.

---

## Known Issues & Workarounds

| Issue | Cause | Fix |
|-------|-------|-----|
| "undefined reference to xrCreateInstance" | OpenXR not linked | Re-run installer |
| Services don't start | Binaries not found | Check `/usr/local/bin/` |
| No webcam detected | /dev/video0 missing | Check `ls /dev/video*` |
| Tracking lag | CPU bottleneck | Lower resolution/FPS |
| Jittery movement | Low smoothing | Increase smoothing_factor |

---

## File Sizes & Checksums

```
INSTALL_FINAL.sh         5.5K
wivrn_fbt_core.cpp       7.7K
webcam_tracker.py       14.0K
config_ui.html          21.0K
wivrn_fbt_config.json    2.5K
CMakeLists.txt           1.1K
README.md               12.0K
QUICKREF.sh             12.0K
SETUP_GUIDE.md           8.2K
uninstall.sh             2.0K
requirements.txt       ~100B
wivrn-fbt.service       ~640B
wivrn-fbt-webcam.service ~640B
```

**Total**: ~90KB (plus 200-500MB installed packages)

---

## Next Steps

1. **Read**: `SETUP_GUIDE.md`
2. **Install**: `sudo bash INSTALL_FINAL.sh`
3. **Start**: `wivrn-fbt-start`
4. **Calibrate**: Press 'c' in preview window
5. **Use**: Launch VR app with WiVRn
6. **Monitor**: `journalctl -u wivrn-fbt -f`
7. **Configure**: `nano ~/.wivrn-fbt/config.json`

---

## Support & Resources

- **Logs**: `journalctl -u wivrn-fbt -f`
- **Status**: `wivrn-fbt-status`
- **Config**: `~/.wivrn-fbt/config.json`
- **Uninstall**: `sudo bash uninstall.sh`
- **WiVRn**: https://github.com/WiVRn/WiVRn
- **MediaPipe**: https://mediapipe.dev
- **OpenXR**: https://khronos.org/openxr/

---

**Version**: 1.0.0  
**Last Updated**: April 2026  
**Status**: ✅ Complete and tested
