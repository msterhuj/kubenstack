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
      # External cloud provider: hand node lifecycle (providerID + topology
      # region/zone labels) to the Proxmox CCM instead of static node labels.
      # Consequence: every node boots with the
      # node.cloudprovider.kubernetes.io/uninitialized:NoSchedule taint until the
      # CCM initializes it — Cilium tolerates it (hostNetwork), and the CCM
      # tolerates it too; other workloads only schedule once the CCM is up.
      kubelet = {
        extraArgs = {
          cloud-provider = "external"
        }
        # Longhorn stores volume data under /var/lib/longhorn. Talos' root is
        # read-only, so the kubelet (where Longhorn's engine/replica processes
        # run) needs this path bind-mounted rshared. On workers this path is the
        # dedicated 100G disk (machine.disks below); on control planes it falls
        # back to the writable /var partition (Longhorn won't place replicas there
        # — they keep the control-plane taint).
        extraMounts = [{
          destination = "/var/lib/longhorn"
          type        = "bind"
          source      = "/var/lib/longhorn"
          options     = ["bind", "rshared", "rw"]
        }]
      }
      # Pin the Talos install to the OS disk (workers have a 2nd disk for Longhorn;
      # without this pin Talos' auto-selection could install onto the wrong one).
      #
      # image: install the FACTORY installer (= same schematic as the boot ISO) so
      # the on-disk system carries the system extensions (iscsi-tools, util-linux-
      # tools, nfs-*). Without it Talos installs the vanilla
      # ghcr.io/siderolabs/installer image → NO extensions → Longhorn's manager
      # crash-loops ("iscsiadm: No such file or directory"). The Proxmox CSI didn't
      # need this (no iSCSI), which is why the gap stayed hidden until Longhorn.
      install = {
        disk  = "/dev/sda"
        image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"
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
