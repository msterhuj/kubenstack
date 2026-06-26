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
      source  = "alekc/kubectl"
      version = "2.4.1"
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

# Cluster-connected helm provider, used to install in-cluster workloads (Cilium
# CNI, Traefik). Credentials come from the admin kubeconfig that the talos-cluster
# module produces once etcd is bootstrapped. The cert/key values are base64-encoded
# PEM, hence the base64decode().
#
# Passed into the cilium/traefik modules via their `providers` argument (those
# modules declare `helm` in required_providers but carry no provider block).
provider "helm" {
  alias = "cluster"
  kubernetes = {
    host                   = module.talos_cluster.kube_host
    client_certificate     = base64decode(module.talos_cluster.kube_client_certificate)
    client_key             = base64decode(module.talos_cluster.kube_client_key)
    cluster_ca_certificate = base64decode(module.talos_cluster.kube_ca_certificate)
  }
}

provider "kubectl" {
  host                   = module.talos_cluster.cluster_endpoint
  client_certificate     = base64decode(module.talos_cluster.kube_client_certificate)
  client_key             = base64decode(module.talos_cluster.kube_client_key)
  cluster_ca_certificate = base64decode(module.talos_cluster.kube_ca_certificate)
  load_config_file       = false
}
