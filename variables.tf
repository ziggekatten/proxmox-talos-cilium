variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "proxmox_insecure" {
  type    = bool
  default = false
}

variable "proxmox_node" {
  type = string
}

variable "proxmox_datastore" {
  type = string
}

variable "proxmox_bridge" {
  type = string
}

variable "talos_template_vmid" {
  type = number
}

variable "talos_template_node" {
  type    = string
  default = ""
}

variable "proxmox_snippet_datastore" {
  type    = string
  default = "local"
}

variable "talos_version" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_vip" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "controlplane_count" {
  type    = number
  default = 3
}

variable "controlplane_cpu" {
  type    = number
  default = 2
}

variable "controlplane_memory" {
  type    = number
  default = 4096
}

variable "controlplane_disk_size" {
  type    = number
  default = 50
}

variable "controlplane_vmid_base" {
  type    = number
  default = 800
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "worker_cpu" {
  type    = number
  default = 2
}

variable "worker_memory" {
  type    = number
  default = 4096
}

variable "worker_disk_size" {
  type    = number
  default = 50
}

variable "worker_vmid_base" {
  type    = number
  default = 810
}

variable "controlplane_ip_base" {
  type    = string
  default = "192.168.1.10/24"
}

variable "controlplane_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "worker_ip_base" {
  type    = string
  default = "192.168.1.20/24"
}

variable "worker_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

variable "node_mtu" {
  type    = number
  default = 1450
}

variable "install_cilium" {
  type    = bool
  default = true
}

variable "cilium_version" {
  type    = string
  default = "1.18.0"
}

variable "enable_cilium_l2_announcements" {
  type    = bool
  default = true
}

variable "cilium_l2_announcement_policy_name" {
  type    = string
  default = "gateway-l2-policy"
}

variable "cilium_l2_interfaces" {
  type    = string
  default = "^eth0$"
}

variable "install_gateway_api" {
  type    = bool
  default = true
}

variable "gateway_api_version" {
  type    = string
  default = "v1.4.1"
}

variable "install_hubble" {
  type    = bool
  default = true
}

variable "install_cilium_lb_pool" {
  type    = bool
  default = true
}

variable "cilium_lb_pool_name" {
  type    = string
  default = "default-pool"
}

variable "cilium_lb_pool_start" {
  type    = string
  default = "192.168.2.50"
}

variable "cilium_lb_pool_stop" {
  type    = string
  default = "192.168.2.90"
}

variable "expose_hubble_via_gateway" {
  type    = bool
  default = true
}

variable "hubble_gateway_name" {
  type    = string
  default = "hubble"
}

variable "hubble_gateway_namespace" {
  type    = string
  default = "kube-system"
}

variable "hubble_hostname" {
  type    = string
  default = ""
}

variable "talosctl_command" {
  type    = string
  default = "talosctl"
}

variable "kubectl_command" {
  type    = string
  default = "kubectl"
}

variable "helm_command" {
  type    = string
  default = "helm"
}

variable "kubeconfig_path" {
  type    = string
  default = "./kubeconfig"
}

variable "talosconfig_path" {
  type    = string
  default = "./talosconfig"
}

variable "proxmox_ssh_username" {
  type    = string
  default = ""
}

variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "proxmox_ssh_private_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "proxmox_ssh_agent" {
  type    = bool
  default = false
}
