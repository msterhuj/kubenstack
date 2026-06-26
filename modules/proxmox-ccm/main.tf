# Proxmox Cloud Controller Manager: manages node lifecycle — sets each node's
# providerID (proxmox://<region>/<vmid>) and the well-known topology labels
# (region/zone), and clears the node.cloudprovider.kubernetes.io/uninitialized
# taint. The CSI (and any topology-aware scheduling) relies on these labels.
# Self-contained: owns its own least-privilege, read-only Proxmox credentials.

# ── Proxmox API credentials (read-only) ──────────────────────────────────────
# Dedicated user/token/role so a compromised CCM pod canNOT touch VMs (unlike the
# CSI token). NB: upstream docs also list VM.GuestAgent.Audit but that privilege
# only exists since PVE 8.3 — older clusters reject it; VM.Audit covers VM reads.
resource "proxmox_virtual_environment_role" "this" {
  role_id = "Kubernetes-CCM"
  privileges = [
    "VM.Audit",
    "Sys.Audit",
  ]
}

resource "proxmox_virtual_environment_user" "this" {
  comment = "Kubernetes CCM (read-only)"
  user_id = "kubernetes-ccm@pve"
}

resource "proxmox_user_token" "this" {
  comment    = "Kubernetes CCM"
  token_name = "ccm"
  user_id    = proxmox_virtual_environment_user.this.user_id
  # privsep off so the token inherits the user's ACL below. With privsep ON (the
  # default) effective perms = token ACL ∩ user ACL; the ACL is on the USER, so a
  # priv-separated token would see no VMs. Matches `pveum user token add ... -privsep 0`.
  privileges_separation = false
}

# ACL on the USER (not the token): with privsep off the token inherits it.
resource "proxmox_acl" "this" {
  user_id = proxmox_virtual_environment_user.this.user_id
  role_id = proxmox_virtual_environment_role.this.role_id

  path      = "/"
  propagate = true
}

locals {
  # bpg returns the token as "<user>@<realm>!<name>=<uuid>"; split into token_id and secret.
  token_id     = split("=", proxmox_user_token.this.value)[0]
  token_secret = split("=", proxmox_user_token.this.value)[1]

  # Normalize the bpg endpoint to the /api2/json form the CCM expects.
  api_url = "${trimsuffix(replace(var.proxmox_endpoint, "/api2/json", ""), "/")}/api2/json"
}

# Turn the cni_ready token into an apply-ordering edge.
resource "terraform_data" "cni_gate" {
  input = var.cni_ready
}

resource "helm_release" "this" {
  name      = "proxmox-cloud-controller-manager"
  chart     = "oci://ghcr.io/sergelogvinov/charts/proxmox-cloud-controller-manager"
  version   = var.chart_version
  namespace = "kube-system"

  # token_secret is sensitive → the whole values arg is marked sensitive, so the
  # secret is not rendered in the plan. The chart materializes the cloud-config Secret.
  values = [yamlencode({
    config = {
      clusters = [{
        url          = local.api_url
        insecure     = true # self-signed PVE cert (matches the proxmox provider)
        token_id     = local.token_id
        token_secret = local.token_secret
        region       = var.region
      }]
    }
  })]

  # Needs pod networking (Cilium). The CCM pod tolerates the uninitialized +
  # control-plane taints (chart defaults), so it schedules while nodes are tainted.
  depends_on = [terraform_data.cni_gate]
}
