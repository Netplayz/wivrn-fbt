# WiVRn Full Body Tracking - Installation Comparison

Two ways to run WiVRn FBT on Ubuntu.

## Quick Choice

| Need | Choose |
|------|--------|
| **Native system install** | Use `INSTALL_FINAL.sh` |
| **WiVRn Flatpak only** | Use `install_flatpak.sh` |
| **Both** | Install both |

---

## Option 1: Native Installation (Recommended)

**For**: Direct system integration, best performance, easier debugging.

### Requirements

- Ubuntu 20.04+
- `sudo` access
- WiVRn installed (any method)

### Installation

```bash
cd ~/wivrn-fbt
sudo bash INSTALL_FINAL.sh
```

### Quick Start

```bash
wivrn-fbt-start         # Start
wivrn-fbt-status        # Check status
journalctl -u wivrn-fbt -f  # View logs
wivrn-fbt-stop          # Stop
```

### Advantages

✓ Full system integration  
✓ Better performance (no sandbox overhead)  
✓ Direct hardware access  
✓ Easy debugging  
✓ Works with any WiVRn installation  

### Disadvantages

✗ Requires `sudo` for install  
✗ System-wide package management  
✗ More invasive than Flatpak  

### File Locations (Native)

```
/usr/local/bin/wivrn-fbt-service        (Binary)
/opt/wivrn-fbt/webcam_tracker.py        (Tracker)
/etc/wivrn-fbt/config.json              (System config)
~/.wivrn-fbt/config.json                (User config)
/etc/systemd/system/wivrn-fbt*.service  (Services)
```

---

## Option 2: WiVRn Flatpak Installation

**For**: Sandboxed setup, portable, uses WiVRn Flatpak runtime.

### Requirements

- WiVRn Flatpak installed:
  ```bash
  flatpak install flathub io.github.wivrn.wivrn
  ```
- No `sudo` needed (user-level only)

### Installation

```bash
cd ~/wivrn-fbt-flatpak
bash install_flatpak.sh
```

### Quick Start

```bash
wivrn-fbt-start-flatpak              # Start service
wivrn-fbt-flatpak                    # Direct run (shows preview)
wivrn-fbt-status-flatpak             # Check status
journalctl --user -u wivrn-fbt-flatpak -f  # View logs
wivrn-fbt-stop-flatpak               # Stop service
```

### Advantages

✓ Sandboxed (isolated environment)  
✓ No `sudo` required  
✓ Integrates with WiVRn Flatpak runtime  
✓ User-level systemd services  
✓ Easy to remove/reinstall  

### Disadvantages

✗ Slightly more overhead (sandbox)  
✗ Requires WiVRn Flatpak (not standalone WiVRn)  
✗ Limited to Flatpak's device permissions  

### File Locations (Flatpak)

```
~/.var/app/io.github.wivrn.wivrn/data/wivrn-fbt/
└── webcam_tracker.py

~/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/
└── config.json

~/.local/bin/
├── wivrn-fbt-flatpak
├── wivrn-fbt-start-flatpak
├── wivrn-fbt-stop-flatpak
├── wivrn-fbt-status-flatpak
└── wivrn-fbt-config-flatpak

~/.config/systemd/user/
└── wivrn-fbt-flatpak.service
```

---

## Side-by-Side Comparison

### Installation

**Native**:
```bash
sudo bash INSTALL_FINAL.sh
```

**Flatpak**:
```bash
bash install_flatpak.sh
```

### Starting

**Native**:
```bash
wivrn-fbt-start
```

**Flatpak**:
```bash
wivrn-fbt-start-flatpak
# or
wivrn-fbt-flatpak
```

### Logs

**Native**:
```bash
journalctl -u wivrn-fbt -f
```

**Flatpak**:
```bash
journalctl --user -u wivrn-fbt-flatpak -f
```

### Configuration

**Native**:
```bash
nano ~/.wivrn-fbt/config.json
```

**Flatpak**:
```bash
wivrn-fbt-config-flatpak
# or
nano ~/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/config.json
```

### Performance

| Metric | Native | Flatpak |
|--------|--------|---------|
| CPU overhead | Minimal | +1-2% |
| Latency | 50-100ms | 50-150ms |
| Memory | 200-250MB | 250-350MB |
| Startup time | <1s | 2-3s (sandbox) |

---

## When to Use Each

### Use Native If

- ✓ You want best performance
- ✓ You want direct system integration
- ✓ You use standalone WiVRn (not Flatpak)
- ✓ You want easier debugging
- ✓ You don't mind system-level packages

### Use Flatpak If

- ✓ You already use WiVRn Flatpak
- ✓ You want a sandboxed environment
- ✓ You prefer no `sudo` installation
- ✓ You want to isolate from system packages
- ✓ You like easy uninstall/reinstall

