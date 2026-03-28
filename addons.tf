resource "terraform_data" "kubernetes_api_ready" {
  count = var.install_gateway_api || var.install_cilium ? 1 : 0

  triggers_replace = [
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      $deadline = (Get-Date).AddMinutes(10)

      while ((Get-Date) -lt $deadline) {
        try {
          & $kubectl get --raw="/readyz" --request-timeout=10s *> $null
          if ($LASTEXITCODE -eq 0) {
            exit 0
          }
        } catch {
        }

        Start-Sleep -Seconds 10
      }

      Write-Error "Timed out waiting for the Kubernetes API to become ready."
      exit 1
    EOT
  }

  depends_on = [
    terraform_data.talos_bootstrap_ready,
    talos_cluster_kubeconfig.this,
  ]
}

resource "terraform_data" "gateway_api_crds" {
  count = var.install_gateway_api ? 1 : 0

  triggers_replace = [
    var.gateway_api_version,
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      & $kubectl apply --server-side -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"
    EOT
  }

  depends_on = [terraform_data.kubernetes_api_ready]
}

resource "terraform_data" "cilium" {
  count = var.install_cilium ? 1 : 0

  triggers_replace = [
    var.cilium_version,
    tostring(var.enable_cilium_bgp),
    tostring(var.enable_cilium_l2_announcements),
    tostring(var.install_gateway_api),
    tostring(var.install_hubble),
    tostring(var.node_mtu),
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $helm = "${var.helm_command}"
      & $helm repo add cilium https://helm.cilium.io --force-update
      & $helm repo update
      & $helm upgrade --install cilium cilium/cilium --version ${var.cilium_version} --namespace kube-system --create-namespace --wait --timeout 15m `
        --set ipam.mode=kubernetes `
        --set devices='{eth0}' `
        --set kubeProxyReplacement=true `
        --set k8sClientRateLimit.qps=20 `
        --set k8sClientRateLimit.burst=40 `
        --set bgpControlPlane.enabled=${lower(tostring(var.enable_cilium_bgp))} `
        --set l2announcements.enabled=${lower(tostring(var.enable_cilium_l2_announcements))} `
        --set hubble.enabled=${lower(tostring(var.install_hubble))} `
        --set hubble.relay.enabled=${lower(tostring(var.install_hubble))} `
        --set hubble.ui.enabled=${lower(tostring(var.install_hubble))} `
        --set securityContext.capabilities.ciliumAgent='{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}' `
        --set securityContext.capabilities.cleanCiliumState='{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}' `
        --set cgroup.autoMount.enabled=false `
        --set cgroup.hostRoot=/sys/fs/cgroup `
        --set k8sServiceHost=localhost `
        --set k8sServicePort=7445 `
        --set gatewayAPI.enabled=${lower(tostring(var.install_gateway_api))} `
        --set gatewayAPI.enableAlpn=${lower(tostring(var.install_gateway_api))} `
        --set gatewayAPI.enableAppProtocol=${lower(tostring(var.install_gateway_api))}

      if ([System.Convert]::ToBoolean("${lower(tostring(var.enable_cilium_bgp))}")) {
        & "${var.kubectl_command}" -n kube-system rollout restart ds/cilium
        & "${var.kubectl_command}" -n kube-system rollout status ds/cilium --timeout=15m
      }
    EOT
  }

  depends_on = [
    terraform_data.kubernetes_api_ready,
    terraform_data.gateway_api_crds,
  ]
}

resource "terraform_data" "kubernetes_nodes_ready" {
  count = var.install_cilium ? 1 : 0

  triggers_replace = [
    var.cilium_version,
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      & $kubectl wait --for=condition=Ready nodes --all --timeout=10m
    EOT
  }

  depends_on = [terraform_data.cilium]
}

resource "terraform_data" "cilium_lb_pool" {
  count = var.install_cilium && var.install_cilium_lb_pool ? 1 : 0

  triggers_replace = [
    var.cilium_lb_pool_name,
    var.cilium_lb_pool_start,
    var.cilium_lb_pool_stop,
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      @"
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: ${var.cilium_lb_pool_name}
spec:
  blocks:
  - start: ${var.cilium_lb_pool_start}
    stop: ${var.cilium_lb_pool_stop}
"@ | & $kubectl apply -f -
    EOT
  }

  depends_on = [
    terraform_data.cilium,
    terraform_data.kubernetes_nodes_ready,
  ]
}

resource "terraform_data" "hubble_gateway" {
  count = var.install_hubble && var.install_gateway_api && var.expose_hubble_via_gateway ? 1 : 0

  triggers_replace = [
    var.hubble_gateway_name,
    var.hubble_gateway_namespace,
    var.hubble_hostname,
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      $gatewayListenerHostname = ""
      $httpRouteHostname = ""
      if ("${var.hubble_hostname}" -ne "") {
        $gatewayListenerHostname = "    hostname: ${var.hubble_hostname}`n"
        $httpRouteHostname = "  hostnames:`n  - ${var.hubble_hostname}`n"
      }

      $manifest = @"
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${var.hubble_gateway_name}
  namespace: ${var.hubble_gateway_namespace}
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
$gatewayListenerHostname    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hubble-ui
  namespace: ${var.hubble_gateway_namespace}
spec:
  parentRefs:
  - name: ${var.hubble_gateway_name}
$httpRouteHostname  rules:
  - backendRefs:
    - name: hubble-ui
      port: 80
"@

      $manifest | & $kubectl apply -f -
    EOT
  }

  depends_on = [
    terraform_data.cilium,
    terraform_data.cilium_lb_pool,
    terraform_data.kubernetes_nodes_ready,
  ]
}

