# HamClock LXC

<div align="center">
  <img src="https://img.shields.io/badge/Proxmox-VE-orange?style=flat-square" alt="Proxmox VE">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License">
</div>

Ham radio information display system by WB0OEW for Proxmox VE LXC containers.

## Installation

Run this command on your Proxmox host shell:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/create.sh)"
```

The script will guide you through:
- Container configuration
- Network setup
- Resource allocation

Installation takes 5-10 minutes.

## Access

After installation:

```
http://<container-ip>/       (full access)
http://<container-ip>:8082/  (read-only)
```

## Resolution Options

Choose during installation:
- 800x480 - Small displays
- 1600x960 - Recommended
- 2400x1440 - Large displays (default)
- 3200x1920 - 4K displays

## Optional: Idle Monitoring

HamClock includes automatic CPU-saving idle monitoring (enabled by default). When no one is viewing the interface for 5 minutes, the service automatically stops to save resources. It restarts automatically when you visit the page again.

**Disable if not wanted:**
```bash
export HAMCLOCK_IDLE_MONITORING=false
# Then run installation
```

**Manage on existing installation:**
```bash
systemctl stop hamclock-idle.timer    # Disable
systemctl start hamclock-idle.timer   # Enable
```

## About HamClock

HamClock provides real-time ham radio information including propagation data, solar indices, world map with gray line, DX cluster spots, satellite tracking, and space weather alerts.

Created by Elwood Downey (WB0OEW)
Official site: https://www.clearskyinstitute.com/ham/HamClock/

## Support

- HamClock docs: https://www.clearskyinstitute.com/ham/HamClock/

---

**73 de GM5DNA**
