# ── Layer 1: Proxmox VMs + Talos cluster (etcd bootstrap, admin kubeconfig) ──
module "talos_cluster" {
  source = "./modules/talos-cluster"

  talos_version = var.talos_version
  nodes         = local.talos
  # cluster_name / vip / gateway / nameservers keep their module defaults.
}

# ── Layer 2: Cilium CNI (in-cluster) ─────────────────────────────────────────
# depends_on the whole cluster module: this subsumes the old explicit
# `depends_on = [terraform_data.wait_for_apiserver]` — every cluster resource,
# including the apiserver wait, completes before any Cilium resource. It also
# pins the destroy order (Cilium uninstalled before the VMs are torn down).
module "cilium" {
  source = "./modules/cilium"

  providers = {
    helm    = helm.cluster
    kubectl = kubectl
  }

  depends_on = [module.talos_cluster]
}

# ── Layer 3: Traefik + Gateway API (in-cluster) ──────────────────────────────
# NB: ordering is threaded via tokens, NOT a module-level `depends_on`. A
# module-level depends_on would defer this module's data sources (the Gateway
# API CRD download/split) to apply, making the kubectl_manifest for_each keys
# unknown at plan ("Invalid for_each argument"). The tokens gate only the
# resources that truly need the API up / the CNI in:
#   - cluster_ready -> Gateway API CRD apply (apiserver serving)
#   - cni_ready     -> Traefik release (pods need pod networking)
module "traefik" {
  source = "./modules/traefik"

  providers = {
    helm    = helm.cluster
    kubectl = kubectl
  }

  cluster_ready = module.talos_cluster.apiserver_ready
  cni_ready     = module.cilium.ready
}
