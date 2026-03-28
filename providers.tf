provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure

  ssh {
    agent       = var.proxmox_ssh_agent
    username    = var.proxmox_ssh_username
    password    = var.proxmox_ssh_password
    private_key = var.proxmox_ssh_private_key
  }
}

provider "talos" {}
