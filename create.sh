#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

# HamClock LXC Container Creation Script
# Run this on your Proxmox host to create a HamClock LXC container

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Default values
VMID=""
HOSTNAME="hamclock"
MEMORY=512
CORES=1
STORAGE="4"
BRIDGE="vmbr0"
NETWORK_TYPE="dhcp"
VLAN=""
STATIC_IP=""
GATEWAY=""

# Resolution options
declare -A RESOLUTIONS=(
    [1]="800x480"
    [2]="1600x960"
    [3]="2400x1440"
    [4]="3200x1920"
)

# Function to find next available VMID
get_next_vmid() {
    local next_id=100
    while pct status $next_id &>/dev/null; do
        next_id=$((next_id + 1))
    done
    echo $next_id
}

# Welcome message
clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         HamClock LXC Container Creation Script                ║"
echo "║                                                                ║"
echo "║  This script will create and configure a HamClock container   ║"
echo "║  on your Proxmox VE host.                                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Get VMID
if [ -z "$VMID" ]; then
    suggested_vmid=$(get_next_vmid)
    read -p "Enter container ID (VMID) [$suggested_vmid]: " input_vmid
    VMID=${input_vmid:-$suggested_vmid}
fi

# Check if VMID already exists
if pct status $VMID &>/dev/null; then
    msg_error "Container $VMID already exists!"
fi

# Get hostname
read -p "Enter hostname [$HOSTNAME]: " input_hostname
HOSTNAME=${input_hostname:-$HOSTNAME}

# Get resolution
echo ""
echo "Select display resolution:"
echo "  1) 800x480   - Small (compact displays)"
echo "  2) 1600x960  - Recommended (default)"
echo "  3) 2400x1440 - Large displays"
echo "  4) 3200x1920 - Extra large (4K displays)"
read -p "Enter choice [2]: " res_choice
res_choice=${res_choice:-2}
RESOLUTION=${RESOLUTIONS[$res_choice]:-"1600x960"}

# Ask about nginx
read -p "Install nginx reverse proxy? (Y/n) [Y]: " install_nginx
install_nginx=${install_nginx:-Y}
if [[ "$install_nginx" =~ ^[Yy]$ ]]; then
    INSTALL_NGINX="true"
else
    INSTALL_NGINX="false"
fi

# Network configuration
echo ""
read -p "Use DHCP for networking? (Y/n) [Y]: " use_dhcp
use_dhcp=${use_dhcp:-Y}

if [[ ! "$use_dhcp" =~ ^[Yy]$ ]]; then
    NETWORK_TYPE="static"
    read -p "Enter static IP address (e.g., 192.168.1.10/24): " STATIC_IP
    read -p "Enter gateway (e.g., 192.168.1.1): " GATEWAY
    read -p "Enter VLAN tag (leave empty for none): " VLAN
fi

# Advanced options
echo ""
read -p "Customize resources? (y/N) [N]: " customize_resources
if [[ "$customize_resources" =~ ^[Yy]$ ]]; then
    read -p "Memory (MB) [$MEMORY]: " input_memory
    MEMORY=${input_memory:-$MEMORY}

    read -p "CPU cores [$CORES]: " input_cores
    CORES=${input_cores:-$CORES}

    read -p "Storage (GB) [$STORAGE]: " input_storage
    STORAGE=${input_storage:-$STORAGE}
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Configuration Summary:"
echo "════════════════════════════════════════════════════════════════"
echo "  VMID:       $VMID"
echo "  Hostname:   $HOSTNAME"
echo "  Resolution: $RESOLUTION"
echo "  Nginx:      $INSTALL_NGINX"
echo "  Memory:     ${MEMORY}MB"
echo "  CPU Cores:  $CORES"
echo "  Storage:    ${STORAGE}GB"
echo "  Network:    $NETWORK_TYPE"
if [ "$NETWORK_TYPE" = "static" ]; then
    echo "  IP:         $STATIC_IP"
    echo "  Gateway:    $GATEWAY"
    [ -n "$VLAN" ] && echo "  VLAN:       $VLAN"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""
read -p "Proceed with installation? (Y/n) [Y]: " proceed
proceed=${proceed:-Y}
if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    msg_info "Installation cancelled"
    exit 0
