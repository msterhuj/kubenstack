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

variable "gateway_api_version" {
  description = "Kubernetes Gateway API release (CRDs, standard channel)."
  type        = string
  default     = "v1.3.0"
}

variable "traefik_chart_version" {
  description = "Traefik Helm chart version (37.2.0 ships Traefik v3.5.3, matching the RBAC pinned below)."
  type        = string
  default     = "37.2.0"
}

# ── Step 1: Gateway API CRDs ────────────────────────────────────────────────
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = data.kubectl_file_documents.gateway_api_crds.manifests

  yaml_body         = each.value
  server_side_apply = true

  # Wait for the API server to be up before applying (see talos.tf).
  depends_on = [data.talos_cluster_health.this]
}

# ── Step 2: Traefik via Helm ────────────────────────────────────────────────
resource "helm_release" "traefik" {
  provider = helm.cluster

  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.traefik_chart_version
  namespace        = "traefik"
  create_namespace = true

  values = [file("${path.module}/helm/traefik-values.yaml")]

  depends_on = [
    data.talos_cluster_health.this,
    kubectl_manifest.gateway_api_crds,
  ]
}
