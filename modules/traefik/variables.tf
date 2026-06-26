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

# Dependency tokens passed from the root. They carry resource references across
# the module boundary so ORDERING is expressed without a module-level depends_on
# (which would defer this module's data sources to apply and break the
# kubectl_manifest for_each — keys must be known at plan time).
variable "cluster_ready" {
  description = "Token from talos-cluster: kube-apiserver serving. Gates the Gateway API CRD apply."
  type        = any
  default     = null
}

variable "cni_ready" {
  description = "Token from cilium: CNI installed. Gates the Traefik release (pods need pod networking)."
  type        = any
  default     = null
}
