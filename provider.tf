terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}


provider "proxmox" {
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password

  insecure = true
}

provider "talos" {}

# Default helm provider: NO cluster connection on purpose. It is only used by
# data.helm_template.cilium to render manifests locally (baked into the Talos
# machine config). Wiring cluster credentials here would create a dependency
# cycle (kubeconfig <- bootstrap <- machineconfig <- helm_template <- provider).
provider "helm" {}

# Cluster-connected helm provider, used to install workloads into the live
# cluster (Traefik). Credentials come from the admin kubeconfig that Talos
# generates once etcd is bootstrapped. The cert/key values are base64-encoded
# PEM, hence the base64decode().
provider "helm" {
  alias = "cluster"
  kubernetes = {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

provider "kubectl" {
  host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  load_config_file       = false
}
