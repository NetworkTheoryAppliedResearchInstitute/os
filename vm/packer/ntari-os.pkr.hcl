packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "ntari-os" {
  iso_url          = "../../build-output/ntari-os-1.0.0-x86_64.iso"
  iso_checksum     = "sha256:CHECKSUM_HERE"

  output_directory = "../../build-output/vm"
  vm_name          = "ntari-os-1.0.0"

  disk_size        = "4G"
  format           = "qcow2"

  memory           = 512
  cpus             = 1

  headless         = false

  ssh_username     = "root"
  ssh_password     = "ntari"
  ssh_timeout      = "20m"

  boot_wait        = "10s"
  boot_command     = [
    "root<enter><wait>",
    "setup-alpine<enter><wait>",
    "us<enter><wait>",
    "us<enter><wait>",
    "ntari-node<enter><wait>",
    "eth0<enter><wait>",
    "dhcp<enter><wait>",
    "<wait>n<enter>",
    "ntaripass<enter><wait>",
    "ntaripass<enter><wait>",
    "Africa/Abidjan<enter><wait>",
    "none<enter><wait>",
    "1<enter><wait>",
    "openssh<enter><wait>",
    "chronyd<enter><wait>",
    "sda<enter><wait>",
    "sys<enter><wait>",
    "y<enter><wait10>",
    "reboot<enter>"
  ]
}

build {
  sources = ["source.qemu.ntari-os"]

  provisioner "shell" {
    inline = [
      "apk update",
      "apk add soholink",
      "/usr/local/bin/setup-soholink.sh"
    ]
  }
}
