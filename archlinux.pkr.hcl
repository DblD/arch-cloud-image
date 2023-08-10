packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "username" {
  type 	  = string
  default = "arch"
}

variable "password" {
  type    = string
  default = "admin"
}
variable "full_iso_url" {
  description = "Full URL to the ISO image"
  type        = string
}

variable "full_iso_checksum" {
  description = "Full URL to the ISO checksum"
  type        = string
}

source "qemu" "archlinux" {
  accelerator           = "kvm"
  disk_image            = true
  disk_interface        = "virtio"
  format                = "qcow2"
  http_directory        = "./http"
  iso_checksum          = "${var.full_iso_checksum}"
  iso_url               = "${var.full_iso_url}"
  net_device            = "virtio-net"
  shutdown_command      = "sudo systemctl poweroff"
  ssh_password          = "${var.password}"
  ssh_timeout           = "20m"
  ssh_username          = "${var.username}"
  vm_name               = "golden-arch.qcow2"
  cd_files              = ["cloud-init/meta-data", "cloud-init/user-data"]
  cd_label              = "cidata"
  boot_wait             = "30s"
  boot_command          = [
      "${var.username}<enter>arch<enter>",
      "arch<enter>${var.password}<enter>${var.password}<enter><wait>",
      "curl -sfSLO http://{{ .HTTPIP }}:{{ .HTTPPort }}/pkglist.txt<enter><wait>"
    ]
}

build {
  sources = ["source.qemu.archlinux"]

  provisioner "shell" {
    inline = [
        "echo '## South Africa' | sudo tee /etc/pacman.d/mirrorlist",
        "echo 'Server = https://archlinux.za.mirror.allworldit.com/archlinux/$repo/os/$arch' | sudo tee -a /etc/pacman.d/mirrorlist",
        "sudo pacman -Syu --noconfirm"
    ]
  }

  provisioner "shell" {
    inline = ["sudo pacman -Sy ansible --noconfirm"]
  }

  provisioner "ansible-local" {
    playbook_file = "./playbook.yml"
    extra_arguments = ["--extra-vars", "'username=${var.username}'"]
  }

  provisioner "shell" {
    inline = ["sudo usermod -p '!' ${var.username}"]
  }
}

