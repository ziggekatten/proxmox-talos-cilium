locals {
  controlplane_base_ip = split("/", var.controlplane_ip_base)[0]
  controlplane_prefix  = split("/", var.controlplane_ip_base)[1]
  worker_base_ip       = split("/", var.worker_ip_base)[0]
  worker_prefix        = split("/", var.worker_ip_base)[1]

  controlplane_hostnames = [
    for i in range(var.controlplane_count) :
    "${var.cluster_name}-cp-${i + 1}"
  ]

  worker_hostnames = [
    for i in range(var.worker_count) :
    "${var.cluster_name}-worker-${i + 1}"
  ]

  controlplane_ips = [
    for i in range(var.controlplane_count) :
    format(
      "%s.%s.%s.%d/%s",
      split(".", local.controlplane_base_ip)[0],
      split(".", local.controlplane_base_ip)[1],
      split(".", local.controlplane_base_ip)[2],
      tonumber(split(".", local.controlplane_base_ip)[3]) + i,
      local.controlplane_prefix
    )
  ]

  worker_ips = [
    for i in range(var.worker_count) :
    format(
      "%s.%s.%s.%d/%s",
      split(".", local.worker_base_ip)[0],
      split(".", local.worker_base_ip)[1],
      split(".", local.worker_base_ip)[2],
      tonumber(split(".", local.worker_base_ip)[3]) + i,
      local.worker_prefix
    )
  ]

  controlplane_bare_ips = [for ip in local.controlplane_ips : split("/", ip)[0]]
  worker_bare_ips       = [for ip in local.worker_ips : split("/", ip)[0]]

  controlplane_netmasks = [
    for ip in local.controlplane_ips :
    cidrnetmask(ip)
  ]

  worker_netmasks = [
    for ip in local.worker_ips :
    cidrnetmask(ip)
  ]
}
