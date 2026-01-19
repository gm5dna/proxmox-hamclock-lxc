# HamClock Proxmox LXC

<div align="center">
  <img src="https://img.shields.io/badge/Proxmox-VE-orange?style=flat-square" alt="Proxmox VE">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/HamClock-Web-green?style=flat-square" alt="HamClock">
</div>

<p align="center">
  <strong>Professional ham radio information display for Proxmox VE LXC containers</strong><br>
  Created by Elwood Downey (WB0OEW) | Packaged by GM5DNA
</p>

---

## Features

✨ **Easy Installation** - Single command deployment with interactive configuration
🌐 **Web-Based** - Access from any device via web browser (no desktop required)
⚡ **Auto-Start** - Friendly "Starting..." page instead of 502 errors (~3-5 second startup)
💤 **Idle Monitoring** - Automatic CPU-saving when not in use (30-35% → ~0%)
🔒 **Security** - Separate read-only port for public access
🎨 **Resolution Options** - Choose from 800x480 to 3200x1920
🔄 **Reverse Proxy Ready** - WebSocket header forwarding for HTTPS support
📦 **Minimal Footprint** - Lightweight LXC container deployment

## Quick Start

Run this command on your Proxmox VE host shell:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/create.sh)"
```

The installer will guide you through:
- Container ID and hostname
- Network configuration (DHCP or static)
- Resource allocation (RAM, CPU, storage)
- Resolution selection

**Installation time**: ~5-10 minutes

## Access

After installation, access HamClock via:

```
http://<container-ip>/        - Full access (configuration & viewing)
http://<container-ip>:8082/   - Read-only access (viewing only)
```

The interface will automatically start HamClock if it was stopped to save resources.

## Resolution Options

Choose the best resolution for your display during installation:

| Resolution | Target Use Case | Memory | CPU Load |
|------------|----------------|---------|----------|
| 800x480 | Small displays, low-power | ~50MB | 15-20% |
| 1600x960 | General use | ~100MB | 25-30% |
| **2400x1440** | **Large displays (default)** | **~150MB** | **30-35%** |
| 3200x1920 | 4K displays | ~200MB | 35-40% |

*CPU percentages shown for 2-core allocation when actively displaying*

## Advanced Features

### Idle Monitoring

HamClock automatically stops when no web connections are active for 5 minutes, reducing CPU usage to near zero. When you access the site again, it starts automatically in 3-5 seconds.

**Configure idle timeout:**
```bash
# Set custom timeout (in seconds)
export HAMCLOCK_IDLE_TIMEOUT=600  # 10 minutes

# Disable idle monitoring
export HAMCLOCK_IDLE_MONITORING=false
```

**Manage idle monitoring:**
```bash
# Check status
systemctl status hamclock-idle.timer

# View logs
journalctl -u hamclock-idle -f

# Disable
systemctl stop hamclock-idle.timer
systemctl disable hamclock-idle.timer
```

[Full documentation →](docs/IDLE-MONITORING.md)

### Auto-Start on Access

When HamClock is stopped (due to idle monitoring), accessing the web interface:
1. Shows a friendly "Starting..." page with animated progress
2. Automatically triggers service startup
3. Polls for readiness every 500ms
4. Redirects to HamClock when ready (~3-5 seconds)

No more 502 Bad Gateway errors!

### Reverse Proxy Support

The installation includes nginx with proper WebSocket header forwarding for external reverse proxies (Traefik, Nginx Proxy Manager, etc.).

**Example Traefik configuration:**
```yaml
# Ensure WebSocket headers are forwarded
- "traefik.http.middlewares.ws-headers.headers.customrequestheaders.Upgrade=websocket"
- "traefik.http.middlewares.ws-headers.headers.customrequestheaders.Connection=Upgrade"
```

## Service Management

```bash
# Access container
pct enter <vmid>

