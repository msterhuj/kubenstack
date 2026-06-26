# Proxmox CSI plugin: provisions PersistentVolumes as Proxmox disks and attaches
# them to the VM the consuming pod lands on, placing each disk by the topology
# labels the CCM sets (region/zone). Self-contained: owns its own Proxmox API
# credentials (powerful — allocates/clones/migrates disks) plus the in-cluster
# deployment. Kept separate from the read-only CCM credentials.

# ── Proxmox API credentials ──────────────────────────────────────────────────
resource "proxmox_virtual_environment_role" "this" {
  role_id = "Kubernetes-CSI"
  privileges = [
    "VM.Audit",
    "VM.Allocate",
    "VM.Clone",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.PowerMgmt",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
  ]
}

resource "proxmox_virtual_environment_user" "this" {
  comment = "Kubernetes CSI"
  user_id = "kubernetes-csi@pve"
}

resource "proxmox_user_token" "this" {
  comment    = "Kubernetes CSI"
  token_name = "csi"
  user_id    = proxmox_virtual_environment_user.this.user_id
  # Privilege separation OFF: the token inherits the user's privileges. With it ON
  # (the default) the token's effective perms are the INTERSECTION of its own ACL
  # and the user's — and the ACL below is on the USER, so a priv-separated token
  # would see nothing. Matches upstream `pveum user token add ... -privsep 0`.
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
  # bpg returns the token as "<user>@<realm>!<name>=<uuid>"; the cloud-config wants
  # token_id ("<user>@<realm>!<name>") and token_secret (the uuid) split out.
  token_id     = split("=", proxmox_user_token.this.value)[0]
  token_secret = split("=", proxmox_user_token.this.value)[1]

  # Normalize the bpg endpoint to the /api2/json form the CSI expects.
  api_url = "${trimsuffix(replace(var.proxmox_endpoint, "/api2/json", ""), "/")}/api2/json"
}

# ── Ordering gates (turn the dependency tokens into apply-ordering edges) ─────
resource "terraform_data" "cni_gate" {
  input = var.cni_ready
}

resource "terraform_data" "ccm_gate" {
  input = var.ccm_ready
}

# ── In-cluster deployment ────────────────────────────────────────────────────
# Dedicated namespace. The node plugin DaemonSet mounts volumes on the host, so it
# needs privileged containers — Talos enforces Pod Security, hence the enforce
# label (kube-system is privileged by default; a fresh namespace is not).
resource "kubectl_manifest" "namespace" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "csi-proxmox"
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
      }
    }
  })
  server_side_apply = true

  # Needs the apiserver serving — guaranteed by the CNI being installed.
  depends_on = [terraform_data.cni_gate]
}

resource "helm_release" "this" {
  name      = "proxmox-csi-plugin"
  chart     = "oci://ghcr.io/sergelogvinov/charts/proxmox-csi-plugin"
  version   = var.chart_version
  namespace = "csi-proxmox"

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
    # The chart renders StorageClasses from this list. WaitForFirstConsumer so the
    # disk is created in the zone (Proxmox host) where the pod actually schedules.
    storageClass = [{
      name              = "proxmox"
      storage           = var.storage
      reclaimPolicy     = "Delete"
      fstype            = "ext4"
      volumeBindingMode = "WaitForFirstConsumer"
      # allowVolumeExpansion defaults true in the chart.
    }]
  })]

  # Needs pod networking (Cilium) and CCM-set topology labels for placement; the
  # node plugin schedules on CCM-initialized nodes. Namespace must exist first.
  depends_on = [
    kubectl_manifest.namespace,
    terraform_data.ccm_gate,
  ]
}
