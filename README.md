# HamClock LXC

<div align="center">
  <img src="https://img.shields.io/badge/Proxmox-VE-orange?style=flat-square" alt="Proxmox VE">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License">
</div>

Ham radio information display system by WB0OEW for Proxmox VE LXC containers.

## Features

- 🌍 Real-time world map with day/night terminator
- ☀️ Solar indices and space weather
- 📡 Band conditions and propagation
- 🛰️ Satellite tracking
- 🎯 DX cluster integration
- 🌐 Web-based interface

## Quick Start

Run this command on your Proxmox host shell:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/create.sh)"
```

The script will:
1. Ask for container configuration (VMID, resolution, networking)
2. Create and configure the LXC container
3. Install HamClock with optional nginx reverse proxy
4. Display access URL

**Installation time**: 5-10 minutes (includes compilation)

## Access

After installation:

**With nginx** (default):
```
http://<container-ip>/
```

**Direct access**:
```
http://<container-ip>:8081/live.html  (full access)
http://<container-ip>:8082/live.html  (read-only)
```

## Initial Setup

On first access, HamClock will guide you through:
- Station location (lat/long or callsign)
- Map center selection
- Display preferences
- DX cluster connection (optional)

## Requirements

**Proxmox Host**:
- Proxmox VE 7.0+

**Container Resources**:
- RAM: 512MB minimum (1GB recommended)
- CPU: 1 core minimum (2 cores recommended)
- Storage: 4GB

## Resolution Options

| Resolution | Display Size |
|------------|--------------|
| 800x480    | Small (7" touchscreens) |
| 1600x960   | **Recommended** - General use |
| 2400x1440  | Large displays (27"+) |
| 3200x1920  | Extra large (4K displays) |

## Configuration

The installation script will prompt for:
- **VMID**: Container ID (auto-suggested)
- **Hostname**: Container name (default: hamclock)
- **Resolution**: Display resolution (default: 1600x960)
- **Nginx**: Reverse proxy for simplified URL (default: yes)
- **Network**: DHCP or static IP configuration
- **Resources**: RAM, CPU, storage (defaults provided)

## Advanced Usage

### Environment Variables

Pre-configure settings by setting environment variables before running the script:

```bash
export HAMCLOCK_RESOLUTION="800x480"
export INSTALL_NGINX="false"
bash -c "$(wget -qLO - https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/create.sh)"
```

### Manual Installation

For manual control, download the installation script:

```bash
wget https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/install/hamclock-install.sh
chmod +x hamclock-install.sh
./hamclock-install.sh
```

## Management

```bash
# Start container
pct start <vmid>

# Stop container
pct stop <vmid>

# Access container console
pct enter <vmid>

# View HamClock logs
pct exec <vmid> -- journalctl -u hamclock -f

# Restart HamClock service
pct exec <vmid> -- systemctl restart hamclock
```

## Troubleshooting

**Container won't start**:
```bash
pct start <vmid>
journalctl -xe
```

**HamClock not accessible**:
```bash
pct exec <vmid> -- systemctl status hamclock
pct exec <vmid> -- ss -tlnp | grep 8081
```

**Check installation details**:
```bash
pct exec <vmid> -- cat /opt/hamclock_version.txt
```

## Updating HamClock

To update to a newer HamClock version:

```bash
pct enter <vmid>
cd /tmp
curl -fsSL -o ESPHamClock.tgz https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz
tar -xzf ESPHamClock.tgz
cd ESPHamClock
make hamclock-web-<resolution>  # Use your current resolution
make install
systemctl restart hamclock
```

## Uninstall

To completely remove the container:

```bash
pct stop <vmid>
pct destroy <vmid>
```

## What is HamClock?

HamClock is a comprehensive ham radio information display created by Elwood Downey (WB0OEW). It provides:

- Real-time propagation information
- Solar and geomagnetic data
- World map with gray line
- DX cluster spots
- Satellite tracking and predictions
- Band conditions
- Space weather alerts

**Official website**: https://www.clearskyinstitute.com/ham/HamClock/

## Credits

- **HamClock**: Created by Elwood Downey (WB0OEW)
- **Installation Script**: GM5DNA
- **License**: MIT

## Support

- **Issues**: https://github.com/GM5DNA/proxmox-hamclock-lxc/issues
- **HamClock Documentation**: https://www.clearskyinstitute.com/ham/HamClock/

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test in a clean Proxmox environment
4. Submit a pull request

---

**73 de GM5DNA**
