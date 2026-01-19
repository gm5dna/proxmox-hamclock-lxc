#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

# Standalone script to add idle monitoring to existing HamClock installation

# Simple message functions
msg_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
msg_ok() { echo -e "\033[0;32m[OK]\033[0m $1"; }
msg_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; exit 1; }

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  msg_error "This script must be run as root"
fi

# Check if HamClock service exists
if ! systemctl list-unit-files | grep -q "hamclock.service"; then
  msg_error "HamClock service not found. Please install HamClock first."
fi

msg_info "Installing HamClock Idle Monitoring"

# Configuration
IDLE_TIMEOUT=${HAMCLOCK_IDLE_TIMEOUT:-300}  # Default: 5 minutes

# Install the idle check script
cat > /usr/local/bin/hamclock-idle-check.sh << 'IDLE_SCRIPT_EOF'
#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

# HamClock Idle Monitor
# Monitors active connections to HamClock and stops the service after idle timeout

# Configuration
IDLE_TIMEOUT=${HAMCLOCK_IDLE_TIMEOUT:-300}  # Default: 5 minutes (in seconds)
TIMESTAMP_FILE="/tmp/hamclock-last-connection"
SERVICE_NAME="hamclock.service"

# Ports to monitor (HamClock web ports)
FULL_ACCESS_PORT=18081
READONLY_PORT=18082

# Log function
log() {
    logger -t hamclock-idle "$1"
}

# Check if service is running
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    # Service not running, nothing to do
    exit 0
fi

# Check for active connections on HamClock ports
# Look for ESTABLISHED connections using ss
CONNECTIONS=$(ss -tn state established "( sport = :${FULL_ACCESS_PORT} or sport = :${READONLY_PORT} )" | grep -c ESTAB)

if [ "$CONNECTIONS" -gt 0 ]; then
    # Active connections detected - update timestamp
    date +%s > "$TIMESTAMP_FILE"
    log "Active connections detected ($CONNECTIONS), updating timestamp"
    exit 0
fi

# No active connections - check idle time
if [ ! -f "$TIMESTAMP_FILE" ]; then
    # First time with no connections - create timestamp
    date +%s > "$TIMESTAMP_FILE"
    log "No active connections, starting idle timer"
    exit 0
fi

# Calculate idle time
LAST_CONNECTION=$(cat "$TIMESTAMP_FILE")
CURRENT_TIME=$(date +%s)
IDLE_SECONDS=$((CURRENT_TIME - LAST_CONNECTION))

if [ "$IDLE_SECONDS" -ge "$IDLE_TIMEOUT" ]; then
    # Idle timeout exceeded - stop service
    log "Idle timeout exceeded (${IDLE_SECONDS}s >= ${IDLE_TIMEOUT}s), stopping HamClock service"
    systemctl stop "$SERVICE_NAME"

    # Clean up timestamp file
    rm -f "$TIMESTAMP_FILE"

    log "HamClock service stopped due to inactivity"
else
    # Still within idle timeout
    REMAINING=$((IDLE_TIMEOUT - IDLE_SECONDS))
    log "Idle for ${IDLE_SECONDS}s, will stop in ${REMAINING}s if no connections"
fi

exit 0
IDLE_SCRIPT_EOF

chmod +x /usr/local/bin/hamclock-idle-check.sh
msg_ok "Installed idle check script"

# Create systemd service
cat > /etc/systemd/system/hamclock-idle.service << 'IDLE_SERVICE_EOF'
[Unit]
Description=HamClock Idle Monitor
Documentation=https://github.com/GM5DNA/proxmox-hamclock-lxc
After=hamclock.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hamclock-idle-check.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
IDLE_SERVICE_EOF

msg_ok "Created systemd service"

# Create systemd timer
cat > /etc/systemd/system/hamclock-idle.timer << 'IDLE_TIMER_EOF'
[Unit]
Description=HamClock Idle Monitor Timer
Documentation=https://github.com/GM5DNA/proxmox-hamclock-lxc

[Timer]
# Run every 10 seconds
OnBootSec=10s
OnUnitActiveSec=10s
AccuracySec=1s

[Install]
WantedBy=timers.target
IDLE_TIMER_EOF

msg_ok "Created systemd timer"

# Enable and start the timer
systemctl daemon-reload
systemctl enable hamclock-idle.timer
systemctl start hamclock-idle.timer

# Verify timer is active
sleep 2
if systemctl is-active --quiet hamclock-idle.timer; then
  msg_ok "Idle monitoring enabled successfully"
  echo ""
  echo "Configuration:"
  echo "  Idle timeout: ${IDLE_TIMEOUT}s ($(($IDLE_TIMEOUT / 60)) minutes)"
  echo "  Check interval: 10 seconds"
  echo ""
  echo "Monitoring:"
  echo "  Timer status: systemctl status hamclock-idle.timer"
  echo "  Check logs:   journalctl -u hamclock-idle -f"
  echo ""
  echo "To change timeout, set HAMCLOCK_IDLE_TIMEOUT environment variable:"
  echo "  export HAMCLOCK_IDLE_TIMEOUT=600  # 10 minutes"
  echo "  systemctl restart hamclock-idle.timer"
  echo ""
  echo "To disable idle monitoring:"
  echo "  systemctl stop hamclock-idle.timer"
  echo "  systemctl disable hamclock-idle.timer"
else
  msg_error "Failed to start idle monitoring timer"
fi
