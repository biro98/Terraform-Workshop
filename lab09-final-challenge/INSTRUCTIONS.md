<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 09 Attendee Instructions

**Goal:** assemble a hub-and-spoke network from the building blocks practiced in
earlier labs. This guided capstone supplies small code blocks in construction
order and explains how they connect. You do not need the separate solution folder.

Run one command at a time. **Do not apply until section 9.** Stop when a checkpoint
shows unexpected replacement, overlapping CIDRs, or unrestricted management access.
This lab creates networking only: no VM, firewall, storage account, or private
endpoint is deployed.

For command and state-safety conventions, see [Beginner: start here](../README.md#beginner-start-here).

## 1. Prepare

From the repository root in PowerShell, enter the lab folder itself, which is the starter root, not a `solution/` folder. If coming from another lab, first run `Set-Location ..`; if already here, skip the first command. Copy inputs only once.

```powershell
Set-Location .\lab09-final-challenge
$labRoot = (Get-Location).Path
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
Get-Location
```

On the **workshop VM**, run in this same terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
Set-Location $labRoot
```

The helper changes the working directory to `C:\Workshop`; the last command
returns to the Lab 09 directory captured above. Run subsequent Terraform commands
from that directory, not from `C:\Workshop`.

Laptop users must instead follow [workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm); do not use VM managed identity locally.

In `terraform.tfvars`, replace `u01` with your own suffix in both the Lab 09 group
name and `unique_suffix`. The sample location is `swedencentral` (Sweden Central);
use an instructor-approved region. Do not relocate an existing deployment by
overwriting its inputs.

Keep the example network ranges, flags, and canonical DNS zone.
`203.0.113.10/32` is a documentation-only management source (`/32` means one IPv4
address); replace it with an approved management CIDR if needed, never an
unrestricted source. No real client traffic test is required.

Use a new group dedicated to this state, not another lab, shared group, or VM/platform group. Separate directories do not isolate resources with the same names. The starter declares only a group and may validate despite missing the entire architecture. Complete all TODOs before applying; keep existing provider settings and version constraints.

Before coding, identify the hub/spoke address spaces, each subnet's NSG and routing
flags, both peering directions, and both DNS links in the
[architecture diagram](README.md#architecture).
Confirm the CIDRs do not overlap and the simulated appliance IP belongs to the
hub subnet. No appliance is deployed, so that route cannot forward real traffic.

**Existing state or active backend?** Do not delete it or import shared resources.
Initialize the same directory, inspect `terraform state list`, and confirm the
resume point with your instructor before applying anything.

### Your editing map

| File | What you will change |
| --- | --- |
| `terraform.tfvars` | Personalize values; keep the supplied subnet maps. |
| `variables.tf` | Keep the group/location variables; add the declarations in section 2. |
| `main.tf` | Keep the group block; add each section's resources below it. |
| `outputs.tf` | Keep the group output; add seven outputs in section 8. |
| `providers.tf`, `terraform.tf` | Leave the supplied authentication and versions unchanged. |

Keep the SPDX/MIT headers. Code blocks are top-level unless explicitly described
as an argument inside another block. Add each block once; if you already wrote
one with the same label, edit it instead of duplicating it.

### Expected subnet policy

| Network / key | CIDR | NSG | Route through simulated hub appliance? | Private endpoint policies |
| --- | --- | --- | --- | --- |
| Hub / `shared_services` | `10.50.1.0/24` | None | No | Module default |
| Hub / `management` | `10.50.2.0/24` | None | No | Module default |
| Spoke / `application` | `10.60.1.0/24` | Its own NSG, with custom management HTTPS rule | Yes | Enabled |
| Spoke / `integration` | `10.60.2.0/24` | Its own NSG | Yes | Enabled |
| Spoke / `data` | `10.60.3.0/24` | Its own NSG | Yes | Enabled |
| Spoke / `private_endpoints` | `10.60.4.0/24` | Its own NSG | No | Disabled |

The input flags implement the last two columns: `route_via_hub` selects the route
table; `private_endpoint` selects the endpoint-policy setting. A subnet with
`private_endpoint = true` does not create an actual private endpoint.

## 2. Define and validate inputs

In `variables.tf`, keep `resource_group_name` and `location` and add the missing declarations with these exact names/types. Values stay in `terraform.tfvars`.

| Input | Type |
| --- | --- |
| `unique_suffix`, `management_cidr`, `hub_virtual_appliance_ip`, `private_dns_zone` | `string` |
| `hub_address_space`, `spoke_address_space` | `list(string)` |
| `tags` | `map(string)` |
| `hub_subnets` | `map(object({ address_prefix = string }))` |
| `spoke_subnets` | `map(object({ address_prefix = string, private_endpoint = bool, route_via_hub = bool }))` |

Add descriptions. Do not quote the boolean values or collapse the subnet objects into strings. Regional resources derive location from the managed group; names should include `lab09` and the suffix.

Replace the TODO comment in `variables.tf` with the following declarations.
Keep the two existing `resource_group_name` and `location` blocks unchanged:

```hcl
variable "unique_suffix" {
  description = "Short suffix identifying your Lab 09 deployment."
  type        = string
}

variable "management_cidr" {
  description = "Approved source CIDR for the application HTTPS rule."
  type        = string
}

variable "hub_virtual_appliance_ip" {
  description = "Simulated next-hop IP inside the hub; no appliance is deployed."
  type        = string
}

variable "private_dns_zone" {
  description = "Canonical private DNS zone name used by this lab."
  type        = string
}

variable "hub_address_space" {
  description = "Hub VNet CIDR ranges."
  type        = list(string)
}

variable "spoke_address_space" {
  description = "Spoke VNet CIDR ranges, not overlapping the hub."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the network components."
  type        = map(string)
}

variable "hub_subnets" {
  description = "Hub subnet keys and CIDR ranges."
  type        = map(object({ address_prefix = string }))
}

variable "spoke_subnets" {
  description = "Spoke subnet ranges and endpoint/routing choices."
  type = map(object({
    address_prefix   = string
    private_endpoint = bool
    route_via_hub    = bool
  }))
}
```

The declaration describes the allowed value's shape; the matching entry in
`terraform.tfvars` supplies the value. For example, `spoke_subnets.application`
contains a CIDR string and two booleans, not three separate Terraform resources.

```powershell
terraform init
terraform fmt
terraform validate
```

Fix type errors before continuing. After **each** subsequent checkpoint, run `terraform fmt`, `terraform validate`, and `terraform plan`; these intermediate plans are for review, not apply. Whenever you add a module call, run `terraform init` first. Do not add an output reference before its referenced resource/module exists.

Because nothing is applied until step 9, each intermediate plan is **cumulative**, not a delta from the previous code checkpoint:

| After step | Expected inventory newly added to the previous checkpoint |
| --- | --- |
| 2: Inputs | Only the supplied group is declared; not a finished deployment. |
| 3: Hub | 1 VNet and 2 hub subnets. |
| 4: Spoke | 1 VNet, 4 spoke subnets, 4 NSGs, and 1 custom rule. |
| 5: Routing | 1 route table and 1 route; attachments are part of existing subnet configuration. |
| 6: Peering | 2 directional peerings. |
| 7: DNS | 1 zone and 2 links. |
| 8: Outputs | Outputs only; no new Azure resources. |

These are architecture counts, not a fixed Terraform `to add` total: AVM also manages internal/helper resources. On a fresh state all checkpoints should have **0 to change and 0 to destroy**. Missing architecture elements cannot be excused by a successful `validate`.

## 3. Build the hub boundary

In `main.tf`, keep the supplied group block. Add this module after its closing
brace; remove the corresponding hub TODO once implemented:

```hcl
module "hub" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = "vnet-hub-tf-lab09-${var.unique_suffix}"
  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = var.hub_address_space
  tags          = var.tags

  subnets = {
    for key, subnet in var.hub_subnets : key => {
      name             = "snet-${replace(key, "_", "-")}"
      address_prefixes = [subnet.address_prefix]
    }
  }
}
```

`parent_id` takes the group's full Azure ID, not its name. The `for` expression
creates a map **value passed into the module**: key `shared_services` stays
`shared_services`, while its Azure name becomes `snet-shared-services`.
The brackets turn the input CIDR string into AVM's required list of prefixes.

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

`init` installs the new module and its transitive providers. This plan is only a
preview: do not apply or save intermediate checkpoint plans.

Checkpoint: the hub is `10.50.0.0/16` with two subnets (`10.50.1.0/24` and `10.50.2.0/24`). Inspect the [pinned AVM contract](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/0.22.2) when unsure; do not copy a latest-version example or edit downloaded `.terraform` files.

## 4. Build spoke security and network

### 4a. Create one NSG per spoke subnet

Add these two resource blocks at the top level of `main.tf`, after the hub module:

```hcl
resource "azurerm_network_security_group" "spoke" {
  for_each = var.spoke_subnets

  name                = "nsg-${replace(each.key, "_", "-")}-tf-lab09-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "management_https" {
  name                        = "Allow-Management-Https"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.management_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.spoke["application"].name
}
```

This `for_each` **creates resource instances**, unlike the hub's map-building
`for` expression. Four input keys create four NSGs. Inside that resource block,
`each.key` identifies the current key. Outside it, select an instance with
`azurerm_network_security_group.spoke["application"]`.

The rule is not looped: there is one custom rule attached only to application.
`source_port_range = "*"` allows ephemeral client ports; the destination is
TCP 443 and its source address is still restricted.

### 4b. Create the spoke and pass each NSG to its matching subnet

Add this module at the top level of `main.tf`, after the security resources:

```hcl
module "spoke" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = "vnet-spoke-tf-lab09-${var.unique_suffix}"
  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = var.spoke_address_space
  tags          = var.tags

  subnets = {
    for key, subnet in var.spoke_subnets : key => {
      name                              = "snet-${replace(key, "_", "-")}"
      address_prefixes                  = [subnet.address_prefix]
      network_security_group            = { id = azurerm_network_security_group.spoke[key].id }
      private_endpoint_network_policies = subnet.private_endpoint ? "Disabled" : "Enabled"
    }
  }
}
```

Here `key` is a local name inside the `for` expression, not `each.key`. The same
keys appear in the NSG instances, so `spoke[key].id` selects the correct NSG.
AVM requires the nested object `{ id = ... }`, not a bare ID string.
`condition ? first : second` returns `"Disabled"` when `private_endpoint` is true,
otherwise `"Enabled"`.

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Checkpoint: four spoke subnets and four NSGs, with only one custom HTTPS rule, on application. Built-in NSG rules remain; this is not a complete production isolation policy. AVM owns subnet attachments, so do not add standalone NSG association resources for these same subnets.

## 5. Add centralized route intent

Add these two top-level blocks to `main.tf` after the spoke module:

```hcl
resource "azurerm_route_table" "spoke" {
  name                = "rt-spoke-tf-lab09-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_route" "default_to_hub" {
  name                   = "default-to-hub"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.spoke.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.hub_virtual_appliance_ip
}
```

Now return to the **existing** `module "spoke"` block. Inside its `subnets` map's
`key => { ... }` object, immediately below `network_security_group`, add this
single argument. Do not paste it at the top level or add another spoke module:

```hcl
route_table = subnet.route_via_hub ? { id = azurerm_route_table.spoke.id } : null
```

This passes the table ID only when the input flag is true. `null` means no table
attachment, not an empty table. Do not add separate route-table association
resources: AVM handles those attachments.

```powershell
terraform fmt
terraform validate
terraform plan
```

Expect one table, one default route, and three subnet attachments (application, integration, data). The route expresses architecture intent only; connectivity through the next hop cannot work because this lab deliberately deploys no firewall or appliance.

`0.0.0.0/0` here is a **destination route**, not an inbound NSG permission. It
selects the default next hop for traffic without a more specific route. The
address `10.50.1.4` is inside the shared-services subnet but no machine owns it
in this lab. Do not deploy workloads expecting this simulated path to work.

## 6. Add bidirectional peering

Add these top-level blocks to `main.tf`:

```hcl
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-spoke"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.hub.name
  remote_virtual_network_id    = module.spoke.resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.spoke.name
  remote_virtual_network_id    = module.hub.resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
```

The local VNet uses its **name**; the remote VNet uses its full **ID**. Reverse
them in the second block. The references also let Terraform order creation.
Forwarded traffic support does not create an appliance or route table.
Do not also configure AVM's `peerings` input for these same connections.

```powershell
terraform fmt
terraform validate
terraform plan
```

Checkpoint: exactly two peering resources exist and each points to the opposite VNet.

## 7. Add shared private DNS

Add the following at the top level of `main.tf`:

```hcl
resource "azurerm_private_dns_zone" "this" {
  name                = var.private_dns_zone
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

locals {
  dns_virtual_networks = {
    hub   = module.hub.resource_id
    spoke = module.spoke.resource_id
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.dns_virtual_networks

  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}
```

The local map gives the link loop two stable keys, `hub` and `spoke`. `each.key`
names the link; `each.value` supplies that VNet's ID. This is one resource block
creating **two** links. The zone is global, so it has no `location` argument.
Keep its canonical name; use the dedicated group to isolate it from other labs.

```powershell
terraform fmt
terraform validate
terraform plan
```

Checkpoint: one canonical `privatelink.blob.core.windows.net` zone and two links with autoregistration disabled. Links do not create a storage account, private endpoint, or DNS records.

## 8. Complete outputs and final review

Keep the supplied group output and finish `outputs.tf`:

| Required output name | Value/reference hint |
| --- | --- |
| `hub_vnet_id`, `spoke_vnet_id` | `module.hub.resource_id`, `module.spoke.resource_id` |
| `hub_subnet_ids` | `{ for key, subnet in module.hub.subnets : key => subnet.resource_id }` |
| `spoke_subnet_ids` | The same expression using `module.spoke.subnets` |
| `peering_ids` | A map of both peering resources' `.id` attributes |
| `spoke_route_table_id` | `azurerm_route_table.spoke.id` |
| `private_dns_zone_id` | `azurerm_private_dns_zone.this.id` |

Replace the TODO in `outputs.tf` with these seven blocks, keeping the existing
`resource_group_name` output. Use the exact names so section 9 commands work:

```hcl
output "hub_vnet_id" {
  value = module.hub.resource_id
}

output "spoke_vnet_id" {
  value = module.spoke.resource_id
}

output "hub_subnet_ids" {
  value = { for key, subnet in module.hub.subnets : key => subnet.resource_id }
}

output "spoke_subnet_ids" {
  value = { for key, subnet in module.spoke.subnets : key => subnet.resource_id }
}

output "peering_ids" {
  value = {
    hub_to_spoke = azurerm_virtual_network_peering.hub_to_spoke.id
    spoke_to_hub = azurerm_virtual_network_peering.spoke_to_hub.id
  }
}

output "spoke_route_table_id" {
  value = azurerm_route_table.spoke.id
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.this.id
}
```

The subnet output loops extract each object's `resource_id` into a map of ID
strings. They do not create resources. Remove completed TODO comments after
checking every item; do not remove the header or group.

```powershell
terraform fmt
terraform fmt -check
terraform validate
terraform plan "-out=main.tfplan"
terraform show main.tfplan
```

Before apply, verify:

- AVM versions are pinned.
- Exactly one dedicated group is created; no group or resource from another lab/state is modified.
- Hub and spoke CIDRs do not overlap.
- NSGs and routes attach only to intended subnets.
- The two peerings and two DNS links are present.
- No firewall, VM, AKS cluster, or paid appliance is proposed.
- No management rule uses an unrestricted source.

Inventory: **1 group, 2 VNets, 6 subnets, 4 NSGs, 1 custom rule, 1 route table, 1 route, 2 peerings, 1 DNS zone, and 2 links**. Attachments are part of AVM subnet configuration, not extra standalone association resources. AVM internal/helper resources can increase the Terraform action count; review them rather than asserting a fixed total. The fresh-state plan must have no unexpected changes or destroys.

Regenerate and review `main.tfplan` after any edits; do not apply an earlier checkpoint's saved plan.

**If a check fails, stop here:**

| Message/symptom | First thing to check |
| --- | --- |
| Module not installed | Run `terraform init` after adding each module. |
| Unsupported argument / missing argument | Compare the current section's complete block and AVM version `0.22.2`; do not edit downloaded modules. |
| Invalid index for an NSG | The spoke module and NSGs must both use the same `var.spoke_subnets` keys, including `application`. |
| Reference to undeclared resource | Check the exact labels above and that the referenced block has been added. |
| `each` is unavailable | Use `each.key`/`each.value` only in a resource with `for_each`; use `key`/`subnet` inside the map expression. |
| An unexpected replacement appears | Stop and compare existing state and inputs; do not delete state or apply to see what happens. |
| Login/subscription failure | Recheck the VM helper or laptop authentication setup, not the resource names. |

Transitive providers and helper/telemetry resources are normal for this AVM.
Do not use `-upgrade` or change provider/module pins just to silence an unrelated
error. Keep the lock file created during initialization.

## 9. Apply and inspect

```powershell
terraform apply main.tfplan
terraform state list
terraform output
terraform plan
```

Saved-plan apply does not prompt for confirmation. Expect eight root outputs (including the supplied group output), two hub subnet keys, four spoke subnet keys, and a no-change plan.

Inspect Azure using the outputs instead of hardcoded subscription/resource IDs:

```powershell
$rg = terraform output -raw resource_group_name
$hubName = ((terraform output -raw hub_vnet_id) -split '/')[-1]
$spokeName = ((terraform output -raw spoke_vnet_id) -split '/')[-1]
az network vnet peering list --resource-group $rg --vnet-name $hubName --query "[].{name:name,state:peeringState,forwarded:allowForwardedTraffic}" --output table
az network vnet peering list --resource-group $rg --vnet-name $spokeName --query "[].{name:name,state:peeringState,forwarded:allowForwardedTraffic}" --output table
az network vnet subnet list --resource-group $rg --vnet-name $spokeName --query "[].{name:name,nsg:networkSecurityGroup.id,routeTable:routeTable.id,policies:privateEndpointNetworkPolicies}" --output json
az network private-dns link vnet list --resource-group $rg --zone-name "privatelink.blob.core.windows.net" --output table
```

Both peerings should be `Connected` with forwarded traffic enabled. All four spoke subnets need an NSG; only the three non-private-endpoint subnets need the route table. Expect two DNS links with registration disabled. Do not attempt to prove NVA connectivity: no NVA exists.

Check the DNS links explicitly if the default table omits their settings:

```powershell
az network private-dns link vnet list --resource-group $rg --zone-name "privatelink.blob.core.windows.net" --query "[].{name:name,vnet:virtualNetwork.id,registration:registrationEnabled}" --output json
```

In the subnet result, a missing/null `routeTable` on private endpoints is
**expected**, not a broken association. If peering is still updating immediately
after apply, wait briefly and repeat the read-only peering command; do not
create duplicate peerings.

## 10. Clean up

Stay in this same lab directory. Capture the group name before cleanup removes
the output, then save a deletion plan:

```powershell
$rg = terraform output -raw resource_group_name
terraform plan -destroy "-out=cleanup.tfplan"
terraform show cleanup.tfplan
```

**Stop and inspect before deleting:** the plan must remove only the inventory
from section 8 and AVM helper resources. Check the Azure group contains no
unrelated resources; deleting the group also deletes its contents.
Only when ready, run:

```powershell
terraform apply cleanup.tfplan
terraform state list
az group exists --name $rg
```

Saved-plan apply does not ask for `yes`. Expect empty state and `false` for group
existence. Inspect any AzureRM refusal to delete unmanaged contents rather than
bypassing the safeguard. Keep state until deletion succeeds; other labs and the
VM/backend platform must remain. Keep local inputs, state, and plans out of Git.

**You are done when:** you can explain the two loops, match each subnet to its
policy, distinguish names from resource IDs, explain why the route cannot carry
real traffic, verify both peerings and DNS links, and clean up successfully.
