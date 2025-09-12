#!/bin/bash
set -e

# helper functions for colored output
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[✔]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[⚠]\033[0m $1"; }
error()   { echo -e "\033[1;31m[✖]\033[0m $1"; }

# check dependencies on proxmox host 
for cmd in whiptail pvesh pct pveam jq curl; do
    if ! command -v $cmd &> /dev/null; then
        warn "$cmd not found, installing..."
        apt-get update && apt-get install -y whiptail jq curl
    fi
done

# title banner
echo -e "\033[1;36m===================================\033[0m"
echo -e "\033[1;36m      CASAOS LXC INSTALLER         \033[0m"
echo -e "\033[1;36m===================================\033[0m"

# author banner
echo -e "\033[1;33m🚀 Created by: @Caleb Kibet\033[0m"
echo -e "\033[1;36m💻 GitHub: https://github.com/Caleb-ne1/proxmox-lxc-installer.git\033[0m"
echo ""

# select template storage
TEMPLATE_STORAGES=($(pvesh get /nodes/localhost/storage --output-format=json \
  | jq -r '.[] | select(.content | test("vztmpl")) | .storage'))

if [ ${#TEMPLATE_STORAGES[@]} -eq 0 ]; then
    error "No storage supports templates (vztmpl)."
    exit 1
fi

OPTIONS=()
for s in "${TEMPLATE_STORAGES[@]}"; do
    OPTIONS+=("$s" "" OFF)
done

TEMPLATE_STORAGE=$(whiptail --title "Select Template Storage" \
  --radiolist "Choose storage for LXC template (space to select):" 15 60 5 \
  "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    error "Cancelled."
    exit 1
fi
success "Template storage selected: $TEMPLATE_STORAGE"

# select container storage 
CT_STORAGES=($(pvesh get /nodes/localhost/storage --output-format=json \
  | jq -r '.[] | select(.content | test("rootdir")) | .storage'))

if [ ${#CT_STORAGES[@]} -eq 0 ]; then
    error "No storage supports container rootfs (rootdir)."
    exit 1
fi

OPTIONS=()
for s in "${CT_STORAGES[@]}"; do
    OPTIONS+=("$s" "" OFF)
done

CT_STORAGE=$(whiptail --title "Select Container Storage" \
  --radiolist "Choose storage for LXC container rootfs:" 15 60 5 \
  "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    error "Cancelled."
    exit 1
fi
success "Container storage selected: $CT_STORAGE"

# collect other variables
VMID=$(whiptail --inputbox "Enter VMID (must be unique)" 8 60 105 3>&1 1>&2 2>&3)
HOSTNAME=$(whiptail --inputbox "Enter Hostname" 8 60 casaos 3>&1 1>&2 2>&3)
PASSWORD=$(whiptail --passwordbox "Enter Root Password" 8 60 3>&1 1>&2 2>&3)
MEMORY=$(whiptail --inputbox "Enter Memory (MB)" 8 60 2048 3>&1 1>&2 2>&3)
CORES=$(whiptail --inputbox "Enter CPU Cores" 8 60 2 3>&1 1>&2 2>&3)
IP=$(whiptail --inputbox "Enter IP address (CIDR)" 8 60 X.X.X.X/24 3>&1 1>&2 2>&3)
GW=$(whiptail --inputbox "Enter Gateway" 8 60 X.X.X.X 3>&1 1>&2 2>&3)

# fixed rootfs size
DISK="10G"
DISK_NUMBER=10  # for lvmthin/lvm storage types

# confirm settings
whiptail --title "Confirm Settings" --yesno "Please confirm:\n
Template Storage: $TEMPLATE_STORAGE\n
Container Storage: $CT_STORAGE\n
VMID: $VMID\n
Hostname: $HOSTNAME\n
Memory: $MEMORY MB\n
Disk: $DISK\n
CPU Cores: $CORES\n
IP: $IP\n
Gateway: $GW\n
Continue?" 20 60

if [ $? -ne 0 ]; then
    error "Installation cancelled."
    exit 1
fi

# template setup and download if needed
info "Checking for Debian 12 template..."
TEMPLATE="debian-12-standard_12.12-1_amd64.tar.zst"
TEMPLATE_PATH="/var/lib/vz/template/cache/$TEMPLATE"

if [ ! -f "$TEMPLATE_PATH" ]; then
    info "Downloading Debian 12 template..."
    pveam update
    pveam download $TEMPLATE_STORAGE $TEMPLATE
fi
success "Template ready: $TEMPLATE"

# detect storage type for correct rootfs syntax 
STORAGE_TYPE=$(pvesh get /nodes/localhost/storage --output-format=json \
    | jq -r ".[] | select(.storage==\"$CT_STORAGE\") | .type")

if [ "$STORAGE_TYPE" = "lvmthin" ] || [ "$STORAGE_TYPE" = "lvm" ]; then
    ROOTFS_PARAM="$CT_STORAGE:$DISK_NUMBER"  # number only in GB
elif [ "$STORAGE_TYPE" = "btrfs" ]; then
    ROOTFS_PARAM="$CT_STORAGE:subvol=vm-$VMID-disk-0,size=$DISK"
elif [ "$STORAGE_TYPE" = "dir" ] || [ "$STORAGE_TYPE" = "nfs" ] || [ "$STORAGE_TYPE" = "cifs" ]; then
    ROOTFS_PARAM="$CT_STORAGE:$DISK"   # dir storage, include G, e.g., "8G"
elif [ "$STORAGE_TYPE" = "zfspool" ]; then
    ROOTFS_PARAM="$CT_STORAGE:size=$DISK"
else
    echo "Unsupported storage type: $STORAGE_TYPE"
    exit 1
fi

success "Storage type detected: $STORAGE_TYPE"

# create container 
info "Creating LXC container..."
pct create $VMID $TEMPLATE_PATH \
    --hostname $HOSTNAME \
    --rootfs $ROOTFS_PARAM \
    --memory $MEMORY \
    --cores $CORES \
    --net0 name=eth0,bridge=vmbr0,ip=$IP,gw=$GW \
    --password $PASSWORD \
    --features nesting=1,keyctl=1 \
    --unprivileged 0
success "Container $VMID created."

# start container 
info "Starting container..."
pct start $VMID
success "Container started."

# Install CasaOS dependencies and CasaOS itself
info "Installing CasaOS dependencies and CasaOS..."
pct exec $VMID -- bash -c "apt-get update && apt-get install -y curl wget git sudo && curl -fsSL https://get.casaos.io | sudo bash"
success "CasaOS installed."

# final message
whiptail --msgbox "CasaOS container created!\nHostname: $HOSTNAME\nVMID: $VMID\nIP: $IP\nRoot will auto-login at console." 12 60
echo -e "\033[1;32m[✔] CasaOS container setup complete.\033[0m"
echo -e "\033[1;34mAccess CasaOS at: http://$IP\033[0m"