resource "terraform_data" "cilium_l2_policy" {
  count = var.enable_cilium_l2_announcements && var.expose_hubble_via_gateway ? 1 : 0

  triggers_replace = [
    var.cilium_l2_announcement_policy_name,
    var.cilium_l2_interfaces,
    var.hubble_gateway_name,
    var.hubble_gateway_namespace,
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      @"
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: ${var.cilium_l2_announcement_policy_name}
spec:
  serviceSelector:
    matchLabels:
      gateway.networking.k8s.io/gateway-name: ${var.hubble_gateway_name}
  loadBalancerIPs: true
  interfaces:
  - ${var.cilium_l2_interfaces}
"@ | & $kubectl apply -f -
    EOT
  }

  depends_on = [
    terraform_data.cilium,
    terraform_data.cilium_lb_pool,
    terraform_data.hubble_gateway,
  ]
}

resource "terraform_data" "cilium_bgp_crds_ready" {
  count = var.install_cilium && var.enable_cilium_bgp ? 1 : 0

  triggers_replace = [
    var.cilium_version,
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      $crds = @(
        "ciliumbgpclusterconfigs.cilium.io",
        "ciliumbgppeerconfigs.cilium.io",
        "ciliumbgpadvertisements.cilium.io"
      )
      $deadline = (Get-Date).AddMinutes(10)

      while ((Get-Date) -lt $deadline) {
        $missing = @()

        foreach ($crd in $crds) {
          try {
            & $kubectl get crd $crd *> $null
            if ($LASTEXITCODE -ne 0) {
              $missing += $crd
            }
          } catch {
            $missing += $crd
          }
        }

        if ($missing.Count -eq 0) {
          exit 0
        }

        Start-Sleep -Seconds 10
      }

      Write-Error "Timed out waiting for Cilium BGP CRDs to become available."
      exit 1
    EOT
  }

  depends_on = [terraform_data.cilium]
}

resource "terraform_data" "cilium_bgp" {
  count = var.install_cilium && var.enable_cilium_bgp ? 1 : 0

  triggers_replace = [
    tostring(var.cilium_bgp_local_asn),
    tostring(var.cilium_bgp_peer_asn),
    var.cilium_bgp_peer_address,
    var.cilium_bgp_peer_name,
    join(",", local.worker_hostnames),
    abspath(var.kubeconfig_path),
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      $env:KUBECONFIG = "${abspath(var.kubeconfig_path)}"
      $kubectl = "${var.kubectl_command}"
      @"
apiVersion: cilium.io/v2
kind: CiliumBGPPeerConfig
metadata:
  name: ${var.cilium_bgp_peer_name}-peer
spec:
  timers:
    holdTimeSeconds: 90
    keepAliveTimeSeconds: 30
  families:
  - afi: ipv4
    safi: unicast
    advertisements:
      matchLabels:
        advertise: bgp
---
apiVersion: cilium.io/v2
kind: CiliumBGPAdvertisement
metadata:
  name: ${var.cilium_bgp_peer_name}-advertisements
  labels:
    advertise: bgp
spec:
  advertisements:
  - advertisementType: Service
    service:
      addresses:
      - LoadBalancerIP
    selector:
      matchLabels:
        io.kubernetes.service.namespace: ${var.hubble_gateway_namespace}
        io.kubernetes.service.name: cilium-gateway-${var.hubble_gateway_name}
---
apiVersion: cilium.io/v2
kind: CiliumBGPClusterConfig
metadata:
  name: ${var.cilium_bgp_peer_name}
spec:
  nodeSelector:
    matchExpressions:
    - key: kubernetes.io/hostname
      operator: In
      values:
${local.worker_hostname_yaml}
  bgpInstances:
  - name: ${var.cilium_bgp_peer_name}
    localASN: ${var.cilium_bgp_local_asn}
    peers:
    - name: ${var.cilium_bgp_peer_name}
      peerASN: ${var.cilium_bgp_peer_asn}
      peerAddress: ${var.cilium_bgp_peer_address}
      peerConfigRef:
        name: ${var.cilium_bgp_peer_name}-peer
"@ | & $kubectl apply -f -
    EOT
  }

  depends_on = [
    terraform_data.cilium_bgp_crds_ready,
    terraform_data.cilium_lb_pool,
    terraform_data.kubernetes_nodes_ready,
  ]
}
