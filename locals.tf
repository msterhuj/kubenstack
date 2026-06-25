locals {
  talos = {
    control = {
      "01" = {
        node    = "ctrl-3"
        address = "192.168.3.151" # Static IP assigned by cloud-init (ip_config) and Talos target
      }
      "02" = {
        node    = "ctrl-3"
        address = "192.168.3.152" # Static IP assigned by cloud-init (ip_config) and Talos target
      }
      "03" = {
        node    = "ctrl-3"
        address = "192.168.3.153" # Static IP assigned by cloud-init (ip_config) and Talos target
      }
    }
    worker = {
      "01" = {
        node    = "ctrl-3"
        address = "192.168.3.155" # Static IP assigned by cloud-init (ip_config) and Talos target
      }
      "02" = {
        node    = "ctrl-3"
        address = "192.168.3.156" # Static IP assigned by cloud-init (ip_config) and Talos target
      }
      "03" = {
        node    = "ctrl-3"
        address = "192.168.3.157" # Static IP assigned by cloud-init (ip_config) and Talos target
      }
    }
  }

  # Configuration shared by ALL machines (control plane + workers).
  # The hostname is NOT here: it is set per node (deterministic static
  # HostnameConfig) in each talos_machine_configuration_apply.
  common_machine_config = {
    machine = {
      network = {
        nameservers = ["8.8.8.8", "1.1.1.1"]
      }
    }
  }

  # control + worker merged into a SINGLE map for the VM for_each.
  # key  = VM name suffix       -> talos-ctrl-01, talos-worker-01
  # role = Talos machine type   -> "controlplane" / "worker" (reused for the machine config)
  vms = merge(
    { for k, v in local.talos.control : "controlplane-${k}" => merge(v, { role = "controlplane" }) },
    { for k, v in local.talos.worker : "worker-${k}" => merge(v, { role = "worker" }) },
  )
  cilium_manifest_objects = [
    # Load balancer to expose services on my LAN
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumL2AnnouncementPolicy"
      metadata = {
        name = "external"
      }
      spec = {
        loadBalancerIPs = true
        interfaces      = ["eth0"]
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
        blocks = [
          {
            start = "192.168.3.140" # First available IP
            stop  = "192.168.3.149" # Last available IP
          }
        ]
      }
    }
  ]
  # Convert to YAML for the inlineManifests
  cilium_external_lb_manifest = join("---\n", [for d in local.cilium_manifest_objects : yamlencode(d)])
}