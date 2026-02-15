#!/bin/bash

# ==============================================================================
# Proxmox AI LXC Installer
# Author: Taha Echakiri (Netics)
# Description: Installs Ollama + Open WebUI in an LXC with Nvidia GPU Passthrough
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function info() { echo -e "${GREEN}[INFO] $1${NC}"; }
function warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
function error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Check if running on Proxmox
if [ ! -f "/etc/pve/local/pve-ssl.key" ]; then
    error "This script must be run on a Proxmox VE Host."
    exit 1
fi

info "Starting Proxmox AI LXC Installer..."

# 1. Configuration Wizard
read -p "Enter Container ID (e.g., 200): " CT_ID
read -p "Enter Container Name (default: ai-lab): " CT_NAME
CT_NAME=${CT_NAME:-ai-lab}
read -p "Enter Disk Size in GB (default: 20): " CT_DISK
CT_DISK=${CT_DISK:-20}
read -p "Enter RAM in MB (default: 8192): " CT_RAM
CT_RAM=${CT_RAM:-8192}
read -p "Enter Cores (default: 4): " CT_CORES
CT_CORES=${CT_CORES:-4}
read -p "Enter Bridge (default: vmbr0): " CT_BRIDGE
CT_BRIDGE=${CT_BRIDGE:-vmbr0}

# 2. Check for GPU on Host
info "Checking for Nvidia GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
    info "✅ Detected GPU: $GPU_NAME (Driver: $DRIVER_VER)"
    HAS_GPU=true
else
    warn "⚠️ No Nvidia GPU detected. Switching to CPU Mode."
    info "Ollama will run on CPU (slower but functional)."
    HAS_GPU=false
fi

# 3. Create LXC
info "Downloading Debian 12 Template..."
pveam update
pveam download local debian-12-standard_12.2-1_amd64.tar.zst || true

info "Creating Container $CT_ID ($CT_NAME)..."
pct create $CT_ID local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
    --hostname $CT_NAME \
    --features nesting=1,keyctl=1 \
    --memory $CT_RAM \
    --swap 512 \
    --cores $CT_CORES \
    --net0 name=eth0,bridge=$CT_BRIDGE,ip=dhcp \
    --rootfs local-lvm:${CT_DISK} \
    --unprivileged 0 \
    --start 1

# Wait for boot
info "Waiting for container to boot..."
sleep 10

# 4. Configure GPU Passthrough (if applicable)
if [ "$HAS_GPU" = true ]; then
    info "Configuring GPU Passthrough..."
    
    # Add cgroup config to LXC conf
    cat <<EOF >> /etc/pve/lxc/${CT_ID}.conf
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 237:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
EOF
    
    info "Installing Nvidia Drivers inside Container (Version matching host: $DRIVER_VER)..."
    pct exec $CT_ID -- bash -c "apt-get update && apt-get install -y build-essential dkms"
    pct exec $CT_ID -- bash -c "wget https://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VER}/NVIDIA-Linux-x86_64-${DRIVER_VER}.run"
    pct exec $CT_ID -- bash -c "chmod +x NVIDIA-Linux-x86_64-${DRIVER_VER}.run"
    pct exec $CT_ID -- bash -c "./NVIDIA-Linux-x86_64-${DRIVER_VER}.run --no-kernel-module --ui=none --no-questions --accept-license"
    
    # Restart to apply hooks
    pct stop $CT_ID
    pct start $CT_ID
    sleep 5
fi

# 5. Install Dependencies inside LXC
info "Installing Docker & Ollama inside Container..."
pct exec $CT_ID -- bash -c "apt-get update && apt-get install -y curl git"

# Install Docker
pct exec $CT_ID -- bash -c "curl -fsSL https://get.docker.com | sh"

# Install Ollama (Native, or via Docker - using Native for better GPU access usually, but Docker is fine too. Let's use Native for Ollama to leverage the mounted devices easily)
pct exec $CT_ID -- bash -c "curl -fsSL https://ollama.com/install.sh | sh"

# 6. Install Open WebUI (Docker)
info "Deploying Open WebUI..."
pct exec $CT_ID -- docker run -d -p 3000:8080 --gpus all --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

info "Installation Complete! 🎉"
info "Access Open WebUI at: http://$(pct exec $CT_ID -- hostname -I | awk '{print $1}'):3000"
