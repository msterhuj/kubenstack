variable "talos_version" {
  default = "v1.13.5"
  type    = string
}

variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_username" {
  type    = string
  default = "root@pam"
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "csi_storage" {
  description = <<-EOT
    Proxmox storage where the CSI plugin provisions PV disks. Must be a storage
    with `images` content enabled and reachable on the nodes' Proxmox host(s).
    Defaults to the same ZFS pool used for the VM disks.
  EOT
  type        = string
  default     = "zfs"
}

variable "proxmox_region" {
  description = <<-EOT
    Logical region name for this Proxmox cluster. Becomes the value of the
    topology.kubernetes.io/region label that the Proxmox CCM applies to every
    node, and the `region` key in the CCM cloud-config (CSI cloud-config must
    use the same value). The zone label is derived per node from its Proxmox host.
  EOT
  type        = string
  default     = "stacking"
}
