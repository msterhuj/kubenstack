# Generate the talosconfig (CA + client cert) from the state secrets
data "talos_client_configuration" "this" {
  cluster_name         = "talos"
  client_configuration = talos_machine_secrets.talos.client_configuration
  endpoints            = [for n in local.control : n.address]
  nodes                = [for n in local.control : n.address]
}

# Write the talosconfig to the repo root for debugging with talosctl.
# path.root (not path.module) so the file stays at the project root even though
# this resource now lives inside the module.
resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.root}/talosconfig"
  file_permission = "0600"
}
