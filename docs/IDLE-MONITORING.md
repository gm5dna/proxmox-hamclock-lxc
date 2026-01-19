# HamClock Idle Monitoring

## Overview

The idle monitoring feature automatically stops the HamClock service when no web connections are active for a configurable period. This reduces CPU usage from ~30-35% to near zero when HamClock is not being viewed.

## How It Works

1. **Connection Monitoring**: Every 10 seconds, the system checks for active TCP connections on HamClock's web ports (18081 and 18082)
2. **Idle Tracking**: When no connections are detected, an idle timer starts counting
3. **Automatic Shutdown**: After the idle timeout expires (default: 5 minutes), the HamClock service is automatically stopped
4. **Automatic Restart**: When you access the web interface, it automatically starts HamClock and shows a friendly "Starting..." page (~3-5 seconds)

**Result**: Seamless user experience with significant CPU savings when not in use.

## Architecture

The idle monitoring system consists of three components:

### 1. Idle Check Script (`/usr/local/bin/hamclock-idle-check.sh`)
- Monitors active TCP connections using `ss` command
- Tracks last connection timestamp in `/tmp/hamclock-last-connection`
- Stops the HamClock service when idle timeout is exceeded
- Logs all actions to system journal with tag `hamclock-idle`

### 2. Systemd Service (`hamclock-idle.service`)
- Type: oneshot (runs and exits)
- Executes the idle check script
- Dependency: After `hamclock.service`

### 3. Systemd Timer (`hamclock-idle.timer`)
- Triggers the service every 10 seconds
- Starts 10 seconds after boot
- Enabled by default when installed

## Installation

### For New Installations

Idle monitoring is installed by default. To disable it, set the environment variable:

```bash
export HAMCLOCK_IDLE_MONITORING=false
./install/hamclock-install.sh
```

### For Existing Installations

Use the standalone installation script:

```bash
# On the container
bash scripts/install-idle-monitoring.sh

# Or deploy remotely to container 110
bash scripts/deploy-idle-monitoring-to-110.sh
```

## Configuration

### Change Idle Timeout

The default idle timeout is 300 seconds (5 minutes). To change it:

```bash
# Set environment variable
export HAMCLOCK_IDLE_TIMEOUT=600  # 10 minutes

# Restart the timer to apply (the script reads env var at runtime)
systemctl restart hamclock-idle.timer
```

Or edit the script directly:

```bash
# Edit the script
nano /usr/local/bin/hamclock-idle-check.sh

# Find this line and change the default:
IDLE_TIMEOUT=${HAMCLOCK_IDLE_TIMEOUT:-300}

# No need to restart - change takes effect on next check
```

### Common Timeout Values

- **1 minute**: `HAMCLOCK_IDLE_TIMEOUT=60`
- **5 minutes** (default): `HAMCLOCK_IDLE_TIMEOUT=300`
- **10 minutes**: `HAMCLOCK_IDLE_TIMEOUT=600`
- **30 minutes**: `HAMCLOCK_IDLE_TIMEOUT=1800`
- **1 hour**: `HAMCLOCK_IDLE_TIMEOUT=3600`

## Usage

### Check Timer Status

```bash
systemctl status hamclock-idle.timer
```

### View Idle Monitoring Logs

```bash
# Follow logs in real-time
journalctl -u hamclock-idle -f

# View recent logs
journalctl -u hamclock-idle -n 50
```

### Starting HamClock After Idle Stop

**Automatic (Recommended):**
Simply visit the web interface - it will automatically start HamClock and redirect when ready (~3-5 seconds).

**Manual:**
```bash
systemctl start hamclock
```

The automatic restart feature requires the auto-start components (installed by default). See the main README for details.

### Disable Idle Monitoring

```bash
# Stop and disable the timer
systemctl stop hamclock-idle.timer
systemctl disable hamclock-idle.timer

# HamClock will now run continuously
```

### Re-enable Idle Monitoring

```bash
systemctl enable hamclock-idle.timer
systemctl start hamclock-idle.timer
```

### Uninstall Idle Monitoring

```bash
# Stop and disable
systemctl stop hamclock-idle.timer
systemctl disable hamclock-idle.timer

# Remove files
rm -f /usr/local/bin/hamclock-idle-check.sh
rm -f /etc/systemd/system/hamclock-idle.service
rm -f /etc/systemd/system/hamclock-idle.timer
rm -f /tmp/hamclock-last-connection

# Reload systemd
systemctl daemon-reload
```

## Monitoring

### Check Current Idle Time

