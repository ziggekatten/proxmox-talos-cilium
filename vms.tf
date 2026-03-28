resource "proxmox_virtual_environment_vm" "controlplane" {
  for_each = { for i in range(var.controlplane_count) : "cp-${i}" => i }

  name      = "${var.cluster_name}-cp-${each.value + 1}"
  node_name = var.proxmox_node
  vm_id     = var.controlplane_vmid_base + each.value

  tags = ["talos", "controlplane", var.cluster_name]

  cpu {
    cores = var.controlplane_cpu
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.controlplane_memory
  }

  clone {
    vm_id     = var.talos_template_vmid
    node_name = var.talos_template_node != "" ? var.talos_template_node : var.proxmox_node
    full      = true
    retries   = 3
  }

  initialization {
    datastore_id      = var.proxmox_datastore
    meta_data_file_id = proxmox_virtual_environment_file.controlplane_meta_data[each.key].id
    user_data_file_id = proxmox_virtual_environment_file.controlplane_user_data[each.key].id
    type              = "nocloud"

    ip_config {
      ipv4 {
        address = local.controlplane_ips[each.value]
        gateway = var.controlplane_gateway
      }
    }
  }

  network_device {
    bridge = var.proxmox_bridge
    model  = "virtio"
  }

  disk {
    datastore_id = var.proxmox_datastore
    interface    = "scsi0"
    size         = var.controlplane_disk_size
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  depends_on = [
    proxmox_virtual_environment_file.controlplane_meta_data,
    proxmox_virtual_environment_file.controlplane_user_data,
  ]
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = { for i in range(var.worker_count) : "worker-${i}" => i }

  name      = "${var.cluster_name}-worker-${each.value + 1}"
  node_name = var.proxmox_node
  vm_id     = var.worker_vmid_base + each.value

  tags = ["talos", "worker", var.cluster_name]

  cpu {
    cores = var.worker_cpu
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory
  }

  clone {
    vm_id     = var.talos_template_vmid
    node_name = var.talos_template_node != "" ? var.talos_template_node : var.proxmox_node
    full      = true
    retries   = 3
  }

  initialization {
    datastore_id      = var.proxmox_datastore
    meta_data_file_id = proxmox_virtual_environment_file.worker_meta_data[each.key].id
    user_data_file_id = proxmox_virtual_environment_file.worker_user_data[each.key].id
    type              = "nocloud"

    ip_config {
      ipv4 {
        address = local.worker_ips[each.value]
        gateway = var.worker_gateway
      }
    }
  }

  network_device {
    bridge = var.proxmox_bridge
    model  = "virtio"
  }

  disk {
    datastore_id = var.proxmox_datastore
    interface    = "scsi0"
    size         = var.worker_disk_size
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  depends_on = [
    proxmox_virtual_environment_file.worker_meta_data,
    proxmox_virtual_environment_file.worker_user_data,
  ]
}
