# Longhorn: distributed, replicated block storage (the cluster-default StorageClass).
# Volumes follow a pod to any node → HA + clean node decommission, which the
# host-pinned Proxmox CSI cannot. Runs on the workers (storage nodes): each has a
# dedicated disk mounted at /var/lib/longhorn (see the talos-cluster module), and
# the kubelet extraMount exposes it. Control planes keep the taint, so Longhorn
# places no replicas there. Node-image prereqs (iscsi-tools, util-linux-tools,
# nfs-utils/nfsd for RWX) are baked into the schematic.

# Turn the dependency tokens into apply-ordering edges.
resource "terraform_data" "cni_gate" {
  input = var.cni_ready
}

resource "terraform_data" "ccm_gate" {
  input = var.ccm_ready
}

# Dedicated namespace with privileged Pod Security: Longhorn's manager/engine run
# privileged containers (host devices, iSCSI, mounts).
resource "kubectl_manifest" "namespace" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "longhorn-system"
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
      }
    }
  })
  server_side_apply = true

  depends_on = [terraform_data.cni_gate]
}

resource "helm_release" "this" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = var.chart_version
  namespace  = "longhorn-system"

  values = [yamlencode({
    persistence = {
      defaultClass             = var.default_class
      defaultClassReplicaCount = var.replica_count
    }
    defaultSettings = {
      # Data lives on the dedicated per-worker disk mounted here.
      defaultDataPath     = "/var/lib/longhorn"
      defaultReplicaCount = var.replica_count
      # No explicit storage-node tagging needed: the control-plane taint keeps
      # Longhorn off the masters, so the only schedulable nodes are the workers,
      # which all have /var/lib/longhorn backed by the dedicated disk.
    }
  })]

  # Needs pod networking (Cilium) and CCM-initialized nodes (taint cleared) so the
  # manager DaemonSet/engine pods can schedule on the workers. Namespace first.
  depends_on = [
    kubectl_manifest.namespace,
    terraform_data.ccm_gate,
  ]
}
