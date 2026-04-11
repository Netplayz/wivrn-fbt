# WiVRn Full Body Tracking - Flatpak Setup Guide

Running WiVRn FBT inside the official WiVRn Flatpak sandbox.

## Prerequisites

1. **WiVRn Flatpak installed**:
   ```bash
   flatpak install flathub com.wivrn.WiVRn
   ```

2. **Files needed**:
   - `install_flatpak.sh` — Main installer
   - `webcam_tracker_flatpak.py` — Python tracker with args
   - `wivrn_fbt_config.json` — Configuration

## Installation (2 Steps)

### Step 1: Prepare Files

```bash
mkdir -p ~/wivrn-fbt-flatpak
cd ~/wivrn-fbt-flatpak

# Copy these files:
# - install_flatpak.sh
# - webcam_tracker_flatpak.py
# - wivrn_fbt_config.json

chmod +x install_flatpak.sh
chmod +x webcam_tracker_flatpak.py
```

### Step 2: Run Installation

```bash
bash install_flatpak.sh
```

This will:
- ✓ Detect WiVRn Flatpak installation
- ✓ Create tracker directories in Flatpak structure
- ✓ Install Python tracker into Flatpak environment
- ✓ Create systemd user services
- ✓ Create launcher scripts in ~/.local/bin

## Usage

### Start Tracking

**Option 1: Direct (shows preview window)**
```bash
wivrn-fbt-flatpak
```

**Option 2: As service (background)**
```bash
wivrn-fbt-start-flatpak
```

### Stop Tracking

```bash
wivrn-fbt-stop-flatpak
```

### Check Status

```bash
wivrn-fbt-status-flatpak
```

### View Logs

```bash
journalctl --user -u wivrn-fbt-flatpak -f
```

### Edit Configuration

```bash
wivrn-fbt-config-flatpak
```

Or directly:
```bash
nano ~/.var/app/com.wivrn.WiVRn/config/wivrn-fbt/config.json
```

## Architecture

### File Structure in Flatpak

```
~/.var/app/com.wivrn.WiVRn/
├── data/wivrn-fbt/
│   └── webcam_tracker.py      (Installed tracker)
├── config/wivrn-fbt/
│   └── config.json             (Configuration)
└── cache/                       (Runtime cache)

~/.local/bin/
├── wivrn-fbt-flatpak           (Direct launcher)
├── wivrn-fbt-start-flatpak     (Start service)
├── wivrn-fbt-stop-flatpak      (Stop service)
├── wivrn-fbt-status-flatpak    (Check status)
└── wivrn-fbt-config-flatpak    (Edit config)

~/.config/systemd/user/
└── wivrn-fbt-flatpak.service   (Systemd unit)
```

### How It Works

1. **Flatpak Sandbox** runs WiVRn with OpenXR runtime
2. **Tracker** runs inside Flatpak with `--share=network` and `--device=all`
3. **UDP Communication** sends pose data to localhost:9876
4. **OpenXR** receives and maps trackers to VR space
5. **VR App** reads full body tracking data

## Command Line Arguments

The tracker accepts arguments for one-off runs:

```bash
wivrn-fbt-flatpak \
  --config ~/.var/app/com.wivrn.WiVRn/config/wivrn-fbt/config.json \
  --camera-id 0 \
  --port 9876 \
  --enable-preview \
  --smoothing 0.7 \
  --detection-confidence 0.5 \
  --tracking-confidence 0.5
```

### Arguments

| Argument | Default | Range | Description |
|----------|---------|-------|-------------|
| `--config` | None | Path | JSON config file |
| `--camera-id` | 0 | 0-3 | Camera device |
| `--port` | 9876 | 1024-65535 | UDP port |
| `--enable-preview` | True | - | Show preview window |
| `--no-preview` | - | - | Hide preview |
| `--smoothing` | 0.7 | 0.1-1.0 | Pose filtering |
| `--detection-confidence` | 0.5 | 0.0-1.0 | MediaPipe detection |
| `--tracking-confidence` | 0.5 | 0.0-1.0 | MediaPipe tracking |

## Configuration

### Location

User configuration: `~/.var/app/com.wivrn.WiVRn/config/wivrn-fbt/config.json`

Edit with:
```bash
wivrn-fbt-config-flatpak
```

### Key Settings

```json
{
  "webcam": {
    "camera_id": 0,              // Device ID
    "resolution_width": 1280,    // Frame width
    "resolution_height": 720,    // Frame height
    "fps": 30,
    "enable_preview": true
  },
  "pose_estimation": {
    "smoothing_factor": 0.7,     // 0.1=jittery, 1.0=laggy
    "min_detection_confidence": 0.5
  }
}
```

### Performance Presets

**Low Power** (laptops):
```bash
wivrn-fbt-flatpak --smoothing 0.8 --no-preview
```

**Balanced** (default):
```bash
wivrn-fbt-flatpak --smoothing 0.7 --enable-preview
```

