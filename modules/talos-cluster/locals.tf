locals {
  control = var.nodes.control
  worker  = var.nodes.worker

  # Configuration shared by ALL machines (control plane + workers).
  # The hostname is NOT here: it is set per node (deterministic static
  # HostnameConfig) in each talos_machine_configuration_apply.
  common_machine_config = {
    machine = {
      network = {
        nameservers = var.nameservers
      }
    }
  }

  # control + worker merged into a SINGLE map for the VM for_each.
  # key  = VM name suffix       -> controlplane-01, worker-01
  # role = Talos machine type   -> "controlplane" / "worker"
  vms = merge(
    { for k, v in local.control : "controlplane-${k}" => merge(v, { role = "controlplane" }) },
    { for k, v in local.worker : "worker-${k}" => merge(v, { role = "worker" }) },
  )
}
