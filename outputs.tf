output "talosconfig" {
  value     = module.talos_cluster.talos_config
  sensitive = true
}
