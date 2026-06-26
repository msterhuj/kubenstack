data "talos_image_factory_extensions_versions" "this" {
  # get the latest talos version
  talos_version = var.talos_version
  filters = {
    names = [
      "qemu-guest-agent",
      "iscsi-tools",
      "util-linux-tools",
      "netbird",
      "nfs-utils",
      "nfsd"
    ]
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info.*.name
        }
        bootloader = "sd-boot"
      }
    }
  )
}

resource "proxmox_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  file_name    = "talos-${var.talos_version}.iso"
  node_name    = var.image_node
  overwrite    = false
  url          = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
}

resource "proxmox_virtual_environment_vm" "talos_nodes" {
  for_each = local.vms

  depends_on = [proxmox_download_file.talos_iso]

  name            = "talos-${each.key}" # talos-ctrl-01, talos-worker-01
  node_name       = each.value.node
  started         = true
  bios            = "ovmf"
  boot_order      = ["scsi0", "ide3"]
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-pci"
  stop_on_destroy = true
  timeout_stop_vm = 15

  efi_disk {
    datastore_id = var.datastore
  }

  agent {
    enabled = false
  }

  memory {
    dedicated = 2048
    floating  = 0
  }

  rng {
    source = "/dev/urandom"
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES" # maybe try with host
  }

  operating_system {
    type = "l26"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  cdrom {
    file_id = proxmox_download_file.talos_iso.id
  }

  disk {
    datastore_id = var.datastore
    file_format  = "raw"
    interface    = "scsi0"
    size         = 25
    cache        = "writethrough"
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "${each.value.address}/24"
        gateway = var.gateway
      }
    }
    dns {
      servers = var.nameservers
    }
  }
}
