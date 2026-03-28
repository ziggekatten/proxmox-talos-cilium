param(
  [Parameter(Mandatory = $true)]
  [string[]]$Subnets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Expand-Cidr {
  param([string]$Cidr)

  $parts = $Cidr.Split("/")
  if ($parts.Count -ne 2) {
    throw "Unsupported CIDR format: $Cidr"
  }

  $baseIp = $parts[0]
  $prefix = [int]$parts[1]

  if ($prefix -ne 24) {
    throw "Only /24 subnets are currently supported by this helper: $Cidr"
  }

  $octets = $baseIp.Split(".")
  if ($octets.Count -ne 4) {
    throw "Invalid IPv4 address in CIDR: $Cidr"
  }

  $networkPrefix = "$($octets[0]).$($octets[1]).$($octets[2])"
  foreach ($host in 1..254) {
    "$networkPrefix.$host"
  }
}

function Normalize-Mac {
  param([string]$Mac)
  ($Mac -replace "-", ":" ).ToUpperInvariant()
}

$state = terraform show -json terraform.tfstate | ConvertFrom-Json
$vmResources = $state.values.root_module.resources | Where-Object { $_.type -eq "proxmox_virtual_environment_vm" }

$targets = @{}
foreach ($resource in $vmResources) {
  $mac = $resource.values.mac_addresses[0]
  if ($mac) {
    $targets[(Normalize-Mac $mac)] = $resource.address
  }
}

if ($targets.Count -eq 0) {
  throw "No VM MAC addresses found in terraform state."
}

foreach ($subnet in $Subnets) {
  foreach ($ip in (Expand-Cidr $subnet)) {
    Test-Connection -TargetName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue | Out-Null
  }
}

$arpEntries = arp -a
$results = @()

foreach ($line in $arpEntries) {
  if ($line -match '^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F\-]{17})\s+\w+') {
    $ip = $matches[1]
    $mac = Normalize-Mac $matches[2]

    if ($targets.ContainsKey($mac)) {
      $results += [pscustomobject]@{
        terraform_address = $targets[$mac]
        ip                = $ip
        mac               = $mac
      }
    }
  }
}

$results | Sort-Object terraform_address | Format-Table -AutoSize
