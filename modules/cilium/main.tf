locals {
  # LAN load balancer config: LoadBalancer Services draw IPs from the pool and
  # Cilium answers ARP for them via L2 announcements. Applied AFTER the chart
  # because their CRDs ship with Cilium.
  lb_manifest_objects = [
    # Load balancer to expose services on the LAN
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumL2AnnouncementPolicy"
      metadata = {
        name = "external"
      }
      spec = {
        loadBalancerIPs = true
        interfaces      = var.lb_interfaces
        # Only workers can announce the IPs (not the control planes)
        nodeSelector = {
          matchExpressions = [
            {
              key      = "node-role.kubernetes.io/control-plane"
              operator = "DoesNotExist"
            }
          ]
        }
      }
    },
    # Pool of IPs available for the load balancer
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumLoadBalancerIPPool"
      metadata = {
        name = "external"
      }
      spec = {
        blocks = var.lb_ip_blocks
      }
    }
  ]
}

# Cilium CNI, installed as a day-2-manageable Helm release.
#
# Previously Cilium was rendered locally (data.helm_template) and injected into
# the Talos control-plane inlineManifests. That applies ONLY once at bootstrap
# and never reconciles, so value/version changes silently drifted. As a
# helm_release, `terraform apply` now reconciles upgrades and value changes.
#
# Bootstrap ordering — there is NO chicken-and-egg here:
#   - The API server endpoint (the management VIP) is a Talos Layer2VIPConfig,
#     held at the host level via etcd election — reachable WITHOUT a CNI.
#     It is the same endpoint the helm provider connects to.
#   - cilium-agent (DaemonSet) and cilium-operator both run hostNetwork: true,
#     so they schedule and run before the pod network exists.
#   - The talos-cluster module gates on control-plane health only, so it passes
#     while nodes are still NotReady (no CNI yet) — exactly the window in which
#     we install Cilium.
#
# The module-level `depends_on` from the root ensures the apiserver is actually
# serving (talos-cluster's wait_for_apiserver) before this applies, otherwise
# the first apply races it: "connection refused".
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.chart_version
  namespace  = "kube-system"

  values = [file("${path.module}/helm/cilium-values.yaml")]
}

resource "kubectl_manifest" "this" {
  for_each = { for d in local.lb_manifest_objects : "${d.kind}/${d.metadata.name}" => d }

  yaml_body         = yamlencode(each.value)
  server_side_apply = true

  depends_on = [helm_release.cilium]
}
