# Proxmox AI LXC

<div align="center">

![Proxmox](https://img.shields.io/badge/Proxmox_VE-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![LXC](https://img.shields.io/badge/LXC-333333?style=for-the-badge&logo=linux&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-000000?style=for-the-badge&logoColor=white)
![Nvidia](https://img.shields.io/badge/Nvidia_GPU-76B900?style=for-the-badge&logo=nvidia&logoColor=white)

**One-Click Local AI Stack for Proxmox**

Turn your Proxmox node into a private AI server.
Automates LXC creation, Nvidia GPU passthrough, and Ollama installation.

[Report Bug](https://github.com/tahaex/proxmox-ai-lxc/issues) · [Request Feature](https://github.com/tahaex/proxmox-ai-lxc/issues)

</div>

---

## Overview

Running Local LLMs (Large Language Models) like Llama 3 or Mistral on Proxmox typically requires:
1.  Complex LXC configuration for GPU access.
2.  Manual driver installation on both host and container.
3.  Setting up Ollama and Web UIs manually.

This project provides a single Bash script to automate the entire process using the **Shared Driver** method for near-native performance.

## Features

*   **Automated LXC Creation**: Deploys a lightweight Debian 12 container.
*   **GPU Passthrough**: Automatically detects Nvidia GPUs on the host and configures cgroups/drivers.
*   **CPU Mode**: No GPU? No problem. Automatically falls back to CPU inference.
*   **AI Stack**: Installs Ollama as a system service.
*   **Web UI**: Deploys Open WebUI via Docker inside the LXC.

---

## Installation

Run this command in your **Proxmox Host Shell**:

```bash
bash <(curl -s https://raw.githubusercontent.com/tahaex/proxmox-ai-lxc/main/install.sh)
```

### What happens next?
1.  The script asks for basic container settings (ID, Name, IP).
2.  It downloads the minimal Debian 12 template.
3.  It creates a **Privileged Container** (necessary for direct hardware access).
4.  It identifies your GPU driver version and installs the **exact matching version** inside the container.
5.  It configures Ollama and Open WebUI.
6.  You get a dashboard URL: `http://<container-ip>:3000`.

---

## How It Works (Technical Details)

To achieve GPU acceleration in an LXC container without the overhead of a full VM, this script uses the **Shared Driver Method**:

1.  **Driver Matching**: The Nvidia driver kernel modules are loaded by the Proxmox Host. For the container to communicate with the GPU, it must have the *exact same* user-space driver libraries installed. The script detects the host version (e.g., `535.183.01`) and installs that specific runfile inside the LXC.
2.  **Device Passthrough**: We modify the LXC configuration (`/etc/pve/lxc/CTID.conf`) to allow access to specific character devices:
    *   `/dev/nvidia0` (The GPU itself)
    *   `/dev/nvidiactl` (Control device)
    *   `/dev/nvidia-uvm` (Unified Memory)
3.  **Cgroups**: We add `lxc.cgroup2.devices.allow` rules to permit the container to read/write to these devices.

This approach offers **near-metal performance** with almost zero virtualization penalty.

---

## Testing

**⚠️ Do not run this on a production node without testing first.**

We recommend testing in a **Nested Proxmox VM** (Sandbox).
See [SANDBOX_GUIDE.md](SANDBOX_GUIDE.md) for a step-by-step tutorial on setting up a safe testing environment.

---

## Requirements

*   **Proxmox VE 8.x**
*   **Nvidia GPU** (Maxwell architecture or newer)
*   **Nvidia Drivers** installed on the Proxmox Host (`apt install pve-headers nvidia-driver`)
*   **16GB+ RAM** recommended for running 7B+ parameter models

---

## License

Distributed under the MIT License.

---

<div align="center">
  Built by <a href="https://github.com/tahaex">Taha Echakiri</a> (Netics)
</div>