fi

# Download Debian template if needed
msg_info "Checking for Debian 12 template"
TEMPLATE="debian-12-standard_12.12-1_amd64.tar.zst"
if ! pveam list local | grep -q "$TEMPLATE"; then
    msg_info "Downloading Debian 12 template"
    pveam download local $TEMPLATE || msg_error "Failed to download template"
fi
msg_ok "Template available"

# Build network configuration
NET_CONFIG="name=eth0,bridge=$BRIDGE"
if [ "$NETWORK_TYPE" = "dhcp" ]; then
    NET_CONFIG="$NET_CONFIG,ip=dhcp"
else
    NET_CONFIG="$NET_CONFIG,ip=$STATIC_IP,gw=$GATEWAY"
fi
[ -n "$VLAN" ] && NET_CONFIG="$NET_CONFIG,tag=$VLAN"

# Create container
msg_info "Creating LXC container $VMID"
pct create $VMID local:vztmpl/$TEMPLATE \
    --hostname $HOSTNAME \
    --memory $MEMORY \
    --cores $CORES \
    --rootfs local-lvm:$STORAGE \
    --net0 "$NET_CONFIG" \
    --unprivileged 1 \
    --nameserver 8.8.8.8 \
    --features nesting=1 \
    --onboot 1 \
    --start 1 || msg_error "Failed to create container"

msg_ok "Container created"

# Wait for container to start
msg_info "Waiting for container to start"
sleep 5
for i in {1..30}; do
    if pct status $VMID | grep -q "running"; then
        break
    fi
    sleep 1
done

if ! pct status $VMID | grep -q "running"; then
    msg_error "Container failed to start"
fi
msg_ok "Container started"

# Get container IP
msg_info "Waiting for network configuration"
sleep 3
CONTAINER_IP=$(pct exec $VMID -- hostname -I | awk '{print $1}')
if [ -z "$CONTAINER_IP" ]; then
    CONTAINER_IP="<check container IP>"
    msg_warn "Could not detect container IP automatically"
else
    msg_ok "Container IP: $CONTAINER_IP"
fi

# Download and run installation script
msg_info "Installing HamClock (this may take 5-10 minutes)"

# Download installation script into container
if ! pct exec $VMID -- bash -c "curl -fsSL https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/install/hamclock-install.sh -o /tmp/hamclock-install.sh && chmod +x /tmp/hamclock-install.sh"; then
    msg_error "Failed to download installation script"
fi

# Run installation in container
if ! pct exec $VMID -- bash -c "HAMCLOCK_RESOLUTION=$RESOLUTION INSTALL_NGINX=$INSTALL_NGINX DEBIAN_FRONTEND=noninteractive /tmp/hamclock-install.sh"; then
    msg_error "Installation failed - check container logs: pct exec $VMID -- journalctl -xe"
fi

msg_ok "HamClock installed successfully"

# Get final container IP (in case it changed)
CONTAINER_IP=$(pct exec $VMID -- hostname -I | awk '{print $1}')

# Final message
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Installation Complete!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Container Details:"
echo "  VMID:       $VMID"
echo "  Hostname:   $HOSTNAME"
echo "  IP Address: $CONTAINER_IP"
echo "  Resolution: $RESOLUTION"
echo ""
if [ "$INSTALL_NGINX" = "true" ]; then
    echo "Access HamClock:"
    echo "  http://$CONTAINER_IP/"
    echo ""
    echo "Direct access (optional):"
    echo "  Full:      http://$CONTAINER_IP:8081/live.html"
    echo "  Read-only: http://$CONTAINER_IP:8082/live.html"
else
    echo "Access HamClock:"
    echo "  Full:      http://$CONTAINER_IP:8081/live.html"
    echo "  Read-only: http://$CONTAINER_IP:8082/live.html"
fi
echo ""
echo "Container Management:"
echo "  Start:   pct start $VMID"
echo "  Stop:    pct stop $VMID"
echo "  Console: pct enter $VMID"
echo ""
echo "View installation details:"
echo "  pct exec $VMID -- cat /opt/hamclock_version.txt"
echo ""
msg_ok "Enjoy HamClock! 73 de GM5DNA"
