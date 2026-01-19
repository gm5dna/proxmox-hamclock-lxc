#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

# Check if community-scripts functions are available
if [ -n "$FUNCTIONS_FILE_PATH" ] && [ -f "$FUNCTIONS_FILE_PATH" ]; then
    # Running via community-scripts - use their functions
    source $FUNCTIONS_FILE_PATH
    color
    verb_ip6
    catch_errors
    setting_up_container
else
    # Standalone mode - define our own functions
    color() { :; }
    verb_ip6() { :; }
    catch_errors() { set -e; }
    setting_up_container() { :; }
    motd_ssh() { :; }
    customize() { :; }
    cleanup_lxc() { :; }
    msg_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
    msg_ok() { echo -e "\033[0;32m[OK]\033[0m $1"; }
    msg_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; exit 1; }
    network_check() {
        if ! ping -c 1 8.8.8.8 &>/dev/null; then
            msg_error "Network check failed - no internet connectivity"
        fi
    }
    update_os() {
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
    }
    STD=""
fi

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
ExecStart=/usr/local/bin/hamclock -w 18081 -r 18082
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
# PHASE 7: Nginx Reverse Proxy Configuration
#=============================================================================
msg_info "Installing Nginx Reverse Proxy"

# Install nginx
$STD apt-get install -y nginx

# Create nginx configuration
cat > /etc/nginx/sites-available/hamclock << 'NGINX_EOF'
# Map to determine the proper scheme (handle reverse proxy)
map $http_x_forwarded_proto $redirect_scheme {
    default $scheme;
    https https;
    http http;
}

# Full access on port 80
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Redirect root to live.html (preserve scheme for HTTPS proxies)
    location = / {
        return 301 $redirect_scheme://$host/live.html;
    }

    # Proxy all other requests to HamClock full access (port 18081)
    location / {
        proxy_pass http://127.0.0.1:18081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Read-only access on port 8082
server {
    listen 8082 default_server;
    listen [::]:8082 default_server;
    server_name _;

    # Redirect root to live.html for read-only access (preserve scheme)
    location = / {
        return 301 $redirect_scheme://$host:8082/live.html;
    }

    # Proxy all other requests to HamClock read-only (port 18082)
    location / {
        proxy_pass http://127.0.0.1:18082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/hamclock /etc/nginx/sites-enabled/hamclock

# Test and reload nginx
if nginx -t >/dev/null 2>&1; then
  $STD systemctl reload nginx
  msg_ok "Installed and Configured Nginx"
else
  msg_error "Nginx configuration test failed"
  exit 1
fi

#=============================================================================
# PHASE 8: Unattended Upgrades (Optional)
#=============================================================================
if [ "${UNATTENDED_UPDATES:-true}" = "true" ]; then
  msg_info "Configuring Automatic Security Updates"

  # Install unattended-upgrades package
  $STD apt-get install -y unattended-upgrades apt-listchanges

  # Configure unattended-upgrades
  cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename}-security";
        "origin=Debian,codename=${distro_codename}-updates";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

  # Enable automatic updates
  cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

  msg_ok "Configured Automatic Security Updates"
else
  msg_info "Skipping automatic security updates"
fi

#=============================================================================
# PHASE 9: Version Tracking
#=============================================================================
msg_info "Creating Version Information"

# Get container IP
CONTAINER_IP=$(hostname -I | awk '{print $1}')

# Build version info with conditional nginx section
VERSION_INFO="HamClock Installation Information
==================================
Installation Date: $(date)
Resolution: $RESOLUTION
Build Target: $BUILD_TARGET
Binary Location: /usr/local/bin/hamclock
Configuration: /root/.hamclock

Web Interface URLs:
  Full Access: http://$CONTAINER_IP/
  Read-Only:   http://$CONTAINER_IP:8082/

Service Management:
  HamClock:
    Status:  systemctl status hamclock
    Start:   systemctl start hamclock
    Stop:    systemctl stop hamclock
    Restart: systemctl restart hamclock
    Logs:    journalctl -u hamclock -f
  Nginx:
    Status:  systemctl status nginx
    Reload:  systemctl reload nginx
    Config:  /etc/nginx/sites-available/hamclock"

if [ "${UNATTENDED_UPDATES:-true}" = "true" ]; then
  VERSION_INFO="$VERSION_INFO
  Security Updates:
    Status:  Automatic updates enabled
    Config:  /etc/apt/apt.conf.d/50unattended-upgrades"
fi

VERSION_INFO="$VERSION_INFO

Documentation:
  HamClock Site: https://www.clearskyinstitute.com/ham/HamClock/
  Source Code:   https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz"

echo "$VERSION_INFO" > /opt/hamclock_version.txt

msg_ok "Created Version Information at /opt/hamclock_version.txt"

#=============================================================================
# PHASE 10: Cleanup
#=============================================================================
msg_info "Cleaning Up"
cd /tmp
rm -rf ESPHamClock ESPHamClock.tgz
$STD apt-get autoremove -y
$STD apt-get autoclean
msg_ok "Cleaned Up Temporary Files"

#=============================================================================
# PHASE 11: Finalization
#=============================================================================
motd_ssh
customize

msg_info "HamClock Installation Complete!"
echo ""
cat /opt/hamclock_version.txt
echo ""

msg_ok "Access HamClock at: http://$CONTAINER_IP/"

cleanup_lxc
