variable "chart_version" {
  description = "Cilium Helm chart version."
  type        = string
  default     = "1.19.5"
}

variable "lb_interfaces" {
  description = <<-EOT
    Link names on which Cilium emits L2 announcements (ARP) for LoadBalancer IPs.
    The virtio NIC on these Talos VMs is "ens18" (NOT eth0) — same interface the
    Layer2VIPConfig uses. Cilium matches these as a regex against link names.
  EOT
  type        = list(string)
  default     = ["ens18"]
}

variable "lb_ip_blocks" {
  description = "IP ranges handed out to LoadBalancer Services (CiliumLoadBalancerIPPool)."
  type = list(object({
    start = string
    stop  = string
  }))
  default = [
    {
      start = "192.168.3.140"
      stop  = "192.168.3.149"
    }
  ]
}
