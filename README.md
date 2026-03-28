# Talos on Proxmox

This Terraform project builds a Talos Kubernetes cluster on Proxmox from a Talos NoCloud VM template.

It provisions:

- 3 control-plane VMs
- 2 worker VMs
- static node IPs
- a control-plane VIP
- stable hostnames through NoCloud metadata
- Talos bootstrap and local `talosconfig`/`kubeconfig`
- Gateway API CRDs
- Cilium with kube-proxy replacement
- Hubble relay and UI
- optional Gateway API exposure for Hubble UI
- Cilium `LoadBalancerIPPool` for Gateway addresses
- Cilium L2 announcements for Gateway reachability

## Requirements

- a Proxmox VM template built from a Talos NoCloud image
- `talos_template_vmid` set to that template ID
- a datastore with `snippets` enabled for `proxmox_snippet_datastore`
- `talosctl`, `kubectl`, and `helm` installed on the machine running Terraform
- Cilium is pinned to the current latest release in `terraform.tfvars.example`

If Terraform cannot find those CLIs on `PATH`, set these in `terraform.tfvars`:

- `talosctl_command`
- `kubectl_command`
- `helm_command`

## Create the Talos Template

Create the Proxmox template from a Talos NoCloud disk image, not from the ISO.

1. Download a Talos NoCloud raw image from Image Factory that matches `talos_version`.
2. Import it into Proxmox and attach it as `scsi0`.
3. Convert the VM to a template.
4. Set `talos_template_vmid` in `terraform.tfvars` to that template ID.

Example on the Proxmox host:

```bash
wget -O /var/lib/vz/template/cache/talos-nocloud.raw.xz <talos-image-factory-url>
unxz -f /var/lib/vz/template/cache/talos-nocloud.raw.xz

qm create 9000 --name talos-nocloud-template --memory 4096 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --serial0 socket --vga serial0

qm importdisk 9000 /var/lib/vz/template/cache/talos-nocloud.raw local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot order=scsi0
qm set 9000 --ostype l26
qm template 9000
```

Adjust the bridge, datastore, and image URL to match your environment.

## Workflow

1. Create or update `terraform.tfvars`.
2. Run `terraform init`.
3. Run `terraform apply`.

The first apply can take a while while Talos boots, Cilium images are pulled, and all nodes become `Ready`.

If `expose_hubble_via_gateway = true`, Terraform also creates a `Gateway` and `HTTPRoute` for the `hubble-ui` service in `kube-system`.
If `install_cilium_lb_pool = true`, Terraform also creates a `CiliumLoadBalancerIPPool`.
If `enable_cilium_l2_announcements = true`, Terraform also creates a `CiliumL2AnnouncementPolicy` for the Hubble Gateway service.

## Post-Install Checks

Verify that all Kubernetes nodes are ready:

```powershell
kubectl --kubeconfig .\kubeconfig get nodes -o wide
```

Verify that Gateway API is installed and accepted by Cilium:

```powershell
kubectl --kubeconfig .\kubeconfig get gatewayclass
kubectl --kubeconfig .\kubeconfig get crd | findstr gateway.networking.k8s.io
```

Verify the Hubble Gateway and route:

```powershell
kubectl --kubeconfig .\kubeconfig -n kube-system get gateway,httproute
kubectl --kubeconfig .\kubeconfig get CiliumLoadBalancerIPPool
kubectl --kubeconfig .\kubeconfig get ciliuml2announcementpolicies
```

Verify that Hubble UI is reachable through the Gateway IP:

```powershell
kubectl --kubeconfig .\kubeconfig -n kube-system get svc cilium-gateway-hubble
```

Open the `EXTERNAL-IP` from that service in a browser, for example `http://192.168.2.50`.

Optional Talos checks:

```powershell
talosctl --talosconfig .\talosconfig --nodes 192.168.2.20 --endpoints 192.168.2.20 get members
talosctl --talosconfig .\talosconfig --nodes 192.168.2.20 --endpoints 192.168.2.20 version
```

Optional Cilium CLI checks:

```powershell
cilium status --wait --wait-duration 5m --kubeconfig .\kubeconfig
cilium features status --kubeconfig .\kubeconfig
cilium hubble port-forward --kubeconfig .\kubeconfig
cilium connectivity test --kubeconfig .\kubeconfig
```

## Notes

- `talos_template_node` can be left empty if the template lives on `proxmox_node`
- control-plane and worker IP ranges must be valid on your network
- control-plane nodes and workers are both configured with 50 GB disks by default
- the default Cilium load balancer pool in this repo uses `192.168.2.50-192.168.2.90`
- the default L2 announcement interface selector in this repo is `^eth0$`

## Troubleshooting

If the Gateway service gets an external IP but that IP does not answer ARP or HTTP on the LAN:

1. Verify the running Cilium config:

```powershell
kubectl --kubeconfig .\kubeconfig -n kube-system exec ds/cilium -- cilium-dbg config --all | findstr /I "Devices EnableL2Announcements"
```

2. If `EnableL2Announcements` is still `false` even though the Helm values are correct, restart the Cilium DaemonSet:

```powershell
kubectl --kubeconfig .\kubeconfig -n kube-system rollout restart ds/cilium
kubectl --kubeconfig .\kubeconfig -n kube-system rollout status ds/cilium
```

3. Test again from another machine on the same LAN:

```powershell
curl http://192.168.2.50
```
