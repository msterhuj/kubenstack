locals {
  # Cluster topology. Passed into the talos-cluster module as `nodes`.
  # address = static IP assigned by cloud-init (ip_config) and Talos apply target.
  talos = {
    control = {
      "01" = { node = "ctrl-3", address = "192.168.3.151" }
      "02" = { node = "ctrl-3", address = "192.168.3.152" }
      "03" = { node = "ctrl-3", address = "192.168.3.153" }
    }
    worker = {
      "01" = { node = "ctrl-3", address = "192.168.3.155" }
      "02" = { node = "ctrl-3", address = "192.168.3.156" }
      "03" = { node = "ctrl-3", address = "192.168.3.157" }
    }
  }
}
