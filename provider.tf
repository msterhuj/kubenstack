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
