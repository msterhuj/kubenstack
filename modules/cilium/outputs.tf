# Opaque dependency token: known once the Cilium CNI is installed. Threaded into
# the Traefik release's depends_on so Traefik pods only start once pod networking
# exists — without gating the whole traefik module (see talos-cluster outputs).
output "ready" {
  description = "Token that resolves once the Cilium Helm release is installed."
  value       = helm_release.cilium.id
}
