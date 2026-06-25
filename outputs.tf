# Generate the talosconfig (CA + client cert) from the state secrets
data "talos_client_configuration" "this" {
  cluster_name         = "talos"
  client_configuration = talos_machine_secrets.talos.client_configuration
  endpoints            = [for n in local.talos.control : n.address]
  nodes                = [for n in local.talos.control : n.address]
}

# Write the talosconfig directly to disk for debugging with talosctl
resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/talosconfig"
  file_permission = "0600"
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
