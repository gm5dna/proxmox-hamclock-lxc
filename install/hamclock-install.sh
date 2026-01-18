#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

source $FUNCTIONS_FILE_PATH
color
verb_ip6
catch_errors
setting_up_container

msg_info "Running Network Check"
network_check
msg_ok "Network Check Passed"

msg_info "Updating Container OS"
update_os
msg_ok "Updated Container OS"

#=============================================================================
# PHASE 2: Install Dependencies
#=============================================================================
msg_info "Installing Build Dependencies"
$STD apt-get install -y \
  make \
  g++ \
  libx11-dev \
  linux-libc-dev \
  libssl-dev \
  curl
msg_ok "Installed Build Dependencies"

#=============================================================================
# PHASE 3: Resolution Selection
#=============================================================================
msg_info "Selecting HamClock Resolution"

# Define resolution options
RESOLUTIONS=(
  "800x480" "Small (Compact displays)"
  "1600x960" "Recommended (Default)"
  "2400x1440" "Large displays"
  "3200x1920" "Extra Large (4K displays)"
)

# Check if resolution is pre-set via environment variable
if [ -n "$HAMCLOCK_RESOLUTION" ]; then
  RESOLUTION="$HAMCLOCK_RESOLUTION"
  msg_info "Using pre-set resolution from environment: $RESOLUTION"
# Use whiptail for interactive selection if available and in interactive mode
elif command -v whiptail &> /dev/null && [ -t 0 ]; then
  RESOLUTION=$(whiptail --title "HamClock Resolution" --menu \
    "Choose display resolution for HamClock web interface:" 16 60 4 \
    "${RESOLUTIONS[@]}" \
    3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus != 0 ]; then
    msg_info "Using default resolution (1600x960)"
    RESOLUTION="1600x960"
  fi
else
  # Fallback to default if non-interactive or whiptail unavailable
  RESOLUTION="1600x960"
  msg_info "Non-interactive mode or whiptail unavailable, using default resolution: $RESOLUTION"
fi

BUILD_TARGET="hamclock-web-${RESOLUTION}"
msg_ok "Selected Resolution: $RESOLUTION (Target: $BUILD_TARGET)"

#=============================================================================
# PHASE 4: Download Source
#=============================================================================
msg_info "Downloading HamClock Source"
DOWNLOAD_URL="https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz"
TEMP_DIR="/tmp/ESPHamClock"

cd /tmp
$STD curl -fsSL -o ESPHamClock.tgz "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
  msg_error "Failed to download HamClock source from $DOWNLOAD_URL"
  exit 1
fi

$STD tar -xzf ESPHamClock.tgz
if [ ! -d "$TEMP_DIR" ]; then
  msg_error "Failed to extract HamClock source"
  exit 1
fi
msg_ok "Downloaded and Extracted HamClock Source"

#=============================================================================
# PHASE 5: Compilation
#=============================================================================
msg_info "Compiling HamClock ($BUILD_TARGET)"
cd "$TEMP_DIR"

# Compile with parallel jobs
$STD make -j $(nproc) "$BUILD_TARGET"
if [ $? -ne 0 ]; then
  msg_error "Failed to compile HamClock target: $BUILD_TARGET"
  exit 1
fi
msg_ok "Compiled HamClock Successfully"

#=============================================================================
# PHASE 6: Installation
#=============================================================================
msg_info "Installing HamClock"
$STD make install
if [ $? -ne 0 ]; then
  msg_error "Failed to install HamClock"
  exit 1
fi

# Verify installation
if [ ! -f "/usr/local/bin/hamclock" ]; then
  msg_error "HamClock binary not found at /usr/local/bin/hamclock"
  exit 1
fi
msg_ok "Installed HamClock to /usr/local/bin"

#=============================================================================
# PHASE 7: Service Creation
#=============================================================================
msg_info "Creating HamClock systemd Service"

cat > /etc/systemd/system/hamclock.service << 'EOF'
[Unit]
Description=HamClock Ham Radio Information Display
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hamclock
Restart=on-failure
RestartSec=5s
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl daemon-reload
$STD systemctl enable hamclock.service
$STD systemctl start hamclock.service

# Give service time to start
sleep 3

if ! systemctl is-active --quiet hamclock.service; then
  msg_error "HamClock service failed to start"
  systemctl status hamclock.service
  exit 1
fi
msg_ok "Created and Started HamClock Service"

#=============================================================================
# PHASE 8: Version Tracking
#=============================================================================
msg_info "Creating Version Information"

# Get container IP
CONTAINER_IP=$(hostname -I | awk '{print $1}')

cat > /opt/hamclock_version.txt << EOF
HamClock Installation Information
==================================
Installation Date: $(date)
Resolution: $RESOLUTION
Build Target: $BUILD_TARGET
Binary Location: /usr/local/bin/hamclock
Configuration: /root/.hamclock

Web Interface URLs:
  Full Access: http://$CONTAINER_IP:8081/live.html
  Read-Only:   http://$CONTAINER_IP:8082/live.html

Service Management:
  Status:  systemctl status hamclock
  Start:   systemctl start hamclock
  Stop:    systemctl stop hamclock
  Restart: systemctl restart hamclock
  Logs:    journalctl -u hamclock -f

Documentation:
  HamClock Site: https://www.clearskyinstitute.com/ham/HamClock/
  Source Code:   https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz
EOF

msg_ok "Created Version Information at /opt/hamclock_version.txt"

#=============================================================================
# PHASE 9: Cleanup
#=============================================================================
msg_info "Cleaning Up"
cd /tmp
rm -rf ESPHamClock ESPHamClock.tgz
$STD apt-get autoremove -y
$STD apt-get autoclean
msg_ok "Cleaned Up Temporary Files"

#=============================================================================
# PHASE 10: Finalization
#=============================================================================
motd_ssh
customize

msg_info "HamClock Installation Complete!"
echo ""
cat /opt/hamclock_version.txt
echo ""
msg_ok "Access HamClock at: http://$CONTAINER_IP:8081/live.html"

cleanup_lxc
