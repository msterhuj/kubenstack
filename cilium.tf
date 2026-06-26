# Cilium CNI, installed as a day-2-manageable Helm release.
#
# Previously Cilium was rendered locally (data.helm_template) and injected into
# the Talos control-plane inlineManifests. That applies ONLY once at bootstrap
# and never reconciles, so value/version changes silently drifted. As a
# helm_release, `terraform apply` now reconciles upgrades and value changes.
#
# Bootstrap ordering — there is NO chicken-and-egg here:
#   - The API server endpoint (VIP 192.168.3.150) is a Talos Layer2VIPConfig,
#     held at the host level via etcd election — reachable WITHOUT a CNI
#     (see talos.tf). It is the same endpoint the helm provider connects to.
#   - cilium-agent (DaemonSet) and cilium-operator both run hostNetwork: true,
#     so they schedule and run before the pod network exists.
#   - data.talos_cluster_health.this gates on control-plane health only
#     (skip_kubernetes_checks = true), so it passes while nodes are still
#     NotReady (no CNI yet) — exactly the window in which we install Cilium.
resource "helm_release" "cilium" {
  provider = helm.cluster

  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.19.5"
  namespace  = "kube-system"

  values = [file("${path.module}/helm/cilium-values.yaml")]

  # Wait until the apiserver actually answers on the VIP (not just Talos health),
  # otherwise the first apply races it: "connection refused". See talos.tf.
  depends_on = [terraform_data.wait_for_apiserver]
}

# LAN load balancer config: LoadBalancer Services draw IPs from the pool and
# Cilium answers ARP for them via L2 announcements (CiliumL2AnnouncementPolicy +
# CiliumLoadBalancerIPPool, defined in locals.tf). Applied AFTER the chart
# because their CRDs ship with Cilium.
resource "kubectl_manifest" "cilium_lb" {
  for_each = { for d in local.cilium_manifest_objects : "${d.kind}/${d.metadata.name}" => d }

  yaml_body         = yamlencode(each.value)
  server_side_apply = true

  depends_on = [helm_release.cilium]
}