---

## Running Both (Advanced)

You can run both simultaneously if needed:

```bash
# Native service
wivrn-fbt-start &

# Flatpak service (different user or port)
wivrn-fbt-start-flatpak --port 9877
```

**Note**: They would need different UDP ports to avoid conflict.

---

## Troubleshooting

### Native Installation Issues

**Problem**: "undefined reference to xrCreateInstance"
```bash
sudo apt-get install -y libopenxr-dev libopenxr1-monado
cd ~/wivrn-fbt && rm -rf build && mkdir build && cd build && cmake .. && make
sudo cp wivrn-fbt-service /usr/local/bin/
systemctl restart wivrn-fbt.service
```

**Problem**: "Service not found"
```bash
sudo systemctl daemon-reload
wivrn-fbt-start
```

### Flatpak Issues

**Problem**: "WiVRn Flatpak not found"
```bash
flatpak install flathub io.github.wivrn.wivrn
bash install_flatpak.sh
```

**Problem**: "Service doesn't start"
```bash
journalctl --user -u wivrn-fbt-flatpak -n 50  # Show errors
systemctl --user restart wivrn-fbt-flatpak.service
```

---

## File Manifest

### For Native Installation

```
INSTALL_FINAL.sh              (Main installer)
SETUP_GUIDE.md                (Setup guide)
MANIFEST.md                   (File manifest)
wivrn_fbt_core.cpp           (C++ service)
webcam_tracker.py            (Python tracker)
CMakeLists.txt               (Build config)
wivrn_fbt_config.json        (Config template)
wivrn-fbt.service            (Systemd unit)
wivrn-fbt-webcam.service     (Systemd unit)
requirements.txt             (Python deps)
uninstall.sh                 (Uninstaller)
README.md                    (Documentation)
QUICKREF.sh                  (Quick reference)
```

### For Flatpak Installation

```
install_flatpak.sh           (Main installer)
FLATPAK_SETUP.md             (Flatpak guide)
webcam_tracker_flatpak.py    (Flatpak-compatible tracker)
wivrn_fbt_config.json        (Config template)
```

### Used by Both

```
wivrn_fbt_config.json        (Same config format)
```

---

## Migration Between Installations

### From Native to Flatpak

1. Stop native service:
   ```bash
   wivrn-fbt-stop
   ```

2. Install Flatpak:
   ```bash
   bash install_flatpak.sh
   ```

3. Copy config (optional):
   ```bash
   cp ~/.wivrn-fbt/config.json ~/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/config.json
   ```

4. Start Flatpak:
   ```bash
   wivrn-fbt-start-flatpak
   ```

### From Flatpak to Native

1. Stop Flatpak service:
   ```bash
   wivrn-fbt-stop-flatpak
   ```

2. Install native:
   ```bash
   sudo bash INSTALL_FINAL.sh
   ```

3. Copy config (optional):
   ```bash
   cp ~/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/config.json ~/.wivrn-fbt/config.json
   ```

4. Start native:
   ```bash
   wivrn-fbt-start
   ```

---

## Configuration Compatibility

Both versions use the same `wivrn_fbt_config.json` format.

You can copy configs between them:

```bash
# Flatpak → Native
cp ~/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/config.json ~/.wivrn-fbt/config.json

# Native → Flatpak
cp ~/.wivrn-fbt/config.json ~/.var/app/io.github.wivrn.wivrn/config/wivrn-fbt/config.json
```

---

## Support Matrix

| Issue | Native | Flatpak |
|-------|--------|---------|
| Camera not detected | Check `/dev/video*` | Check Flatpak permissions |
| High CPU | Lower resolution | Disable preview |
| Poor tracking | Increase smoothing | Same fix |
| OpenXR errors | Reinstall OpenXR | Included in Flatpak |
| Python errors | Install packages | Included in Flatpak |

---

## Recommended Setup

**For most users**:
```bash
# Use native if you have standalone WiVRn
sudo bash INSTALL_FINAL.sh

# Use Flatpak if you use WiVRn Flatpak
bash install_flatpak.sh
```

**For developers**:
```bash
# Install both, use native for debugging
sudo bash INSTALL_FINAL.sh
bash install_flatpak.sh
```

---

## Summary

| Aspect | Native | Flatpak |
|--------|--------|---------|
| **Install command** | `sudo bash INSTALL_FINAL.sh` | `bash install_flatpak.sh` |
| **Start command** | `wivrn-fbt-start` | `wivrn-fbt-start-flatpak` |
| **Sudo required** | Yes (install) | No |
| **Performance** | Excellent | Good |
| **Isolation** | System-wide | Sandboxed |
| **Best for** | Direct integration | WiVRn Flatpak users |

**Choose based on your WiVRn installation method!**
