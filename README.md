# HamClock Proxmox LXC Helper Script

Automated installation script for HamClock (ham radio information display) on Proxmox VE LXC containers.

## What is HamClock?

HamClock is a comprehensive ham radio information display created by Elwood Downey (WB0OEW). It provides real-time information including:

- World map with day/night terminator and gray line
- Solar indices (SFI, SSN, Kp, A-index)
- Band conditions and propagation predictions
- DXCC prefix lookup and beam headings
- Satellite tracking and passes
- Space weather alerts and warnings

**Official Website**: https://www.clearskyinstitute.com/ham/HamClock/

## Features

- **One-Command Installation**: Automated setup following community-scripts patterns
- **Interactive Resolution Selection**: Choose from 4 display resolutions during installation
- **Web-Based Interface**: Access from any device on your network
- **Nginx Reverse Proxy** (optional): Simple URL access at `http://container-ip/` instead of `:8081/live.html`
- **LXC Optimized**: Uses web-only builds for minimal resource usage
- **Automatic Startup**: Systemd service with auto-restart on failure
- **Comprehensive Documentation**: Built-in version tracking and usage information

## Requirements

### Proxmox Host
- Proxmox VE 7.0 or newer
- Network connectivity for LXC container

### LXC Container
- **OS**: Debian 12 (Bookworm) or Ubuntu 20.04+
- **RAM**: 1GB minimum (2GB recommended for compilation)
- **CPU**: 2 cores recommended
- **Storage**: 4GB minimum
- **Network**: Internet access during installation

## Quick Start

### 1. Create LXC Container

In Proxmox VE:

```bash
pct create 100 local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
  --hostname hamclock \
  --memory 1024 \
  --cores 2 \
  --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --start 1
```

Or use the Proxmox web UI to create a Debian 12 or Ubuntu 20.04+ container.

### 2. Access Container

```bash
pct enter 100
```

Or SSH into the container after obtaining its IP address.

### 3. Run Installation Script

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/install/hamclock-install.sh)"
```

### 4. Select Resolution

During installation, you'll be prompted to choose a display resolution:

| Resolution | Recommended For |
|------------|----------------|
| **800x480** | Small displays, 7" touchscreens |
| **1600x960** | General use (recommended default) |
| **2400x1440** | Large displays, 27"+ monitors |
| **3200x1920** | 4K displays, presentation systems |

Use arrow keys to select and press Enter.

### 5. Access HamClock

After installation completes, access the web interface:

**With Nginx (default)**:
```
http://<container-ip>/
```

**Direct access** (without nginx or on specific ports):
```
http://<container-ip>:8081/live.html  (full access)
http://<container-ip>:8082/live.html  (read-only)
```

Replace `<container-ip>` with your container's IP address (shown at end of installation).

## Post-Installation

### Initial Setup

On first access, HamClock will guide you through:

1. **Station Location**: Enter your latitude/longitude or callsign
2. **Map Center**: Choose where to center the world map
3. **Display Preferences**: Configure colors and layout
4. **DX Cluster**: Optionally connect to DX spotting network
5. **Additional Features**: Configure satellite tracking, alerts, etc.

### Web Interface Ports

- **Port 8081**: Full access (view and configure)
- **Port 8082**: Read-only access (display only)

### Service Management

```bash
# Check service status
systemctl status hamclock

# Restart service
systemctl restart hamclock

# View logs
journalctl -u hamclock -f

# Stop service
systemctl stop hamclock

# Start service
systemctl start hamclock
```

### Configuration Files

- **Binary**: `/usr/local/bin/hamclock`
- **Configuration**: `/root/.hamclock/`
- **Service**: `/etc/systemd/system/hamclock.service`
- **Version Info**: `/opt/hamclock_version.txt`

## Advanced Usage

### Non-Interactive Installation

Pre-set the resolution using an environment variable:

```bash
export HAMCLOCK_RESOLUTION="1600x960"
./hamclock-install.sh
```

This is useful for automated deployments.

### Nginx Configuration

By default, the installation includes nginx as a reverse proxy for simplified access. You can control this behavior:

**Install without nginx**:
```bash
export INSTALL_NGINX=false
./hamclock-install.sh
```

**What nginx provides**:
- Access HamClock at `http://container-ip/` instead of `http://container-ip:8081/live.html`
- Automatic redirect from root path to `/live.html`
- Standard HTTP port (80) access
- All HamClock features still accessible on ports 8081/8082

**Nginx configuration location**: `/etc/nginx/sites-available/hamclock`

### Changing Resolution

