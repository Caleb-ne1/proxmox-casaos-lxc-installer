# Proxmox LXC Installer for CasaOS

🚀 Automate the creation of a CasaOS LXC container on Proxmox with ease.

---

## Requirements

- Proxmox VE 7.x or newer  
- Root access to Proxmox host  
- Internet connection for downloading templates and CasaOS  

---

## Usage

### Option 1: Clone and run

```bash
git clone https://github.com/Caleb-ne1/proxmox-lxc-installer.git
cd proxmox-casaos-lxc-installer
bash casaos-installer.sh
```

### Option 2: One-liner installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Caleb-ne1/proxmox-casaos-lxc-installer/main/install.sh)"
```

This will download and run the installer script.

---

## How It Works

1. Detects available Proxmox storage for templates and container rootfs.  
2. Prompts user to select template and container storage using a simple interactive menu.  
3. Downloads the Debian 12 template if it doesn't exist.  
4. Creates the LXC container with configured resources (memory, CPU, disk, network).  
5. Installs CasaOS and required dependencies inside the container.  

> ⚠️ **Note:** Root autologin is **not enabled by default** for security reasons. Access CasaOS via the container's IP address.

---

## Author

- 👤 **Caleb Kibet**  
- 💻 [GitHub](https://github.com/Caleb-ne1)  
- 📌 Created for automating CasaOS deployment on Proxmox  

---
