<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 06 Attendee Instructions

**Goal:** package one VNet and its subnets into a reusable child module, then add a subnet by changing inputs only. No earlier lab deployment is needed.

Read the [beginner conventions](../README.md#beginner-start-here). Keep all Terraform commands in the **Lab 06 starter root**, even while editing files inside `modules/network`. Do not run `apply` inside the child or `solution`.

## 1. Prepare a fresh lab

From the repository root in PowerShell:

```powershell
Set-Location .\lab06-custom-modules
Get-Location
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
```

On the workshop VM, run `& "C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1"`, then `az account show --output table`. On a laptop, use the [workstation authentication path](../common/azure-authentication.md#running-without-the-workshop-vm) instead; managed identity login is VM-only.

Edit your copied input file:

- Use a new group such as `rg-tf-lab06-u01`, replacing `u01` with your suffix.
- Set `unique_suffix` to the same suffix.
- Set `location = "swedencentral"` if that region is approved.
- Keep the supplied `application = 10.6.1.0/24` and `data = 10.6.2.0/24` subnet entries for the first deployment.

Never use a platform/shared/other lab group. If this directory already manages resources, stop and inspect its state with the instructor before following fresh-deployment counts.

## 2. Understand the two folders

| Folder/file | Your task |
| --- | --- |
| Root [main.tf](main.tf) | Keep the supplied RG. Add a call to `module "network"`. |
| Root [variables.tf](variables.tf) | Already declares caller inputs; no new inputs are needed. |
| Child [variables.tf](modules/network/variables.tf) | Declare the five values the module accepts. |
| Child [main.tf](modules/network/main.tf) | Create the VNet and subnet loop. Do not create a second RG. |
| Child [outputs.tf](modules/network/outputs.tf) | Return resource IDs to the caller. |
| Root [outputs.tf](outputs.tf) | Display selected child outputs in the terminal. |

Think of the child module as a function: arguments go in, resource IDs come back. Root and child variables are **different scopes** even when they share a name. The child cannot automatically read root variables.

Complete sections 3-6 before validating. **Until the root calls the child, root validation does not inspect that unused folder.** A successful check of the unmodified starter does not prove your module works.

## 3. Declare the child inputs

In [modules/network/variables.tf](modules/network/variables.tf), add a variable block for each row:

| Input name | Terraform type | Purpose |
| --- | --- | --- |
| `name` | `string` | VNet name supplied by the caller. |
| `location` | `string` | Region of the root's RG. |
| `resource_group_name` | `string` | Root-created group's name. |
| `address_space` | `list(string)` | VNet CIDR list, here `["10.6.0.0/16"]`. |
| `subnets` | `map(object({ address_prefix = string }))` | Stable subnet keys and each subnet's CIDR. |

For example, the first block is:

```hcl
variable "name" {
  type = string
}
```

Use the same structure for the other four inputs with their own names/types. Keep the MIT header. Do not copy the root's suffix input into the child: the caller constructs the name.

## 4. Implement the child resources

In [modules/network/main.tf](modules/network/main.tf), add:

1. A `resource "azurerm_virtual_network" "this"` block with these argument/value pairs:

   | Argument | Value expression |
   | --- | --- |
   | `name` | `var.name` |
   | `location` | `var.location` |
   | `resource_group_name` | `var.resource_group_name` |
   | `address_space` | `var.address_space` |

2. A `resource "azurerm_subnet" "this"` block using:

   | Argument | Value expression |
   | --- | --- |
   | `for_each` | `var.subnets` |
   | `name` | `"snet-${each.key}"` |
   | `resource_group_name` | `var.resource_group_name` |
   | `virtual_network_name` | `azurerm_virtual_network.this.name` |
   | `address_prefixes` | `[each.value.address_prefix]` |

Use `argument = expression` inside each block. Do not quote references such as `var.name`. The square brackets around the subnet prefix matter: the provider expects a list even for one CIDR.

`each.key` is `application` or `data`; `each.value.address_prefix` is that entry's CIDR. Referencing the VNet tells Terraform to create it before its subnets.

## 5. Return the child outputs

In [modules/network/outputs.tf](modules/network/outputs.tf), add two output blocks:

```hcl
output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  value = { for key, subnet in azurerm_subnet.this : key => subnet.id }
}
```

The loop returns a **map**, not an ordered list. Consumers can request the `application` ID by its stable key.

## 6. Connect the root to the child

Keep the resource group in root [main.tf](main.tf). Add this block below it:

```hcl
module "network" {
  source              = "./modules/network"
  name                = "vnet-tf-lab06-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.6.0.0/16"]
  subnets             = var.subnets
}
```

The root has no `address_space` variable in this starter, so supply the lab CIDR here. `source` is a local Terraform module path, not a command to change directories. Keep VNet/subnet resources inside the child.

In root [outputs.tf](outputs.tf), add:

```hcl
output "vnet_id" {
  value = module.network.vnet_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}
```

These refer to the child's public outputs, not directly to its internal resources.

## 7. Initialize, validate and inspect the plan

From the **Lab 06 root**, run each command separately:

```powershell
terraform fmt -recursive
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
```

`init` now discovers `module.network`; run it again if you add/change a module source. Formatting without `-recursive` would miss the child files.

**Checkpoint before apply:** validation passes and a fresh plan shows **4 to add, 0 to change, 0 to destroy**:

```text
azurerm_resource_group.this
module.network.azurerm_virtual_network.this
module.network.azurerm_subnet.this["application"]
module.network.azurerm_subnet.this["data"]
```

If only the RG appears, the module call or its resources are incomplete. Stop; do not apply a partial exercise. Confirm the correct subscription, new group, VNet `/16` and two nonoverlapping subnet `/24`s.

## 8. Deploy and read the outputs

After reviewing the saved plan:

```powershell
terraform apply main.tfplan
terraform state list
terraform output
terraform plan
```

Expected: four state addresses as above, a VNet ID, a subnet-ID map with `application` and `data`, then `No changes.` All resources use **one root state**; the child does not maintain a separate state file.

## 9. Add a subnet without changing the module

Edit only your root `terraform.tfvars`. Add this entry **inside the existing `subnets = { ... }` map**, retaining the first two entries:

```hcl
management = { address_prefix = "10.6.3.0/24" }
```

Do not create a second `subnets` assignment and do not change the child implementation.

```powershell
terraform fmt
terraform plan -out add-subnet.tfplan
terraform show add-subnet.tfplan
```

**Checkpoint:** **1 to add, 0 to change, 0 to destroy**, at `module.network.azurerm_subnet.this["management"]`. The output map will also gain that key. If existing subnets are replaced/deleted, check that their original keys and CIDRs are unchanged.

```powershell
terraform apply add-subnet.tfplan
terraform output subnet_ids
terraform plan
```

Expected: three subnet IDs and no remaining changes. Do not reuse `main.tfplan` after changing inputs.

## 10. Clean up

```powershell
terraform plan -destroy -out cleanup.tfplan
terraform show cleanup.tfplan
```

Expect five managed deletions if you completed section 9, or four if you stopped after the initial deployment. Check the dedicated RG contains only this lab's resources.

```powershell
terraform apply cleanup.tfplan
az group exists --name "rg-tf-lab06-u01"
```

Use your actual group name; expected result is `false`. RG deletion can delete unrelated contents too. Never disable AzureRM's unmanaged-content safeguard to bypass a cleanup error. Keep platform/backend resources and other labs intact, and keep inputs/state/plans out of Git.

**You are done when you can trace:** root input -> module argument -> child variable -> resource -> child output -> root output. See the [README](README.md#common-mistakes) for common module errors.
