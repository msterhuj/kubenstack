variable "talos_version" {
  description = "Talos Linux version used for the image factory and machine secrets."
  type        = string
}

variable "cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
  default     = "stacking"
}

variable "vip" {
  description = "Management VIP shared across the control planes (Talos Layer2VIPConfig, etcd-elected)."
  type        = string
  default     = "192.168.3.150"
}

variable "vip_link" {
  description = "Link name the VIP binds to. On these virtio VMs the stable interface is ens18 (NOT eth0)."
  type        = string
  default     = "ens18"
}

variable "gateway" {
  description = "Default gateway for the node network."
  type        = string
  default     = "192.168.3.1"
}

variable "nameservers" {
  description = "DNS servers pushed to every machine."
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

variable "nodes" {
  description = <<-EOT
    Cluster topology. Each node has the Proxmox host it runs on and the static
    IP assigned by cloud-init (ip_config) — also the Talos apply target.
  EOT
  type = object({
    control = map(object({
      node    = string
      address = string
    }))
    worker = map(object({
      node    = string
      address = string
    }))
  })
}

variable "image_node" {
  description = "Proxmox node onto which the Talos ISO is downloaded."
  type        = string
  default     = "ctrl-3"
}

variable "network_bridge" {
  description = "Proxmox bridge the VM NIC attaches to."
  type        = string
  default     = "vmbr3"
}

variable "datastore" {
  description = "Proxmox datastore for VM disks / EFI / cloud-init."
  type        = string
  default     = "zfs"
}
