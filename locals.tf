locals {
  # Cluster topology. Passed into the talos-cluster module as `nodes`.
  # address = static IP assigned by cloud-init (ip_config) and Talos apply target.
  # One control plane + one worker per Proxmox host. VM ↔ Proxmox-host pinning is
  # intentional: kube node migration is NOT supported (local, non-shared storage —
  # a CSI disk lives on one host's ZFS pool and can't follow a migrated VM), so each
  # node stays put and its topology.kubernetes.io/zone label is stable.
  talos = {
    control = {
      "01" = { node = "ctrl-1", address = "192.168.3.151" }
      "02" = { node = "ctrl-2", address = "192.168.3.152" }
      "03" = { node = "ctrl-3", address = "192.168.3.153" }
    }
    worker = {
      "01" = { node = "ctrl-1", address = "192.168.3.155" }
      "02" = { node = "ctrl-2", address = "192.168.3.156" }
      "03" = { node = "ctrl-3", address = "192.168.3.157" }
    }
  }
}
