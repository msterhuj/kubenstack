output "storage_class" {
  description = "Name of the StorageClass the CSI plugin creates."
  value       = "proxmox"
}

output "ready" {
  description = "Token that resolves once the CSI Helm release is installed."
  value       = helm_release.this.id
}
