variable "talos_version" {
  default = "v1.13.5"
  type    = string
}

variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_username" {
  type    = string
  default = "root@pam"
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}
