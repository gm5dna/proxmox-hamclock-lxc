#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

set -e

# Colors
BL='\033[0;34m'
GN='\033[0;32m'
YW='\033[1;33m'
RD='\033[0;31m'
CL='\033[0m'

msg_info() { echo -e "${BL}[INFO]${CL} $1"; }
msg_ok() { echo -e "${GN}[OK]${CL} $1"; }
msg_error() { echo -e "${RD}[ERROR]${CL} $1"; exit 1; }

# Default configuration
APP="HamClock"
var_cpu="1"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="12"
var_bridge="vmbr0"

# Get next available VMID
get_next_vmid() {
    local id=100
    while pct status $id &>/dev/null 2>&1; do
        ((id++))
    done
    echo $id
}

# Get user input
header_info() {
    clear
    echo -e "${GN}
 _   _                 ____ _            _
| | | | __ _ _ __ ___ / ___| | ___   ___| | __
| |_| |/ _\` | '_ \` _ \ |   | |/ _ \ / __| |/ /
|  _  | (_| | | | | | | |___| | (_) | (__|   <
|_| |_|\__,_|_| |_| |_|\____|_|\___/ \___|_|\_\\
${CL}"
    echo -e "${YW}HamClock LXC Container Setup${CL}"
    echo ""
}

variables() {
    # VMID
    SUGGESTED_VMID=$(get_next_vmid)
    read -p "Enter container ID (VMID) [$SUGGESTED_VMID]: " VMID
    VMID=$(echo "${VMID:-$SUGGESTED_VMID}" | xargs)

    # Check if exists
    if pct status $VMID &>/dev/null; then
        msg_error "Container $VMID already exists"
    fi

    # Hostname
    read -p "Enter hostname [hamclock]: " HOSTNAME
    HOSTNAME=$(echo "${HOSTNAME:-hamclock}" | xargs)

    # Resolution
    echo ""
    echo "Select resolution:"
    echo "  1) 800x480   - Small"
    echo "  2) 1600x960  - Recommended (default)"
    echo "  3) 2400x1440 - Large"
    echo "  4) 3200x1920 - Extra large"
    read -p "Choice [2]: " RES_CHOICE
    RES_CHOICE=${RES_CHOICE:-2}

    case $RES_CHOICE in
        1) RESOLUTION="800x480" ;;
        2) RESOLUTION="1600x960" ;;
        3) RESOLUTION="2400x1440" ;;
        4) RESOLUTION="3200x1920" ;;
        *) RESOLUTION="1600x960" ;;
    esac

    # Nginx
    echo ""
    read -p "Install nginx reverse proxy? (Y/n) [Y]: " INSTALL_NGINX
    INSTALL_NGINX=$(echo "${INSTALL_NGINX:-Y}" | xargs)
    [[ "$INSTALL_NGINX" =~ ^[Yy]$ ]] && INSTALL_NGINX="true" || INSTALL_NGINX="false"

    # Network
    echo ""
    read -p "Use DHCP? (Y/n) [Y]: " USE_DHCP
    USE_DHCP=$(echo "${USE_DHCP:-Y}" | xargs)

    if [[ ! "$USE_DHCP" =~ ^[Yy]$ ]]; then
        read -p "Static IP (e.g., 192.168.1.10/24): " STATIC_IP
        STATIC_IP=$(echo "$STATIC_IP" | xargs)

        # Validate CIDR notation
        if [[ ! "$STATIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            msg_error "Invalid IP format. Must include CIDR notation (e.g., 192.168.1.10/24)"
        fi

        read -p "Gateway (e.g., 192.168.1.1): " GATEWAY
        GATEWAY=$(echo "$GATEWAY" | xargs)

        read -p "VLAN tag (optional): " VLAN
        VLAN=$(echo "$VLAN" | xargs)

        NET_CONFIG="name=eth0,bridge=$var_bridge,ip=$STATIC_IP,gw=$GATEWAY"
        [[ -n "$VLAN" ]] && NET_CONFIG="$NET_CONFIG,tag=$VLAN"
    else
        NET_CONFIG="name=eth0,bridge=$var_bridge,ip=dhcp"
    fi
}

# Build container
build_container() {
    TEMPLATE="debian-12-standard_12.12-1_amd64.tar.zst"

    msg_info "Checking for Debian 12 template"
    if ! pveam list local | grep -q "$TEMPLATE"; then
        msg_info "Downloading Debian 12 template"
        pveam download local $TEMPLATE || msg_error "Failed to download template"
    fi
    msg_ok "Template ready"

    msg_info "Creating LXC container $VMID"
    pct create $VMID local:vztmpl/$TEMPLATE \
        --hostname $HOSTNAME \
        --memory $var_ram \
        --cores $var_cpu \
        --rootfs local-lvm:$var_disk \
        --net0 "$NET_CONFIG" \
        --unprivileged 1 \
        --nameserver 8.8.8.8 \
        --features nesting=1 \
        --onboot 1 \
        --start 1 || msg_error "Failed to create container"
    msg_ok "Container created"

    # Wait for start
    msg_info "Starting container"
    sleep 5
    for i in {1..30}; do
        pct status $VMID | grep -q "running" && break
        sleep 1
    done
    pct status $VMID | grep -q "running" || msg_error "Container failed to start"
    msg_ok "Container started"

    # Get IP
    sleep 3
    CONTAINER_IP=$(pct exec $VMID -- hostname -I | awk '{print $1}')
    [[ -z "$CONTAINER_IP" ]] && CONTAINER_IP="<pending>"

    # Install HamClock
    msg_info "Installing HamClock (5-10 minutes)"

    if ! pct exec $VMID -- bash -c "wget -qO /tmp/hamclock-install.sh https://raw.githubusercontent.com/GM5DNA/proxmox-hamclock-lxc/main/install/hamclock-install.sh && chmod +x /tmp/hamclock-install.sh"; then
        msg_error "Failed to download installation script"
    fi

    if ! pct exec $VMID -- bash -c "HAMCLOCK_RESOLUTION=$RESOLUTION INSTALL_NGINX=$INSTALL_NGINX DEBIAN_FRONTEND=noninteractive /tmp/hamclock-install.sh"; then
        msg_error "Installation failed - check logs: pct exec $VMID -- journalctl -xe"
    fi

    msg_ok "Installation complete"

    # Get final IP
    CONTAINER_IP=$(pct exec $VMID -- hostname -I | awk '{print $1}')
}

# Display completion message
description() {
    echo ""
    echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "${GN}  Installation Complete!${CL}"
    echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "  VMID:       ${YW}$VMID${CL}"
    echo -e "  Hostname:   ${YW}$HOSTNAME${CL}"
    echo -e "  IP Address: ${YW}$CONTAINER_IP${CL}"
    echo -e "  Resolution: ${YW}$RESOLUTION${CL}"
    echo ""

    if [[ "$INSTALL_NGINX" == "true" ]]; then
        echo -e "  Access:     ${BL}http://$CONTAINER_IP/${CL}"
        echo ""
        echo -e "  Direct:"
        echo -e "    Full:     ${BL}http://$CONTAINER_IP:8081/live.html${CL}"
        echo -e "    Read-only: ${BL}http://$CONTAINER_IP:8082/live.html${CL}"
    else
        echo -e "  Access:"
        echo -e "    Full:     ${BL}http://$CONTAINER_IP:8081/live.html${CL}"
        echo -e "    Read-only: ${BL}http://$CONTAINER_IP:8082/live.html${CL}"
    fi

    echo ""
    echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
}

# Main execution
header_info
variables
build_container
description

msg_ok "Setup complete! 73 de GM5DNA"
