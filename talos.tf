resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  for_each = { for i, ip in local.controlplane_bare_ips : "cp-${i}" => ip }

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          interfaces = [{
            interface = "eth0"
            addresses = [local.controlplane_ips[tonumber(split("-", each.key)[1])]]
            mtu       = var.node_mtu
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.controlplane_gateway
            }]
            vip = {
              ip = var.cluster_vip
            }
          }]
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = var.worker_count == 0
        network = {
          cni = {
            name = "none"
          }
          podSubnets     = [var.pod_cidr]
          serviceSubnets = [var.service_cidr]
        }
        proxy = {
          disabled = true
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  for_each = { for i, ip in local.worker_bare_ips : "worker-${i}" => ip }

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          interfaces = [{
            interface = "eth0"
            addresses = [local.worker_ips[tonumber(split("-", each.key)[1])]]
            mtu       = var.node_mtu
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.worker_gateway
            }]
          }]
        }
      }
    })
  ]
}

resource "proxmox_virtual_environment_file" "controlplane_user_data" {
  for_each = data.talos_machine_configuration.controlplane

  content_type = "snippets"
  datastore_id = var.proxmox_snippet_datastore
  node_name    = var.proxmox_node

  source_raw {
    data      = each.value.machine_configuration
    file_name = "talos-${each.key}.yaml"
  }
}

resource "proxmox_virtual_environment_file" "controlplane_meta_data" {
  for_each = { for i in range(var.controlplane_count) : "cp-${i}" => i }

  content_type = "snippets"
  datastore_id = var.proxmox_snippet_datastore
  node_name    = var.proxmox_node

  source_raw {
    data = yamlencode({
      "instance-id"    = local.controlplane_hostnames[each.value]
      "local-hostname" = local.controlplane_hostnames[each.value]
    })
    file_name = "talos-${each.key}-meta.yaml"
  }
}

resource "proxmox_virtual_environment_file" "worker_user_data" {
  for_each = data.talos_machine_configuration.worker

  content_type = "snippets"
  datastore_id = var.proxmox_snippet_datastore
  node_name    = var.proxmox_node

  source_raw {
    data      = each.value.machine_configuration
    file_name = "talos-${each.key}.yaml"
  }
}

resource "proxmox_virtual_environment_file" "worker_meta_data" {
  for_each = { for i in range(var.worker_count) : "worker-${i}" => i }

  content_type = "snippets"
  datastore_id = var.proxmox_snippet_datastore
  node_name    = var.proxmox_node

  source_raw {
    data = yamlencode({
      "instance-id"    = local.worker_hostnames[each.value]
      "local-hostname" = local.worker_hostnames[each.value]
    })
    file_name = "talos-${each.key}-meta.yaml"
  }
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controlplane_bare_ips[0]
  endpoint             = local.controlplane_bare_ips[0]

  depends_on = [proxmox_virtual_environment_vm.controlplane]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.controlplane_bare_ips
  nodes                = concat(local.controlplane_bare_ips, local.worker_bare_ips)
}

resource "terraform_data" "talos_bootstrap_ready" {
  triggers_replace = [
    join(",", local.controlplane_bare_ips),
    abspath(var.talosconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $talosconfig = "${abspath(var.talosconfig_path)}"
      $endpoint = "${local.controlplane_bare_ips[0]}"
      $expected = ${var.controlplane_count + var.worker_count}
      $deadline = (Get-Date).AddMinutes(15)
      $talosctl = "${var.talosctl_command}"

      while ((Get-Date) -lt $deadline) {
        try {
          $output = & $talosctl --talosconfig $talosconfig --nodes $endpoint --endpoints $endpoint get members 2>$null
          if ($LASTEXITCODE -eq 0) {
            $memberCount = ($output | Select-String -Pattern '\bMember\b').Count
            if ($memberCount -ge $expected) {
              exit 0
            }
          }
        } catch {
        }

        Start-Sleep -Seconds 10
      }

      Write-Error "Timed out waiting for Talos cluster members to register."
      exit 1
    EOT
  }

  depends_on = [
    talos_machine_bootstrap.this,
    local_file.talosconfig,
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controlplane_bare_ips[0]
  endpoint             = var.cluster_vip

  depends_on = [terraform_data.talos_bootstrap_ready]
}

resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = var.kubeconfig_path
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = var.talosconfig_path
  file_permission = "0600"
}
