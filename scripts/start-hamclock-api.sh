#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

# API endpoint script to start HamClock service
# Called by nginx when user accesses HamClock while service is stopped

# Print HTTP status first
echo "Status: 200 OK"
echo "Content-Type: application/json"
echo ""

# Check if service is already running
if sudo systemctl is-active --quiet hamclock.service; then
    echo '{"status":"running","message":"HamClock is already running"}'
    exit 0
fi

# Start the service
if sudo systemctl start hamclock.service 2>&1; then
    echo '{"status":"starting","message":"HamClock service started successfully"}'
    logger -t hamclock-api "HamClock started via web interface"
    exit 0
else
    echo '{"status":"error","message":"Failed to start HamClock service"}'
    exit 1
fi
