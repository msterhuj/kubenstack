variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (any form: https://host:8006/ or .../api2/json). Normalized internally."
  type        = string
}

variable "region" {
  description = <<-EOT
    Proxmox region for the CSI cloud-config. Must match the topology.kubernetes.io/region
    label the CCM applies to the nodes, so the CSI places disks in the right region.
  EOT
  type        = string
}

variable "storage" {
  description = "Proxmox storage where the CSI provisions PV disks (must have `images` content)."
  type        = string
  default     = "zfs"
}

variable "chart_version" {
  description = "proxmox-csi-plugin Helm chart (OCI) version."
  type        = string
  default     = "0.5.9"
}

# Dependency tokens (see the cilium/traefik modules): carry ORDERING across the
# module boundary without a module-level depends_on.
variable "cni_ready" {
  description = "Token from cilium: CNI installed (pod networking + apiserver up). Gates the namespace/release."
  type        = any
  default     = null
}

variable "ccm_ready" {
  description = "Token from the Proxmox CCM: nodes carry topology labels + are initialized. Gates the CSI release."
  type        = any
  default     = null
}
