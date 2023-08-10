# Load configurations from config.ini
-include config.ini

MIRROR_URL ?= https://archlinux.za.mirror.allworldit.com
MIRROR_IMAGE_PATH ?= /archlinux/images/latest/
IMAGE_NAME ?= Arch-Linux-x86_64-cloudimg.qcow2
USERNAME ?= arch
PASSWORD ?= admin

FULL_ISO_URL=$(MIRROR_URL)$(MIRROR_IMAGE_PATH)$(IMAGE_NAME)
FULL_ISO_CHECKSUM=$(shell awk '{print $$1}' scripts/Arch-Linux-x86_64-cloudimg.qcow2.SHA256)


# Default values for Proxmox SSH
PROXMOX_SSH_USER ?= root
PROXMOX_SSH_HOST ?= 192.168.1.62
PROXMOX_SSH_KEY_PATH ?= /path/to/default/proxmox/ssh/key

# Default values for VM cloud-init
VM_USER ?= arch
VM_SSH_KEY_PATH ?= /path/to/default/vm/ssh/key

all: modify-user-data build restore-user-data

modify-user-data:
	@cp cloud-init/user-data cloud-init/user-data.backup
	@sed -i -E "s/(hostname: ).*/\1$(USERNAME)/" cloud-init/user-data
	@sed -i -E "s/(user: ).*/\1$(USERNAME)/" cloud-init/user-data
	@sed -i -E "s/(\s+- ).*:/\1$(USERNAME):/" cloud-init/user-data

build:
	@echo 'iso url' + $(FULL_ISO_URL)
	@echo 'iso url' + $(FULL_ISO_CHECKSUM)
	@packer build \
	-var 'username=$(USERNAME)' \
	-var 'password=$(PASSWORD)' \
	-var 'full_iso_url=$(FULL_ISO_URL)' \
	-var 'full_iso_checksum=$(FULL_ISO_CHECKSUM)' \
	archlinux.pkr.hcl
	@echo "Successfully created golden arch image."

restore-user-data:
	@mv cloud-init/user-data.backup cloud-init/user-data

deploy:
	@echo "Deploying the VM template to Proxmox..."
	@./scripts/proxmox.sh $(PROXMOX_SSH_USER) $(PROXMOX_SSH_HOST) $(VM_USER) $(VM_SSH_KEY_PATH)
	@echo "Deployment completed."

.PHONY: all modify-user-data build restore-user-data deploy