```bash
# If timestamp file exists
if [ -f /tmp/hamclock-last-connection ]; then
  LAST=$(cat /tmp/hamclock-last-connection)
  NOW=$(date +%s)
  IDLE=$((NOW - LAST))
  echo "Idle for $IDLE seconds ($(($IDLE / 60)) minutes)"
else
  echo "No timestamp file (service stopped or recently started)"
fi
```

### Check Active Connections

```bash
# View connections on HamClock ports
ss -tn state established '( sport = :18081 or sport = :18082 )'

# Count connections
ss -tn state established '( sport = :18081 or sport = :18082 )' | grep -c ESTAB
```

## Troubleshooting

### Service Keeps Stopping Immediately

**Cause**: Idle timeout is too short or connections aren't being detected

**Solutions**:
1. Increase idle timeout: `export HAMCLOCK_IDLE_TIMEOUT=600`
2. Check logs to see what's happening: `journalctl -u hamclock-idle -f`
3. Verify connections are being counted: `ss -tn state established '( sport = :18081 )'`

### Timer Not Running

**Check timer status**:
```bash
systemctl status hamclock-idle.timer
```

**Enable and start**:
```bash
systemctl enable hamclock-idle.timer
systemctl start hamclock-idle.timer
```

### Logs Show "No active connections" But I'm Connected

**Possible causes**:
1. Using port 80 via nginx instead of direct ports (this is expected - nginx -> 18081)
2. Connections on wrong port numbers
3. Container network isolation issues

**Verify**:
```bash
# Check all established connections
ss -tn state established

# Should show connections on ports 18081 or 18082
```

### Service Won't Stop (Keeps Running)

**Possible causes**:
1. Persistent connections keeping HamClock active
2. Timer not running
3. Script errors

**Check**:
```bash
# Verify timer is active
systemctl is-active hamclock-idle.timer

# Check recent logs for errors
journalctl -u hamclock-idle -n 20

# Manually run check script for debugging
bash -x /usr/local/bin/hamclock-idle-check.sh
```

## Performance Impact

### Before Idle Monitoring
- HamClock running continuously
- CPU usage: ~30-35% (2400x1440 resolution, 2 cores)
- Memory: ~150MB

### After Idle Monitoring (When Stopped)
- HamClock stopped when not in use
- CPU usage: ~0%
- Memory: ~10MB (systemd timer only)

### When Active
- No performance impact during active use
- Check runs in <1 second every 10 seconds
- Minimal CPU overhead (<0.1%)

## Use Cases

### Home Server (Occasional Viewing)
- **Recommended timeout**: 5-10 minutes
- **Benefit**: Significant CPU savings, instant on-demand viewing

### Public Display (Frequent Viewing)
- **Recommended timeout**: 30 minutes - 1 hour
- **Benefit**: Reduced CPU during off-peak hours

### 24/7 Display
- **Recommendation**: Disable idle monitoring
- **Reason**: Service will constantly stop/start

## Integration with Reverse Proxies

The idle monitor tracks connections on HamClock's ports (18081/18082), which works correctly with reverse proxies:

- Nginx on port 80 → forwards to → HamClock on port 18081
- External proxy (Traefik) → Nginx → HamClock

When a client connects via the proxy, the proxy maintains a connection to port 18081, which the idle monitor detects correctly.

## Integration with Auto-Start Feature

Idle monitoring works seamlessly with the auto-start feature (installed by default):

**When HamClock is stopped** (due to idle timeout):
1. User visits the web interface
2. Custom "Starting..." page displays with animated progress
3. API endpoint triggers `systemctl start hamclock` via CGI
4. Page polls every 500ms checking for service readiness
5. Auto-redirects to HamClock when ready (~3-5 seconds)

**Result**: Users never see a 502 error and don't need to manually restart the service.

**Technical Details**:
- Auto-start uses fcgiwrap + sudo for permission management
- CGI script at `/usr/lib/cgi-bin/start-hamclock.sh`
- Sudoers configuration at `/etc/sudoers.d/hamclock-www`
- Custom HTML page at `/var/www/hamclock/hamclock-starting.html`

## Future Enhancements

Potential improvements being considered:

1. **Configurable Check Interval**: Make the 10-second interval user-configurable
2. **Web Dashboard**: Show idle time and status via web interface
3. **Multiple Timeouts**: Different timeouts for different times of day
4. **Connection Count Threshold**: Only stop if connections drop below N for X minutes
5. **Wake-on-LAN Integration**: Start HamClock from other services

## Contributing

If you have suggestions or improvements for the idle monitoring feature, please:

1. Open an issue on GitHub
2. Submit a pull request with your changes
3. Share your use case and configuration

## License

MIT License - see project LICENSE file

## Author

GM5DNA

---

**Documentation Version**: 1.0
**Last Updated**: 2026-01-19
