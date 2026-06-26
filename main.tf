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

# ── Layer 3: Proxmox CCM (in-cluster, node lifecycle + topology labels) ───────
# Self-contained: owns its read-only Proxmox credentials + the helm release.
# Its `ready` token gates everything that needs nodes initialized (taint cleared)
# or topology labels: Traefik, Proxmox CSI, Longhorn.
module "proxmox_ccm" {
  source = "./modules/proxmox-ccm"

  providers = {
    proxmox = proxmox
    helm    = helm.cluster
  }

  proxmox_endpoint = var.proxmox_endpoint
  region           = var.proxmox_region

  cni_ready = module.cilium.ready
}

# ── Layer 4: Traefik + Gateway API (in-cluster) ──────────────────────────────
# NB: ordering is threaded via tokens, NOT a module-level `depends_on`. A
# module-level depends_on would defer this module's data sources (the Gateway
# API CRD download/split) to apply, making the kubectl_manifest for_each keys
# unknown at plan ("Invalid for_each argument"). The tokens gate only the
# resources that truly need the API up / the CNI in / the nodes initialized:
#   - cluster_ready -> Gateway API CRD apply (apiserver serving)
#   - cni_ready     -> Traefik release (pods need pod networking)
#   - ccm_ready     -> Traefik release (pods don't tolerate the uninitialized taint)
module "traefik" {
  source = "./modules/traefik"

  providers = {
    helm    = helm.cluster
    kubectl = kubectl
  }

  cluster_ready = module.talos_cluster.apiserver_ready
  cni_ready     = module.cilium.ready
  ccm_ready     = module.proxmox_ccm.ready
}

# ── Layer 4: Proxmox CSI plugin (in-cluster storage, host-pinned) ─────────────
# Self-contained module: owns its Proxmox API credentials + the in-cluster
# deployment. Ordering via tokens: cni_ready (pod networking) and ccm_ready
# (topology labels for disk placement).
module "proxmox_csi" {
  source = "./modules/proxmox-csi"

  providers = {
    proxmox = proxmox
    helm    = helm.cluster
    kubectl = kubectl
  }

  proxmox_endpoint = var.proxmox_endpoint
  region           = var.proxmox_region
  storage          = var.csi_storage

  cni_ready = module.cilium.ready
  ccm_ready = module.proxmox_ccm.ready
}

# ── Layer 4: Longhorn (in-cluster storage, replicated/HA — DEFAULT SC) ────────
module "longhorn" {
  source = "./modules/longhorn"

  providers = {
    helm    = helm.cluster
    kubectl = kubectl
  }

  cni_ready = module.cilium.ready
  ccm_ready = module.proxmox_ccm.ready
}

# ── State migration: resources moved from the old root files into modules ─────
# Address changes only — NO destroy/recreate.

# proxmox-csi module (was pve-csi.tf)
moved {
  from = proxmox_virtual_environment_role.csi
  to   = module.proxmox_csi.proxmox_virtual_environment_role.this
}
moved {
  from = proxmox_virtual_environment_user.kubernetes
  to   = module.proxmox_csi.proxmox_virtual_environment_user.this
}
moved {
  from = proxmox_user_token.csi
  to   = module.proxmox_csi.proxmox_user_token.this
}
moved {
  from = proxmox_acl.csi
  to   = module.proxmox_csi.proxmox_acl.this
}
moved {
  from = kubectl_manifest.csi_namespace
  to   = module.proxmox_csi.kubectl_manifest.namespace
}
moved {
  from = helm_release.proxmox_csi
  to   = module.proxmox_csi.helm_release.this
}

# proxmox-ccm module (was ccm.tf)
moved {
  from = proxmox_virtual_environment_role.ccm
  to   = module.proxmox_ccm.proxmox_virtual_environment_role.this
}
moved {
  from = proxmox_virtual_environment_user.ccm
  to   = module.proxmox_ccm.proxmox_virtual_environment_user.this
}
moved {
  from = proxmox_user_token.ccm
  to   = module.proxmox_ccm.proxmox_user_token.this
}
moved {
  from = proxmox_acl.ccm
  to   = module.proxmox_ccm.proxmox_acl.this
}
moved {
  from = helm_release.proxmox_ccm
  to   = module.proxmox_ccm.helm_release.this
}

# longhorn module (was longhorn.tf)
moved {
  from = kubectl_manifest.longhorn_namespace
  to   = module.longhorn.kubectl_manifest.namespace
}
moved {
  from = helm_release.longhorn
  to   = module.longhorn.helm_release.this
}
