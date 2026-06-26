variable "chart_version" {
  description = "Longhorn Helm chart version."
  type        = string
  default     = "1.11.2"
}

variable "replica_count" {
  description = <<-EOT
    Default Longhorn replica count per volume. Longhorn places one replica per
    node, so this must be <= number of worker (storage) nodes. 3 workers → 3.
  EOT
  type        = number
  default     = 3
}

variable "default_class" {
  description = "Make Longhorn's StorageClass the cluster default."
  type        = bool
  default     = true
}

# Dependency tokens (carry ORDERING across the module boundary).
variable "cni_ready" {
  description = "Token from cilium: CNI installed. Gates the namespace/release."
  type        = any
  default     = null
}

variable "ccm_ready" {
  description = "Token from the Proxmox CCM: nodes initialized (uninitialized taint cleared). Gates the release."
  type        = any
  default     = null
}
