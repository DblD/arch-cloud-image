#!/bin/bash

# Enable error handling
set -e

# Display usage message
usage() {
    echo "Usage: $0 <SSH_USER> <PROXMOX_HOST> <VM_USER> <SSH_KEY_PATH>"
    echo "SSH_USER:      Username to SSH into the Proxmox host."
    echo "PROXMOX_HOST:  IP address or hostname of the Proxmox host."
    echo "VM_USER:       Default username for the VM."
    echo "SSH_KEY_PATH:  Path to the SSH public key for passwordless access to the VM."
    exit 1
}

# Check for correct number of arguments
if [ "$#" -ne 4 ]; then
    usage
fi

# Test SSH connection
echo "Testing SSH connection to $2..."
ssh -q -o BatchMode=yes $1@$2 exit
if [ $? != "0" ]; then
    echo "SSH connection failed!"
    exit 1
fi
echo "SSH connection successful."

# Copy files to Proxmox host
echo "Copying files to Proxmox host..."
ssh -q -o BatchMode=yes $1@$2 "mkdir -p packer-template"
scp output-archlinux/golden-arch.qcow2 $1@$2:packer-template/
scp $4 $1@$2:packer-template/
basename=`basename $4`

# Create and configure VM on Proxmox host
echo "Creating and configuring VM on Proxmox host..."
ssh -T $1@$2 /bin/bash <<ENDSSH
    echo "Destroying existing VM with ID 9000..."
    qm destroy 9000 || echo "No existing VM with ID 9000 found."
    sleep 3
    echo "Creating new VM with ID 9000..."
    qm create 9000 --memory 2048 --net0 virtio,bridge=vmbr0 --agent 1
    qm importdisk 9000 packer-template/golden-arch.qcow2 local-lvm
    qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0,cache=writeback,discard=on
    qm set 9000 --ide2 local-lvm:cloudinit
    qm set 9000 --boot c --bootdisk scsi0
    qm set 9000 --ciuser $3 --citype nocloud --ipconfig0 ip=dhcp
    qm set 9000 --sshkeys 'packer-template/$basename'
    qm set 9000 --name arch-golden --template 1
    echo "VM creation and configuration complete."
ENDSSH

echo "Script execution completed successfully."
