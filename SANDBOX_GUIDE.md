# 🧪 Safe Sandbox Testing Guide

Running scripts on your main Proxmox node can be scary. The best way to test `proxmox-ai-lxc` without risking your production setup is by using **Nested Virtualization**.

This allows you to run a **Proxmox VM inside your Proxmox Host**, effectively giving you a "throwaway" lab.

---

## 🏗️ Step 1: Create the Nested VM

1.  **Download Proxmox ISO**: Get the latest Proxmox VE ISO on your main host.
2.  **Create a VM**:
    *   **OS**: Linux.
    *   **CPU**: **CRITICAL** — Set Type to **`Host`**. This enables nested virtualization instructions to pass through.
    *   **RAM**: Give it at least 8GB (for AI testing).
    *   **Disk**: 16GB, 32 is recommended.
    *   **Network**: Bridged (vmbr0).

## ⚙️ Step 2: Enable "MacVTap" (Optional) or Promiscuous Mode
If your nested Proxmox containers can't reach the internet, you might need to enable "Promiscuous Mode" on your main host's bridge, or just use standard bridging. Usually, standard bridging works fine.

## 🚀 Step 3: Install Proxmox
Boot the VM and install Proxmox as usual.

## 🧪 Step 4: Run the Script in the Sandbox
1.  Access the **Nested Proxmox Web UI** (it will get an IP from your main network).
2.  Open the Shell.
3.  Run the `proxmox-ai-lxc` install command:
    ```bash
    bash <(curl -s https://raw.githubusercontent.com/tahaex/proxmox-ai-lxc/main/install.sh)
    ```
4.  **Result**: If it creates the container and installs Ollama, the script works!
    *   *Note*: GPU Passthrough might not work in a nested VM unless you do "Nested GPU Passthrough" which is very advanced. But you can test the **LXC creation, dependency installation, and web UI setup** perfectly fine here.

---

## 🧹 Cleanup
Done testing? Just **Stop and Remove** the Nested VM. Your main host remains untouched.
