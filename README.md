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
- Container configuration (VMID, hostname, resolution)
- Network setup (DHCP or static IP)
- Resource allocation (defaults: 512MB RAM, 1 CPU core, 4GB storage)

Installation takes 5-10 minutes.

## Access

After installation, access HamClock at:

```
http://<container-ip>/
```

Or directly:
```
http://<container-ip>:8081/live.html  (full access)
http://<container-ip>:8082/live.html  (read-only)
```

## Resolution Options

Choose during installation:
- 800x480 - Small displays
- 1600x960 - Recommended
- 2400x1440 - Large displays
- 3200x1920 - 4K displays

## Management

```bash
pct start <vmid>              # Start container
pct stop <vmid>               # Stop container
pct enter <vmid>              # Access console
pct destroy <vmid>            # Remove container
```

## About HamClock

HamClock provides real-time ham radio information including propagation data, solar indices, world map with gray line, DX cluster spots, satellite tracking, and space weather alerts.

Created by Elwood Downey (WB0OEW)
Official site: https://www.clearskyinstitute.com/ham/HamClock/

## Support

- Issues: https://github.com/GM5DNA/proxmox-hamclock-lxc/issues
- HamClock docs: https://www.clearskyinstitute.com/ham/HamClock/

---

**73 de GM5DNA**
