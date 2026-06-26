variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (any form: https://host:8006/ or .../api2/json). Normalized internally."
  type        = string
}

variable "region" {
  description = <<-EOT
    Logical Proxmox region. Becomes topology.kubernetes.io/region on every node and
    the `region` key in the cloud-config. The CSI must use the SAME region value.
  EOT
  type        = string
}

variable "chart_version" {
  description = "proxmox-cloud-controller-manager Helm chart (OCI) version."
  type        = string
  default     = "0.2.29"
}

variable "cni_ready" {
  description = "Token from cilium: CNI installed (pod networking + apiserver up). Gates the CCM release."
  type        = any
  default     = null
}
