<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 10 Attendee Instructions - Optional AVM Pattern Challenge

**Goal:** build a small network platform using a connectivity pattern that calls
another pattern for Private DNS. Follow every construction step below; no hidden
solution or earlier lab state is needed.

**Sandbox independence:** this configuration creates its own resource group,
VNets, subnets, peerings, Bastion, NAT, public IPs, resolver and DNS zones/links.
Nothing must be deployed first. You only need access to the sandbox subscription
and either a local computer with the required tools or the supplied workshop VM.
No existing network, storage account, remote backend, service principal or
GitHub runner is required.

**Do not apply until section 8.** This lab includes paid Bastion, NAT Gateway,
public IPs and a DNS Resolver inbound endpoint. Get budget approval first and
reserve time for section 11 cleanup. Firewall, VPN/ExpressRoute gateways and
DDoS Protection Plan must remain disabled.

Run one command at a time. Stop on errors. A successful `validate` alone does not
mean the TODOs are complete, Azure will accept the deployment, or the plan is
safe. Read the [architecture and boundaries](README.md#architecture) first.

## 1. Prepare the terminal and inputs

Open the repository in VS Code and select **Terminal > New Terminal > PowerShell**.
Start at the repository root, the folder containing all the lab folders.
If returning from another lab, navigate back to that root before continuing.

```powershell
Get-Location
$repoRoot = (Get-Location).Path
```

### 1.1 Choose one authentication path

Use **A or B**, not both. Keep the same PowerShell terminal for the rest of the lab.

#### A. Supplied workshop VM

The tools and managed identity are already provided. Do not deploy another VM.
Authenticate in this terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

The helper changes the current directory. Skip path B and continue to section
1.2, which returns to the repository path you captured above.

#### B. Local computer

Use this path if PowerShell, [Terraform](https://developer.hashicorp.com/terraform/install)
and [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) are installed
and your sandbox allows interactive user sign-in. Otherwise, use the supplied VM.
Do not run the VM helper on your local computer.

Check the tools:

```powershell
terraform version
az version
```

Terraform must be 1.14.5 or newer 1.x. Sign in with the user account that has access
to the sandbox. When prompted below, paste the sandbox subscription ID provided
by your instructor, not a production subscription ID:

```powershell
az login
if ($LASTEXITCODE -ne 0) { throw "Azure sign-in failed." }
$subscriptionId = Read-Host "Sandbox subscription ID"
az account set --subscription $subscriptionId
if ($LASTEXITCODE -ne 0) { throw "Could not select the sandbox subscription." }
$env:ARM_USE_MSI = "false"
$env:ARM_USE_CLI = "true"
$env:ARM_USE_OIDC = "false"
$env:ARM_SUBSCRIPTION_ID = az account show --query id --output tsv
if ($LASTEXITCODE -ne 0) { throw "Could not read the subscription." }
$env:ARM_TENANT_ID = az account show --query tenantId --output tsv
if ($LASTEXITCODE -ne 0) { throw "Could not read the tenant." }
az account show --output table
```

Use a terminal without unrelated service-principal credentials, such as
`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` or certificate settings. If you previously
configured those, clear the unrelated overrides as described in
[workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm).
Do not create a service principal or request Owner access for this exercise.

### 1.2 Enter the lab and set your inputs

```powershell
Set-Location (Join-Path $repoRoot 'lab10-avm-patterns')
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
Get-Location
terraform version
```

**Checkpoint:** the path ends in `lab10-avm-patterns`, not `solution`.
Terraform must be 1.14.5 or newer 1.x.

In VS Code, open `terraform.tfvars`:

1. Replace `u01` in **both** `resource_group_name` and `unique_suffix` with your own
   2-8 character lowercase/digit suffix.
2. Keep `location = "swedencentral"` unless your instructor approves another region
   supporting these services and Standard NAT zone 1.
3. Keep the two canonical DNS zone names unchanged.
4. Save the file. Do not overwrite an existing input file to restart.

Use a **new, dedicated group**. Do not use `rg-workshop-platform`, any shared
group, or another lab's group. Terraform creates the group; do not pre-create it
with Azure CLI.

This lab uses **local state** in this directory. Do not add a backend block,
copy Lab 05 backend settings or create a storage account.

**Returning to a previous attempt?** If this directory already has state or a
backend you configured earlier, initialize that same root, inspect
`terraform state list`, and ask your instructor about resuming. This is a recovery
check, not a requirement to create a backend. Do not delete state, import a shared
group or apply a stale saved plan.

### Preflight before spending money

```powershell
az account show --output table
az provider show --namespace Microsoft.Network --query registrationState --output tsv
```

Expected provider state: `Registered`; the supplied VM setup normally registers it already.
Registration enables network resource types in the subscription; it is not a
pre-existing VNet or other lab resource.

Only if the provider is not registered and your sandbox permits registration:

```powershell
az provider register --namespace Microsoft.Network --wait
if ($LASTEXITCODE -ne 0) { throw "Provider registration failed; ask the instructor." }
az provider show --namespace Microsoft.Network --query registrationState --output tsv
```

Wait for `Registered` before continuing. If registration is denied, ask the
instructor; do not change roles or policy. Then check regional usage, substituting
your approved location if different:

```powershell
az network list-usages --location swedencentral --output table
```

Confirm available regional public-IP/Bastion/NAT/resolver quota and allowed SKUs;
the usage list may not expose every service limit.
Review the [pricing and availability references](README.md#references).
A sandbox still has service limits and may incur charges. Do not grant yourself
Owner, change policy or open shared network controls.

### Your editing map

| File | Action |
| --- | --- |
| `terraform.tfvars` | Personalize the group and suffix; preserve the DNS map |
| `variables.tf` | Read the supplied typed declarations; no edits required |
| `main.tf` | Keep the group; add the four construction blocks below |
| `outputs.tf` | Keep the group output; add five outputs in section 6 |
| `providers.tf`, `terraform.tf` | Keep unchanged |

All HCL blocks below are **top-level** unless explicitly stated otherwise.
Keep the MIT/SPDX headers. Add each block once. If a label already exists, edit
the block rather than duplicate it.

You are consuming published AVM modules, not writing their implementation.
Do not create a local `modules/` directory or copy code from the AVM repositories.
See [Do I need to write my own modules?](README.md#do-i-need-to-write-my-own-modules)
for the distinction between your root configuration and its child modules.

## 2. Understand the inputs and add names

Open `variables.tf`. Notice:

- `resource_group_name`, `location` and `unique_suffix` are strings.
- `private_dns_zones` is a `map(string)`: stable service key -> canonical zone name.
- `tags` is also a `map(string)`.

Values belong in `terraform.tfvars`, not in the variable declarations.
The resource-group block already present in `main.tf` declares a **new** group;
it does not look up an existing Azure group. Terraform will create it and pass
its location and resource ID to both modules.

In `main.tf`, **keep** `azurerm_resource_group.this`. Replace the TODO comment
below it with this block:

```hcl
locals {
  hub_name   = "vnet-hub-tf-lab10-${var.unique_suffix}"
  spoke_name = "vnet-spoke-tf-lab10-${var.unique_suffix}"
}
```

**Checkpoint:** there is one resource-group block and one locals block.
Names include `lab10`, keeping them distinct from previous exercises.

## 3. Add the spoke resource module

Module documentation:
[AVM Virtual Network 0.22.2](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/0.22.2).
Its **Inputs** and **Outputs** tabs describe the exact release used below.

Append this block **below the locals block** in `main.tf`:

```hcl
module "spoke" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name             = local.spoke_name
  location         = azurerm_resource_group.this.location
  parent_id        = azurerm_resource_group.this.id
  address_space    = ["10.80.0.0/16"]
  enable_telemetry = false
  tags             = var.tags
  subnets = {
    application = {
      name                            = "snet-application"
      address_prefixes                = ["10.80.1.0/24"]
      default_outbound_access_enabled = false
    }
  }
}
```

This is a **resource module**, as in Lab 08. The `parent_id` is the full resource
group ID, not its name. The `application` key identifies a subnet inside the
module; it is not a separate top-level resource.

The subnet has no NAT Gateway and no implicit/default outbound access. Later
peering will not make the hub NAT available to it. No VM is deployed here.

**Checkpoint:** the spoke range is `10.80.0.0/16`; the upcoming hub is
`10.70.0.0/16`. These ranges do not overlap.

## 4. Add the connectivity pattern

Module documentation:
[AVM connectivity pattern 0.17.5](https://registry.terraform.io/modules/Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm/0.17.5)
and its nested
[Private DNS pattern 0.23.2](https://registry.terraform.io/modules/Azure/avm-ptn-network-private-link-private-dns-zones/azurerm/0.23.2).
Read these pinned releases when exploring the feature switches or output maps.
The DNS pattern is called internally; do not add another root module for it.

Append the following **entire module block** below the spoke module.
Do not paste it inside `module "spoke"`.

The block is longer because it deliberately lists feature choices instead of
accepting enterprise defaults. Read the explanation immediately after it.

```hcl
module "connectivity" {
  source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
  version = "0.17.5"

  enable_telemetry = false
  tags             = var.tags
  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = false
    }
  }
  hub_virtual_networks = {
    hub = {
      location                  = azurerm_resource_group.this.location
      default_parent_id         = azurerm_resource_group.this.id
      default_hub_address_space = "10.70.0.0/16"
      enabled_resources = {
        firewall                              = false
        firewall_policy                       = false
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = false
        bastion                               = true
        nat_gateway                           = true
        private_dns_zones                     = true
        private_dns_resolver                  = true
        dns_resolver_policy                   = false
      }
      hub_virtual_network = {
        name                            = local.hub_name
        address_space                   = ["10.70.0.0/16"]
        mesh_peering_enabled            = false
        route_table_firewall_enabled     = false
        route_table_user_subnets_enabled = false
        subnets = {
          workload = {
            name                            = "snet-workload"
            address_prefixes                = ["10.70.1.0/24"]
            default_outbound_access_enabled = false
            nat_gateway = {
              assign_generated_nat_gateway = true
            }
            route_table = {
              assign_generated_route_table = false
            }
          }
        }
      }
      bastion = {
        name                  = "bas-tf-lab10-${var.unique_suffix}"
        sku                   = "Basic"
        subnet_address_prefix = "10.70.0.0/26"
        zones                 = []
        bastion_public_ip = {
          name  = "pip-bastion-tf-lab10-${var.unique_suffix}"
          zones = []
        }
      }
      nat_gateway = {
        name  = "nat-tf-lab10-${var.unique_suffix}"
        sku   = "Standard"
        zones = ["1"]
        ip_configurations = {
          default = {
            is_default = true
            public_ip_configuration = {
              name  = "pip-nat-tf-lab10-${var.unique_suffix}"
              sku   = "Standard"
              zones = ["1"]
            }
          }
        }
      }
      private_dns_resolver = {
        name                             = "dnspr-tf-lab10-${var.unique_suffix}"
        subnet_name                      = "snet-dns-inbound"
        subnet_address_prefix            = "10.70.0.64/28"
        ip_address                       = "10.70.0.68"
        default_inbound_endpoint_enabled = true
      }
      private_dns_zones = {
        auto_registration_zone_enabled = false
        private_link_private_dns_zones = {
          for key, zone_name in var.private_dns_zones : key => {
            zone_name = zone_name
          }
        }
        virtual_network_link_additional_virtual_networks = {
          spoke = {
            virtual_network_resource_id = module.spoke.resource_id
          }
        }
      }
    }
  }
}
```

### Understand what you just configured

1. **`hub` is a stable map key**, not an Azure region or VNet name. Outputs use
   `["hub"]` to select this instance.
2. **Global versus per-hub flags:** the paid DDoS plan is disabled in
   `hub_and_spoke_networks_settings`. Firewall, gateway and service switches are
   inside the `hub` object's `enabled_resources`.
3. **Explicit false values matter.** Several upstream defaults are `true`.
   Removing a line is not equivalent to disabling its feature.
4. **No fake routing:** both generated route-table flags and the subnet's
   route-table assignment are disabled. We do not invent a firewall next-hop IP.
5. **NAT attachment:** `assign_generated_nat_gateway = true` attaches the
   pattern-created NAT to `snet-workload`, not to every subnet or the spoke.
   Both NAT and its public IP explicitly use Standard, zone 1; the upstream
   default is StandardV2, which this exercise does not require.
6. **Service subnets are automatic:** the pattern creates `AzureBastionSubnet`
   and `snet-dns-inbound` from their service settings. Do not also add them to
   the `subnets` map or create standalone subnet resources.
7. **DNS delegation is automatic:** the resolver subnet is delegated to
   `Microsoft.Network/dnsResolvers`. The `/28` is dedicated to the inbound
   endpoint. `10.70.0.68` is its explicitly selected usable address.
8. **Nested pattern:** the connectivity module calls Private DNS pattern 0.23.2.
   Our `for` expression turns each input string into its required
   `{ zone_name = ... }` object. This is an object transformation, not resource
   `for_each`.
9. **Only two zones:** supplying `private_link_private_dns_zones` replaces the
   large default catalogue. The automatic registration zone is also disabled.
10. **Four links:** the pattern links each zone to its hub by default. The
    additional-network map adds the spoke. No DNS link registers VM names.
11. **Inbound only:** no outbound endpoints or forwarding rulesets are supplied.
    Neither VNet's DNS-server setting is changed.

### Subnet checkpoint

| VNet | Subnet | Prefix | Special configuration |
| --- | --- | --- | --- |
| Hub | `AzureBastionSubnet` | `10.70.0.0/26` | Pattern-created for Bastion; no NAT |
| Hub | `snet-dns-inbound` | `10.70.0.64/28` | Pattern-created delegation; inbound IP `.68`; no NAT |
| Hub | `snet-workload` | `10.70.1.0/24` | Pattern-created NAT attached; no route table |
| Spoke | `snet-application` | `10.80.1.0/24` | No NAT or implicit outbound access |

The two service subnets are adjacent, not overlapping: `/26` covers `.0-.63`,
and this `/28` covers `.64-.79`.

## 5. Connect the hub and spoke

Append both blocks below the connectivity module in `main.tf`:

```hcl
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-spoke"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.connectivity.name["hub"]
  remote_virtual_network_id    = module.spoke.resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.spoke.name
  remote_virtual_network_id    = module.connectivity.resource_id["hub"]
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
```

The root owns these peerings; the pattern's multi-hub mesh is disabled.
Both directions allow direct VNet traffic. Forwarded traffic and gateway transit
are not needed because there is no appliance or gateway.

**Checkpoint:** `main.tf` now has one RG, one locals block, two modules and two
peering resources. There should be no manually created Bastion, NAT, resolver,
DNS zone, service subnet, route or firewall resource in the root.

## 6. Expose the pattern's outputs

In `outputs.tf`, keep `resource_group_name`. Replace its TODO comment with:

```hcl
output "virtual_networks" {
  description = "Hub and spoke names and resource IDs."
  value = {
    hub   = { name = module.connectivity.name["hub"], id = module.connectivity.resource_id["hub"] }
    spoke = { name = module.spoke.name, id = module.spoke.resource_id }
  }
}

output "peering_ids" {
  description = "Both directions of direct VNet peering."
  value = {
    hub_to_spoke = azurerm_virtual_network_peering.hub_to_spoke.id
    spoke_to_hub = azurerm_virtual_network_peering.spoke_to_hub.id
  }
}

output "platform_services" {
  description = "Pattern-owned Bastion, hub-only NAT Gateway and DNS Resolver."
  value = {
    bastion_id     = module.connectivity.bastion_host_resource_ids["hub"]
    nat_gateway_id = module.connectivity.nat_gateway_resource_ids["hub"]
    resolver_id    = module.connectivity.dns_resolver_resource_ids["hub"]
  }
}

output "resolver_inbound_ip_addresses" {
  description = "Private resolver endpoint IPs; no private path is configured from the management client."
  value       = module.connectivity.dns_resolver_inbound_endpoint_ip_addresses["hub"]
}

output "private_dns_zone_ids" {
  description = "Only the selected zones, created by the nested DNS pattern."
  value       = module.connectivity.private_dns_zone_resource_ids["hub"]
}
```

**Checkpoint:** six root outputs in total. Use these exact names: the verification
commands below depend on them. Computed resource IDs remain unknown until apply.

## 7. Initialize, format, validate and inspect the plan

From `lab10-avm-patterns`:

```powershell
terraform init
terraform fmt
terraform fmt -check
terraform validate
terraform plan "-out=main.tfplan"
terraform show main.tfplan
```

Wait for each command to complete successfully before running the next.
Initialization downloads many nested modules, including disabled services:
**a download is not a deployment**. The plan tells you what will be created.
Do not edit files inside `.terraform`.

Expected: validation succeeds. You may see an upstream AzAPI retry `multiplier`
deprecation warning; a warning is not an instruction to modify downloaded modules.
Errors, authentication failures and invalid plans must still be resolved.

### Review this exact Azure inventory

| Azure component | Expected count |
| --- | --- |
| Dedicated resource group | 1 |
| VNets | 2 |
| Subnets | 4 total: three hub, one spoke |
| Directional VNet peerings | 2 |
| Basic Bastion | 1 |
| Standard NAT Gateway | 1 |
| Standard public IPs | 2: Bastion and NAT |
| Private DNS Resolver | 1 |
| Resolver inbound endpoints | 1 |
| Private DNS zones | 2 |
| DNS VNet links | 4 |
| Firewall, Firewall Policy, VPN/ExpressRoute gateways, DDoS Protection Plan | **0** |
| Route tables, VMs, private endpoints, resolver outbound endpoints/rulesets | **0** |

Terraform's total action count may include helper resources; do not treat that
number as the Azure resource count. Search the plan for the service resource
types and their properties, not just words in module download paths.

**Stop if** you see extra zones, a paid excluded service, a shared resource group,
unexpected replacements/deletions, an appliance next-hop route, or the wrong NAT
association. A first deployment should not destroy existing infrastructure.

Optional inspection aid:

```powershell
terraform show -json main.tfplan | Set-Content -Encoding utf8 .\main.tfplan.json
$plan = Get-Content .\main.tfplan.json -Raw | ConvertFrom-Json
$plan.resource_changes |
  Where-Object { $_.mode -eq 'managed' } |
  Select-Object address, type, @{Name='actions'; Expression={ $_.change.actions -join ',' }} |
  Format-Table -AutoSize
```

`azapi_resource` is generic; inspect `change.after.type` to see its actual Azure
type. `main.tfplan.json` may contain sensitive infrastructure details: keep it
local and delete it after the review.

**Plan-only stopping point:** if budget or time is insufficient, do not run apply.
Explain the architecture and inventory to your instructor. A plan creates no
lab infrastructure. If resuming an earlier applied attempt, it still needs cleanup.
For a fresh plan-only attempt, stop here and skip sections 8-11's Azure operations.
Label your result **plan-only**. You may remove the local plan files using the
final artifact-removal block in section 11.

## 8. Apply the reviewed plan

Proceed only with budget approval, the expected inventory and time to clean up:

```powershell
terraform apply main.tfplan
terraform output
```

A saved-plan apply executes immediately, without another yes/no prompt.
If you changed any code or input after planning, regenerate and review the plan
first. Bastion and DNS services can take several minutes to provision.

If apply fails, **some resources may already exist and incur charges**. Keep
state, read the error, and either repair/re-plan or follow section 11. Do not
start over in another folder or delete the group out of band.

## 9. Verify in Azure, one relationship at a time

These are management-plane checks, runnable from your local computer or supplied VM.
Keep the same authenticated terminal. First load the real output values:

```powershell
$rg = terraform output -raw resource_group_name
if ($LASTEXITCODE -ne 0) { throw "Could not read the lab resource group." }
$networks = terraform output -json virtual_networks | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Could not read the network outputs." }
$services = terraform output -json platform_services | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Could not read the service outputs." }
az resource list --resource-group $rg --output table
```

The resource list may omit nested children. Use the checks below for subnets,
peerings, resolver endpoints and DNS links.

### 9.1 Both peering directions

```powershell
az network vnet peering list --resource-group $rg --vnet-name $networks.hub.name --output table
az network vnet peering list --resource-group $rg --vnet-name $networks.spoke.name --output table
```

Expected: `hub-to-spoke` and `spoke-to-hub`, both with `Connected` peering state.
`Connected` proves the peering configuration, not application reachability.

### 9.2 Hub subnet delegation and NAT attachment

```powershell
az network vnet subnet list --resource-group $rg --vnet-name $networks.hub.name --output json
az network vnet subnet list --resource-group $rg --vnet-name $networks.spoke.name --output json
az network nat gateway show --ids $services.nat_gateway_id --output json
```

Expected:

- Three hub subnets and one spoke subnet, matching section 4's table.
- **Only** hub `snet-workload` has `natGateway.id` set to the NAT output ID.
- The resolver subnet has delegation `Microsoft.Network/dnsResolvers`.
- The NAT SKU is `Standard`, its zone is `1`, and it has one public IP.
- The spoke subnet has no NAT and `defaultOutboundAccess` is `false`.

### 9.3 Bastion and public IPs

```powershell
az resource show --ids $services.bastion_id --output json
az network public-ip list --resource-group $rg --output table
```

Expected: Bastion `Basic`, provisioning state `Succeeded`, IP configuration using
`AzureBastionSubnet`; two Standard public IPs in the group.
There is no target workload VM, so you are not expected to open a Bastion session.
Do not create or attach a VM just to complete this check.

### 9.4 Resolver inbound endpoint

```powershell
az resource show --ids $services.resolver_id --output json
terraform output resolver_inbound_ip_addresses
$inboundId = "$($services.resolver_id)/inboundEndpoints/dns"
az resource show --ids $inboundId --api-version 2022-07-01 --output json
```

Expected: resolver and endpoint provisioning state `Succeeded`; static inbound
IP `10.70.0.68` in `snet-dns-inbound`. No outbound endpoint or forwarding ruleset
should exist.

Do not run `nslookup` against `.68` from your local computer or supplied VM as a
required test: the lab does not configure a private network path from either
management client. No VPN, peering or extra VM is needed to complete the exercise.
An inbound endpoint serves reachable DNS clients; it does not connect networks.

### 9.5 Two zones, two links per zone

```powershell
az network private-dns zone list --resource-group $rg --output table
az network private-dns link vnet list --resource-group $rg --zone-name privatelink.blob.core.windows.net --output json
az network private-dns link vnet list --resource-group $rg --zone-name privatelink.vaultcore.azure.net --output json
```

Expected: exactly the two configured zones, each linked to the hub and spoke
with `registrationEnabled = false`. Link provisioning should be successful.
An empty zone contains its platform SOA record, but no private endpoint A record
is expected because the lab deploys no endpoints.

You can also open [Azure portal](https://portal.azure.com/), select **Resource
groups**, open the group named by `$rg`, and inspect each service's Overview and
Configuration pages. The Mermaid diagram should match what you see.

Finally:

```powershell
terraform plan -detailed-exitcode
$planExit = $LASTEXITCODE
if ($planExit -eq 1) { throw "Plan failed; inspect the error." }
if ($planExit -eq 2) { throw "Changes remain; review them before continuing." }
```

Expected exit code `0` and **No changes**. Do not apply an unexplained change just
to make the message disappear.

## 10. Optional plan-only experiment: add a service to the DNS pattern

**Prerequisite:** sections 8-9 have successfully deployed and verified the
two-zone baseline. Here, "plan-only" means the additional DNS zone is previewed,
not applied. If you stopped before deploying the baseline in section 7, skip this
experiment; its no-change checks would not apply to your empty state.

In `terraform.tfvars`, add one entry **inside** `private_dns_zones`:

```hcl
  queue = "privatelink.queue.core.windows.net"
```

Save, then run:

```powershell
terraform plan "-out=dns-preview.tfplan"
terraform show dns-preview.tfplan
```

Expected Azure change: one additional Private DNS zone and its two VNet links,
not another resolver, Bastion or NAT Gateway. This shows how a small input change
expands a reusable pattern. **Do not apply this preview.**

Remove the `queue` line, save, and check the restored configuration:

```powershell
terraform plan -detailed-exitcode
$planExit = $LASTEXITCODE
if ($planExit -ne 0) { throw "Expected no changes after restoring the two-zone input." }
Remove-Item -LiteralPath .\dns-preview.tfplan
```

Never reuse a saved preview after restoring inputs.

## 11. Clean up immediately and verify deletion

If you never applied and have no earlier deployment in this state, there are no
lab resources to destroy. Skip to the local plan-artifact removal block below.
If apply was attempted, even unsuccessfully, inspect state and complete cleanup.

Stay in the **same Terraform directory and state**. Capture the group name before
destroy removes the output:

```powershell
$rg = terraform output -raw resource_group_name
if ($LASTEXITCODE -ne 0) { throw "Cannot identify the owned group; inspect state with the instructor." }
terraform plan -destroy "-out=cleanup.tfplan"
terraform show cleanup.tfplan
```

Review: only the dedicated Lab 10 group and its resources should be deleted.
If anything points at the workshop platform or another lab, **stop**.

After reviewing:

```powershell
terraform apply cleanup.tfplan
terraform state list
az group exists --name $rg
```

Expected: destroy completes successfully, `state list` is empty and `az group
exists` returns `false`. Deletion can take time. If it fails or the group remains,
keep state, inspect the error, regenerate a destroy plan and ask the instructor
for help. **The lab is not cleaned up while paid resources remain.**

After successful deletion, remove only stale local plan artifacts:

```powershell
foreach ($file in @('main.tfplan', 'main.tfplan.json', 'dns-preview.tfplan', 'cleanup.tfplan')) {
  if (Test-Path -LiteralPath $file) {
    Remove-Item -LiteralPath $file
  }
}
```

Keep state/backups and inputs until cleanup is confirmed. Do not delete the
workshop VM/platform, change its role assignments, or commit state/plans/inputs.

**Partial failed apply with no outputs?** Use `terraform state list` and your
`terraform.tfvars` to identify the exact owned group, confirm it with the
instructor, then run the same reviewed destroy-plan sequence. Do not delete state
just because `terraform output` cannot yet return a value.

## Troubleshooting

| Symptom | Check / action |
| --- | --- |
| Cannot find lab files after authentication | The VM helper changes directory; restore the saved repository path using section 1 |
| Local tools or interactive sign-in unavailable | Use the supplied workshop VM and authentication path A; do not provision another VM |
| Provider is not registered | Follow the conditional registration step in section 1; this is subscription setup, not a prerequisite lab deployment |
| Too many command-line arguments | Quote the entire saved-plan option: `"-out=main.tfplan"` |
| Unsupported attribute / wrong map key | Keep pinned versions; use `["hub"]` for pattern maps, but `.resource_id` for the single spoke module |
| Missing resource-group ID / invalid parent | Pass `.id` to `parent_id` / `default_parent_id`, not `.name` |
| Missing region or subscription authorization | Re-run the correct authentication path in the same terminal; verify selected subscription and identity; do not grant Owner |
| Unexpected firewall, gateway, DDoS or many DNS zones | Restore every explicit disable flag and the selected-zone map; do not apply |
| NAT SKU/zone or policy/quota failure | Use matching Standard NAT/public-IP SKU and zone 1; ask the instructor about approved regional availability; preserve any partial state |
| Duplicate DNS zone or subnet | Do not manage pattern-owned resources a second time; do not deploy starter and solution into the same group |
| DNS lookup or Bastion connection cannot be tested | No target workload or private path from the management client exists; use section 9's management-plane checks |
| Interrupted apply or destroy | Keep state, allow active operations to finish, inspect/re-plan; do not force-unlock an active operation |
| Unexpected delete/replace in a fresh lab | Check folder, inputs and state ownership before proceeding |
