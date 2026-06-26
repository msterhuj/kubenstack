# Traefik + Kubernetes Gateway API, installed as code.
# Based on the Sidero Labs guide:
# https://docs.siderolabs.com/kubernetes-guides/advanced-guides/deploy-traefik
#
#   1. Apply the Gateway API CRDs (standard channel) — NOT shipped by the chart.
#   2. Install Traefik via Helm with the kubernetesGateway provider enabled.
#
# The guide's separate "kubernetes-gateway-rbac.yml" step is intentionally
# skipped: the official Helm chart already renders the ServiceAccount,
# ClusterRole (with the gateway.networking.k8s.io rules) and ClusterRoleBinding
# when providers.kubernetesGateway.enabled = true (rbac.enabled defaults true).
#
# Cluster readiness (apiserver serving) and CNI readiness (Cilium installed) are
# guaranteed by the root module ordering: module.traefik depends_on module.cilium
# depends_on module.talos_cluster.

# Inert gates that turn the dependency tokens into apply-ordering edges. Kept
# separate from the data sources below so those still read at PLAN time (their
# results feed the kubectl_manifest for_each, whose keys must be known at plan).
resource "terraform_data" "cluster_gate" {
  input = var.cluster_ready
}

resource "terraform_data" "cni_gate" {
  input = var.cni_ready
}

resource "terraform_data" "ccm_gate" {
  input = var.ccm_ready
}

# ── Step 1: Gateway API CRDs ────────────────────────────────────────────────
# The download (hashicorp/http, no cluster config) reads at plan. We split the
# multi-doc YAML in PURE HCL rather than via data.kubectl_file_documents: that
# data source belongs to the kubectl provider, so reading it forces the provider
# to Configure at plan time — and alekc/kubectl errors ("no configuration has
# been provided") when the host is still unknown during a from-scratch apply.
# Splitting locally keeps the kubectl provider unconfigured until the
# kubectl_manifest resources actually apply (by then the apiserver is up).
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"
}

locals {
  # Drop the leading license-comment segment and any blank docs by keeping only
  # segments that decode to a named Kubernetes object. Keyed by kind/name so the
  # for_each keys are static and known at plan.
  gateway_api_docs = {
    for doc in split("\n---\n", data.http.gateway_api_crds.response_body) :
    "${yamldecode(doc).kind}/${yamldecode(doc).metadata.name}" => doc
    if try(yamldecode(doc).metadata.name, null) != null
  }
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = local.gateway_api_docs

  yaml_body         = each.value
  server_side_apply = true

  # CRDs only need the apiserver up, not the CNI (mirrors the old flat layout
  # where these depended on wait_for_apiserver).
  depends_on = [terraform_data.cluster_gate]
}

# ── Step 2: Traefik via Helm ────────────────────────────────────────────────
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.traefik_chart_version
  namespace        = "traefik"
  create_namespace = true

  values = [file("${path.module}/helm/traefik-values.yaml")]

  # Traefik pods need pod networking to become Ready — Cilium must be in first
  # (cni_gate). The Gateway API CRDs must also exist before the chart renders
  # Gateway resources. And nodes must be CCM-initialized (ccm_gate): Traefik does
  # not tolerate the uninitialized taint, so until the CCM clears it the pods stay
  # Pending and this release would time out.
  depends_on = [
    kubectl_manifest.gateway_api_crds,
    terraform_data.cni_gate,
    terraform_data.ccm_gate,
  ]
}