**High Quality** (gaming):
```bash
wivrn-fbt-flatpak --smoothing 0.5 --detection-confidence 0.6
```

## Troubleshooting

### "WiVRn Flatpak not found"

**Fix**: Install WiVRn first:
```bash
flatpak install flathub com.wivrn.WiVRn
flatpak run com.wivrn.WiVRn  # Test it works
```

### Service doesn't start

**Check logs**:
```bash
journalctl --user -u wivrn-fbt-flatpak -n 50
```

**Common issues**:
- Camera not accessible: Grant permissions to Flatpak
- Port 9876 in use: Change `--port` argument
- Python missing: Already in WiVRn Flatpak

### No camera detected

**Inside Flatpak, check**:
```bash
flatpak run --device=all com.wivrn.WiVRn \
  python3 -c "import cv2; print(cv2.VideoCapture(0).isOpened())"
```

**Grant webcam access**:
```bash
flatpak override --device=all com.wivrn.WiVRn
```

### Poor tracking quality

**Try higher detection thresholds**:
```bash
wivrn-fbt-flatpak --detection-confidence 0.3 --smoothing 0.85
```

**Or use lower resolution** (edit config):
```json
"resolution_width": 960,
"resolution_height": 540
```

### Laggy / Slow response

**Disable preview**:
```bash
wivrn-fbt-flatpak --no-preview
```

**Or reduce smoothing**:
```bash
wivrn-fbt-flatpak --smoothing 0.5
```

## Updating

### Update Tracker

```bash
cd ~/wivrn-fbt-flatpak
bash install_flatpak.sh  # Reinstalls tracker
```

### Update Configuration

Manually edit config or replace:
```bash
cp wivrn_fbt_config.json ~/.var/app/com.wivrn.WiVRn/config/wivrn-fbt/config.json
```

### Update WiVRn Flatpak

```bash
flatpak update com.wivrn.WiVRn
```

## Advanced

### Multiple Cameras

Switch camera at runtime:
```bash
wivrn-fbt-flatpak --camera-id 1
```

Or in config:
```json
"camera_id": 1
```

### Custom Port

If port 9876 is in use:
```bash
wivrn-fbt-flatpak --port 9877
```

### Enable Auto-start

Enable service on boot:
```bash
systemctl --user enable wivrn-fbt-flatpak.service
```

Check:
```bash
systemctl --user is-enabled wivrn-fbt-flatpak.service
```

Disable:
```bash
systemctl --user disable wivrn-fbt-flatpak.service
```

### Uninstall

Remove tracker from Flatpak:
```bash
rm -rf ~/.var/app/com.wivrn.WiVRn/data/wivrn-fbt
rm -rf ~/.var/app/com.wivrn.WiVRn/config/wivrn-fbt
rm -rf ~/.local/bin/wivrn-fbt-*
systemctl --user disable wivrn-fbt-flatpak.service
rm ~/.config/systemd/user/wivrn-fbt-flatpak.service
systemctl --user daemon-reload
```

## Integration with WiVRn

Once tracker is running:

1. **Start WiVRn normally**:
   ```bash
   flatpak run com.wivrn.WiVRn
   ```

2. **Launch VR app** (SteamVR game, etc.)

3. **Full body tracking** is available as controller trackers

## Performance

### Typical Resource Usage

| Setting | CPU | Memory | Latency |
|---------|-----|--------|---------|
| No preview, 720p@30 | 15-20% | 200MB | 50-100ms |
| Preview, 720p@30 | 20-25% | 250MB | 50-100ms |
| High quality, 1080p | 30-40% | 350MB | 25-50ms |

### Tips

- Disable preview if running as background service
- Lower resolution for older hardware
- Increase smoothing if tracking jitters
- Close background apps for better performance

## Systemd Service Details

Service runs at user level:

```bash
# Start
systemctl --user start wivrn-fbt-flatpak.service

# Stop
systemctl --user stop wivrn-fbt-flatpak.service

# Status
systemctl --user status wivrn-fbt-flatpak.service

# Enable on login
systemctl --user enable wivrn-fbt-flatpak.service

# Logs
journalctl --user -u wivrn-fbt-flatpak -f
```

## Support

- **Tracker logs**: `journalctl --user -u wivrn-fbt-flatpak -f`
- **Configuration**: `~/.var/app/com.wivrn.WiVRn/config/wivrn-fbt/config.json`
- **Direct run**: `wivrn-fbt-flatpak --help`
- **WiVRn docs**: https://github.com/WiVRn/WiVRn
- **Flatpak docs**: https://docs.flatpak.org

## Summary

**Install**: `bash install_flatpak.sh`  
**Start**: `wivrn-fbt-start-flatpak`  
**Logs**: `journalctl --user -u wivrn-fbt-flatpak -f`  
**Config**: `wivrn-fbt-config-flatpak`  
**Stop**: `wivrn-fbt-stop-flatpak`
