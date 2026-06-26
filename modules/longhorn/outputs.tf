output "ready" {
  description = "Token that resolves once the Longhorn Helm release is installed."
  value       = helm_release.this.id
}