# Service commands
systemctl status hamclock       # Check status
systemctl start hamclock        # Start service
systemctl stop hamclock         # Stop service
systemctl restart hamclock      # Restart service

# View logs
journalctl -u hamclock -f       # Follow logs
journalctl -u hamclock -n 50    # Last 50 lines

# Check version info
cat /opt/hamclock_version.txt
```

## Upgrading

To install features on an existing HamClock installation:

```bash
# Add idle monitoring
bash scripts/install-idle-monitoring.sh

# Add auto-start feature
bash scripts/install-auto-start.sh
```

## Resource Requirements

**Minimum:**
- RAM: 512MB
- CPU: 1 core
- Storage: 2GB

**Recommended:**
- RAM: 1GB
- CPU: 2 cores
- Storage: 4GB

**With idle monitoring**, actual resource usage is minimal when not viewing HamClock.

## What is HamClock?

HamClock by Elwood Downey (WB0OEW) is a comprehensive ham radio information display featuring:

- 🌍 World map with gray line and sun position
- 📡 Real-time propagation data and solar indices
- 🛰️ Satellite tracking (ISS, amateur satellites)
- ⚡ DX cluster integration with spots
- 🌦️ Space weather alerts and conditions
- 📊 Band conditions and predictions
- 🕐 Multiple time zones and UTC
- 📈 Solar flux, A/K indices, and more

**Official HamClock site:** https://www.clearskyinstitute.com/ham/HamClock/

## Troubleshooting

### HamClock won't start

```bash
# Check service status
systemctl status hamclock

# View detailed logs
journalctl -u hamclock -n 100

# Restart service
systemctl restart hamclock
```

### Can't access web interface

```bash
# Check if service is running
systemctl is-active hamclock

# Check listening ports
ss -tlnp | grep -E "18081|18082|:80"

# Test locally
curl http://localhost:80/live.html
```

### 502 error persists

The auto-start feature should prevent this, but if it persists:

```bash
# Verify auto-start components
systemctl status fcgiwrap
cat /etc/sudoers.d/hamclock-www
ls -la /usr/lib/cgi-bin/start-hamclock.sh

# Test API endpoint
curl -X POST http://localhost:80/api/start-hamclock
```

### High CPU usage

HamClock uses CPU for rendering and calculations. To reduce usage:

1. **Enable idle monitoring** (enabled by default)
2. **Use a lower resolution** (800x480 or 1600x960)
3. **Allocate more CPU cores** to spread the load

## Architecture

- **Base**: Debian 12 LXC container
- **Build**: HamClock web-only build (truly headless, no X11 at runtime)
- **Web Server**: Nginx reverse proxy with WebSocket support
- **Service**: Systemd-managed HamClock service
- **Automation**: CGI-based auto-start with fcgiwrap
- **Monitoring**: Systemd timer-based idle detection

## Project Structure

```
.
├── install/
│   └── hamclock-install.sh    # Main installation script
├── scripts/
│   ├── install-idle-monitoring.sh   # Add idle monitoring
│   ├── install-auto-start.sh        # Add auto-start feature
│   ├── hamclock-starting.html       # Loading page
│   └── ...
├── docs/
│   └── IDLE-MONITORING.md     # Idle monitoring documentation
├── claude.md                   # AI assistant context
└── README.md                   # This file
```

## Contributing

Issues and pull requests welcome at:
https://github.com/GM5DNA/proxmox-hamclock-lxc

## License

MIT License - See LICENSE file for details

HamClock itself is created and maintained by Elwood Downey (WB0OEW).
This is an independent packaging project for Proxmox VE deployment.

## Credits

- **HamClock**: Elwood Downey (WB0OEW) - https://www.clearskyinstitute.com/ham/HamClock/
- **Proxmox Helper Scripts**: Community Scripts project for installation patterns
- **Packaging**: GM5DNA

---

**73 de GM5DNA**

*For more details, see the documentation in the `/docs` directory.*
