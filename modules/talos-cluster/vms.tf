data "talos_image_factory_extensions_versions" "this" {
  # get the latest talos version
  talos_version = var.talos_version
  filters = {
    names = [
      "qemu-guest-agent",
      "iscsi-tools",
      "util-linux-tools",
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

# The ISO datastore ("local") is node-local, NOT shared — so a VM can only boot an
# ISO present on ITS OWN Proxmox host. Download the image once per distinct host the
# topology places VMs on; each VM references the copy on its own node (cdrom below).
resource "proxmox_download_file" "talos_iso" {
  for_each = toset([for v in local.vms : v.node])

  content_type = "iso"
  datastore_id = "local"
  file_name    = "talos-${var.talos_version}.iso"
  node_name    = each.value
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
  timeout_stop_vm = 60 # 15s was too short — qmstop timed out on destroy, leaving VMs behind

  efi_disk {
    datastore_id = var.datastore
  }

  # QEMU guest agent: lets Proxmox read the VM's IP, do graceful shutdown, and
  # fs-freeze. The qemu-guest-agent extension is baked into the node image
  # (schematic above), so the agent actually runs inside Talos.
  agent {
    enabled = true
  }

  memory {
    # Workers are sized for Longhorn + workloads; control planes stay small.
    dedicated = each.value.role == "worker" ? var.worker_memory : var.control_memory
    floating  = 0
  }

  rng {
    source = "/dev/urandom"
  }

  cpu {
    cores = each.value.role == "worker" ? var.worker_cores : var.control_cores
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
    # ISO copy on THIS VM's own Proxmox host (local datastore is not shared).
    file_id = proxmox_download_file.talos_iso[each.value.node].id
  }

  # OS / Talos system disk (→ /dev/sda; machine.install.disk pins the install here).
  disk {
    datastore_id = var.datastore
    file_format  = "raw"
    interface    = "scsi0"
    size         = 25
    cache        = "writethrough"
  }

  # Dedicated Longhorn data disk on workers only (→ /dev/sdb, mounted at
  # /var/lib/longhorn by the worker machine config). Control planes get none.
  dynamic "disk" {
    for_each = each.value.role == "worker" ? [1] : []
    content {
      datastore_id = var.datastore
      file_format  = "raw"
      interface    = "scsi1"
      size         = var.longhorn_disk_size
      cache        = "writethrough"
    }
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
