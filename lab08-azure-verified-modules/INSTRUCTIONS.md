<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 08 Attendee Instructions

**Goal:** create one VNet and three subnets using an Azure Verified Module (AVM),
then attach your own application security policy. An AVM is reusable Terraform
code: you supply inputs, and the module creates the resources inside it.

Follow the sections in order, running one command at a time. Stop when a checkpoint
does not match. The code blocks below complete the starter gradually; you do not
need the separate solution folder. Do not apply until section 6.

For command and state-safety conventions, see [Beginner: start here](../README.md#beginner-start-here).

## 1. Prepare

From the repository root in PowerShell, enter the lab folder itself (the starter root), not `solution/`. If in another lab, first run `Set-Location ..`; if already here, skip the first command. Copy inputs once, without overwriting prior edits.

```powershell
Set-Location .\lab08-azure-verified-modules
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
Get-Location
```

On the **workshop VM**, run in this same terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

Laptop users must instead follow [workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm); the VM identity is not available locally.

Open your copied `terraform.tfvars`. Change `u01` to your own short suffix in both
`resource_group_name` and `unique_suffix`. The sample uses `swedencentral` (Sweden
Central); use it only if approved in your subscription. Do not change an existing
deployment's region just to match the example.

Keep the three example subnets. `management_cidr = "203.0.113.10/32"` is a
documentation-only example, not a working client address; use your approved
management CIDR for a realistic rule, never `0.0.0.0/0`. `/32` means one IPv4
address. No client connectivity is tested here.

The group must be new and dedicated to this root, never a shared, other-lab, or VM/platform group. Leave provider/version files unchanged. The initial starter may validate while declaring only the group; successful validation is not proof the module is implemented.

**Resuming a previous attempt?** If there is existing state or an active backend,
do not delete either to start over. Initialize that same root, inspect
`terraform state list`, and confirm ownership with the instructor before applying.
Keep the SPDX/MIT headers and existing resource group block.

| File | What you do |
| --- | --- |
| `terraform.tfvars` | Personalize inputs; never commit this file. |
| `main.tf` | Keep the group; add the NSG, rule, and module below it. |
| `outputs.tf` | Keep the group output; add three outputs in section 5. |
| `variables.tf`, `providers.tf`, `terraform.tf` | Already supplied; do not duplicate their declarations. |

The finished subnet behavior must be:

| Map key | Azure subnet name | CIDR | Application NSG attached? | Private endpoint network policies |
| --- | --- | --- | --- | --- |
| `application` | `snet-application` | `10.8.1.0/24` | Yes | Enabled |
| `data` | `snet-data` | `10.8.2.0/24` | No | Enabled |
| `private_endpoints` | `snet-private-endpoints` | `10.8.3.0/24` | No | Disabled |

The private-endpoint subnet is only a subnet prepared for that use. This lab
does not create a private endpoint or storage account.

## 2. Inspect the AVM contract

Open the [Registry documentation for version 0.22.2](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/0.22.2), not the latest-version interface, and inspect its Inputs and Outputs tabs:

1. Source `Azure/avm-res-network-virtualnetwork/azurerm` and exact `version = "0.22.2"`.
2. Required arguments for name, location, parent resource, and address space.
3. The expected subnet map shape.
4. How a subnet receives an existing NSG ID.

Checkpoint: the root owns the group, NSG, and rule; AVM owns the VNet and subnets.
`parent_id` is the group's complete Azure ID, not its name. Use the exact version
in the link: examples for another version may have different arguments.

## 3. Build root-owned security

In `main.tf`, keep `azurerm_resource_group.this`. Replace the first TODO comment
with these two blocks **after the group's closing brace**, not inside it. Leave
the module TODO for the next section. If you already wrote either block, edit it
to match rather than adding a duplicate.

```hcl
resource "azurerm_network_security_group" "application" {
  name                = "nsg-application-tf-lab08-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
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
  network_security_group_name = azurerm_network_security_group.application.name
}
```

`application` and `management_https` are Terraform labels used in references.
The `name` arguments are Azure names. The rule references the NSG's name so
Terraform knows the NSG must exist first.

```powershell
terraform init
terraform fmt
terraform validate
```

**Checkpoint:** validation succeeds. You have a group, an NSG, and a rule in code,
but no network yet. Do not apply. If validation says a resource is duplicated,
keep one block for that label; do not rename a duplicate to hide the mistake.

The source port is `"*"` because clients use ephemeral ports; the destination
service is TCP 443 and its source is restricted. Azure's built-in NSG rules remain;
this custom rule alone is not a deny-all policy.

## 4. Add the pinned AVM call

Replace the remaining module TODO in `main.tf` with this block, below the two
security resources. There is no address-space variable to add in this starter.

```hcl
module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = "vnet-tf-lab08-${var.unique_suffix}"
  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = ["10.8.0.0/16"]

  subnets = {
    for key, subnet in var.subnets : key => {
      name                              = "snet-${replace(key, "_", "-")}"
      address_prefixes                  = [subnet.address_prefix]
      network_security_group            = key == "application" ? { id = azurerm_network_security_group.application.id } : null
      private_endpoint_network_policies = key == "private_endpoints" ? "Disabled" : "Enabled"
    }
  }
}
```

Read the transformation one piece at a time:

- `subnets = { ... }` is an **argument inside the module block**.
- `for key, subnet in var.subnets` visits each input entry. For application,
  `key` is `"application"` and `subnet.address_prefix` is `"10.8.1.0/24"`.
- `key => { ... }` keeps that key and constructs the object AVM expects.
- `[subnet.address_prefix]` turns one string into a one-item list. AVM's input is
  named `address_prefixes` (plural), unlike this lab's simpler input.
- `replace(key, "_", "-")` turns `private_endpoints` into `private-endpoints`
  for the Azure name; it does not change the map key.
- `condition ? value_if_true : value_if_false` selects the NSG object only for
  application. `{ id = ... }` is the nested object AVM requires, not a bare string.
- `null` means no NSG attachment is supplied for that subnet. It is not a fake ID
  and does not create an empty NSG.

For the application entry, AVM receives `name = "snet-application"`,
`address_prefixes = ["10.8.1.0/24"]`, and the root NSG's ID. The same expression
builds all three entries without duplicating the module.

AVM owns the subnet attachments. **Do not add standalone subnet or subnet/NSG
association resources** for these same subnets.

## 5. Finish outputs, initialize, and review

In `outputs.tf`, keep the header and supplied `resource_group_name` output.
Replace the TODO comment with these three blocks at the top level:

```hcl
output "vnet_id" {
  value = module.virtual_network.resource_id
}

output "subnets" {
  value = module.virtual_network.subnets
}

output "application_nsg_id" {
  value = azurerm_network_security_group.application.id
}
```

`module.virtual_network.resource_id` is an output of the child module; `vnet_id`
is the root output you expose in the terminal. The `subnets` output contains
per-subnet objects, not just ID strings. Use these exact output names: later
commands depend on them.

```powershell
terraform init
terraform fmt
terraform fmt -check
terraform validate
terraform plan "-out=main.tfplan"
terraform show main.tfplan
```

Run `init` again because you added a module after the initial initialization. It downloads the pinned module and transitive providers; do not use `-upgrade` or edit `.terraform` files to fix interface errors.

You may see AzAPI, modtm, and random in addition to AzureRM. They are dependencies
of AVM, not unexpected VMs or appliances. If an error says a module is not installed,
run `init`; if it says an argument is unsupported, compare your block and pinned
module version with section 4. Authentication failures require fixing your login
or subscription, not changing the module source.

Checkpoint: one group, one VNet, **three subnets**, one root NSG, and one scoped rule; only application gets that NSG. Module-internal helper/telemetry resources can add plan actions, so do not expect a fixed total equal to the Azure inventory. Review every action and expect no changes/destroys on a fresh state, no compute, and no appliance. Regenerate and review the saved plan after any edits.

## 6. Apply and inspect module addresses

```powershell
terraform apply main.tfplan
terraform state list
terraform output
terraform plan
```

Saved-plan apply does not prompt for `yes`. Confirm module-owned state addresses start with `module.virtual_network`, the output has three subnet keys, and the final plan shows no changes.

```powershell
$rg = terraform output -raw resource_group_name
$vnetId = terraform output -raw vnet_id
$vnetName = ($vnetId -split '/')[-1]
az network vnet subnet list --resource-group $rg --vnet-name $vnetName --query "[].{name:name,prefix:addressPrefix,nsg:networkSecurityGroup.id,policies:privateEndpointNetworkPolicies}" --output json
```

**Check the Azure result:** three subnet rows, an NSG ID only for application,
and policies Disabled only for private endpoints. Depending on the Azure API,
the CIDR may be in `addressPrefixes` rather than `addressPrefix`; if the projected
prefix is empty, inspect the full subnet result before concluding it is missing:

```powershell
az network vnet subnet list --resource-group $rg --vnet-name $vnetName --output json
```

### Plan-only experiment: one input change

1. In `terraform.tfvars`, change only data's prefix from `10.8.2.0/24` to `10.8.4.0/24`.
2. Run `terraform plan` **without** `-out`. Identify the proposed change to the data subnet.
3. **Do not apply.** Restore `10.8.2.0/24` in the input file.
4. Run `terraform plan` again; expect no changes.

This demonstrates how changing an input reaches a resource inside a module.
Do not reuse the earlier saved deployment plan after editing inputs.

## Cleanup

Stay in the Lab 08 directory. Capture the group name before deleting its output:

```powershell
$rg = terraform output -raw resource_group_name
terraform plan -destroy "-out=cleanup.tfplan"
terraform show cleanup.tfplan
```

**Stop and inspect:** only this lab's group, VNet, three subnets, NSG, rule, and
AVM helper resources should be removed. The exact action count includes helpers.
Check the group contains no unrelated resources: group deletion deletes its
contents. Other labs and VM/backend platform resources must remain.

Only after review, run:

```powershell
terraform apply cleanup.tfplan
terraform state list
az group exists --name $rg
```

Saved-plan apply does not ask for `yes`. Expect an empty state list and `false`.
If deletion fails, preserve state and investigate; never disable deletion
safeguards or delete state to conceal the failure.

**You are done when:** you can explain the subnet transformation and ownership
boundaries, the deployed output matched the table, the plan-only experiment was
restored, and cleanup succeeded. Keep private inputs, state, plans, and credentials
out of Git.
