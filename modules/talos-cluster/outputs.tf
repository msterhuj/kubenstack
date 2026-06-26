# Admin kubeconfig pieces consumed by the root helm/kubectl provider blocks.
# Values are base64-encoded PEM — callers base64decode() them.
output "kube_host" {
  description = "kube-apiserver endpoint (the management VIP)."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
}

output "kube_client_certificate" {
  value     = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
  sensitive = true
}

output "kube_client_key" {
  value     = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
  sensitive = true
}

output "kube_ca_certificate" {
  value     = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
  sensitive = true
}

output "talos_config" {
  description = "Rendered talosconfig (talosctl client config)."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

# Opaque dependency token: becomes known only once the kube-apiserver is
# actually serving (terraform_data.wait_for_apiserver). Workload modules thread
# this into the `depends_on` of the resources that need the API up — WITHOUT
# gating the whole module (a module-level depends_on would also defer the
# workloads' data sources to apply, breaking for_each over their results).
output "apiserver_ready" {
  description = "Token that resolves once the kube-apiserver is serving."
  value       = terraform_data.wait_for_apiserver.id
}

# Statically-known cluster endpoint (the management VIP). Unlike the kubeconfig
# host (only known after talos_cluster_kubeconfig is created), this is derived
# from var.vip and is therefore known at PLAN time — so the kubectl/helm provider
# `host` is never empty during a from-scratch apply. The alekc/kubectl provider
# validates its config eagerly at plan and rejects an empty host; a known host
# keeps it happy while the certs (still computed) are filled in at apply.
output "cluster_endpoint" {
  description = "https://<vip>:6443 — known at plan time."
  value       = "https://${var.vip}:6443"
}
