output "ready" {
  description = <<-EOT
    Token that resolves once the CCM Helm release is installed. Thread into the
    `ccm_ready` of workloads that must wait for nodes to be initialized (taint
    cleared) / carry topology labels (Traefik, Proxmox CSI, Longhorn).
  EOT
  value       = helm_release.this.id
}
