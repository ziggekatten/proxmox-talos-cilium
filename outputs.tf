output "controlplane_ips" {
  value = local.controlplane_bare_ips
}

output "worker_ips" {
  value = local.worker_bare_ips
}

output "cluster_endpoint" {
  value = var.cluster_endpoint
}

output "kubeconfig_path" {
  value = var.kubeconfig_path
}

output "talosconfig_path" {
  value = var.talosconfig_path
}

output "controlplane_hostnames" {
  value = local.controlplane_hostnames
}

output "worker_hostnames" {
  value = local.worker_hostnames
}
