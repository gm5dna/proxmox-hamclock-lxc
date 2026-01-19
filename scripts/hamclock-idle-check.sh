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