Resolution cannot be changed from the web interface. To change it:

1. Stop the service: `systemctl stop hamclock`
2. Download source: `curl -fsSL -o /tmp/ESPHamClock.tgz https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz`
3. Extract: `cd /tmp && tar -xzf ESPHamClock.tgz && cd ESPHamClock`
4. Compile new resolution: `make -j $(nproc) hamclock-web-<resolution>`
5. Install: `make install`
6. Update version file: Edit `/opt/hamclock_version.txt`
7. Restart: `systemctl restart hamclock`

### Firewall Configuration

If using Proxmox firewall or external firewall, allow these ports:

```bash
# UFW
ufw allow 8081/tcp
ufw allow 8082/tcp

# iptables
iptables -A INPUT -p tcp --dport 8081 -j ACCEPT
iptables -A INPUT -p tcp --dport 8082 -j ACCEPT
```

### Adding Authentication

HamClock has no built-in authentication. For secure external access, use a reverse proxy:

**Nginx Example**:
```nginx
server {
    listen 80;
    server_name hamclock.example.com;

    location / {
        auth_basic "HamClock";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://localhost:8081;
    }
}
```

## Troubleshooting

### Service Won't Start

```bash
# Check service status
systemctl status hamclock

# View detailed logs
journalctl -u hamclock -n 50

# Common causes:
# - Ports 8081/8082 already in use
# - Network not available
# - Binary missing or corrupted
```

### Web Interface Not Accessible

```bash
# Verify service is running
systemctl is-active hamclock

# Check if ports are listening
ss -tlnp | grep 8081

# Test locally first
curl -I http://localhost:8081/live.html

# If local works, check firewall
iptables -L -n | grep 8081
```

### Compilation Fails

```bash
# Check available memory
free -h

# If low, increase container memory (from Proxmox host):
pct set <vmid> -memory 2048

# Check disk space
df -h

# Verify dependencies installed
apt-get install --reinstall make g++ libx11-dev linux-libc-dev libssl-dev
```

### Display Issues

If the web interface loads but displays incorrectly:

1. Clear browser cache
2. Try different browser
3. Check resolution matches your display capabilities
4. Verify JavaScript is enabled

## Uninstallation

To completely remove HamClock:

```bash
# Stop and disable service
systemctl stop hamclock
systemctl disable hamclock

# Remove files
rm -f /usr/local/bin/hamclock
rm -rf /root/.hamclock
rm -f /etc/systemd/system/hamclock.service
rm -f /opt/hamclock_version.txt

# Reload systemd
systemctl daemon-reload

# Optional: Remove dependencies
apt-get autoremove -y make g++ libx11-dev linux-libc-dev libssl-dev
```

## Project Information

### Author
**GM5DNA**

### Repository
https://github.com/GM5DNA/proxmox-hamclock-lxc

### License
MIT License - See LICENSE file for details

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes in a clean LXC container
4. Update documentation as needed
5. Submit a pull request

### Issues

Report bugs or request features at:
https://github.com/GM5DNA/proxmox-hamclock-lxc/issues

## Additional Documentation

- **project.md**: Comprehensive project documentation, architecture decisions, and development guide
- **claude.md**: AI assistant context and development patterns
- **examples/hamclock.service**: Reference systemd service file

## Resources

### HamClock
- **Homepage**: https://www.clearskyinstitute.com/ham/HamClock/
- **Documentation**: https://www.clearskyinstitute.com/ham/HamClock/
- **Source Code**: https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz

### Proxmox
- **Proxmox VE Documentation**: https://pve.proxmox.com/pve-docs/
- **LXC Containers**: https://pve.proxmox.com/wiki/Linux_Container
- **Community Scripts**: https://github.com/community-scripts/ProxmoxVE

### Ham Radio
- **ARRL**: https://www.arrl.org/
- **QRZ**: https://www.qrz.com/
- **DX Maps**: https://www.dxmaps.com/

## Acknowledgments

- **Elwood Downey (WB0OEW)**: Creator of HamClock
- **Community Scripts Team**: Patterns and conventions reference
- **Proxmox Community**: LXC container expertise

## Version History

### Version 1.0 (2026-01-18)
- Initial release
- Support for 4 resolution options
- Debian 12 and Ubuntu 20.04+ support
- Systemd service with auto-restart
- Web interface on ports 8081/8082
- Comprehensive documentation

---

**73 and happy DXing!**

*This script is not officially affiliated with HamClock or Clear Sky Institute. It's a community contribution to make HamClock easier to deploy on Proxmox VE.*
