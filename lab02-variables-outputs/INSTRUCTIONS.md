<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 02 Attendee Instructions

Use this guide with [README.md](README.md). The lab folder itself is the starter root; do not create or enter a `starter/` or `solution/` subfolder.

For command and state-safety conventions, see [Beginner: start here](../README.md#beginner-start-here).

## 1. Prepare

From the repository root in PowerShell, run the following. If in another lab, first run `Set-Location ..`; if already in Lab 02, skip the first command. Copy inputs once, not over an existing edited file.

```powershell
Set-Location .\lab02-variables-outputs
Copy-Item terraform.tfvars.example terraform.tfvars
Get-Location
```

On the **workshop VM**, run in this same terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

Laptop users must instead follow [workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm); do not try the VM's managed identity locally.

Edit `terraform.tfvars`: choose your own suffix in `resource_group_name`, `unique_suffix`, and the explicit `vnet_name`; set `location` to an allowed region. Keep the supplied CIDRs for the first deployment. This root creates its own group: never use the VM/platform group, Lab 01's group, or a pre-existing/shared group. No earlier lab state is needed.

The unedited starter may validate and plan only a group, with warnings about undeclared inputs. That is not completion. Leave `providers.tf` and `terraform.tf` unchanged and complete all TODOs below before applying.

## 2. Define the input contract

Open `variables.tf`. Keep the existing declarations and add `vnet_name`, `vnet_address_space`, `subnet_name`, and `subnet_prefix`.

For each input:

1. Use the exact input name from `terraform.tfvars.example`.
2. Use `string` as its type.
3. Add a short description of what it controls.
4. Do not hardcode the supplied value in the declaration.

Checkpoint:

```powershell
terraform init
terraform fmt
terraform validate
```

For example, the `vnet_name` block needs `type = string` and a description; its value comes from `terraform.tfvars`, not a default. An undeclared-variable error means a name in the configuration does not exactly match its declaration.

## 3. Build the local naming value

Open `main.tf`. Replace the local's `"TODO"` with `"tf-lab02-${var.unique_suffix}"`. Use `local.name_prefix` as the value of a VNet `workload` tag inside its `tags` map; the group and VNet names remain explicit inputs.

Checkpoint: changing the suffix changes the derived local without changing HCL. The explicitly supplied `vnet_name` must be updated separately when changing the VNet name.

## 4. Complete resources in dependency order

Work from parent to child:

1. Managed resource group: inspect `azurerm_resource_group.this`, which creates a group using `var.resource_group_name` and `var.location`.
2. Add `resource "azurerm_virtual_network" "this"`: use `var.vnet_name`, `address_space = [var.vnet_address_space]`, plus the group's `.name` and `.location`.
3. Add `resource "azurerm_subnet" "this"`: use `var.subnet_name`, `address_prefixes = [var.subnet_prefix]`, the group's `.name`, and `virtual_network_name = azurerm_virtual_network.this.name`. A subnet does not take a `location` argument.

Use resource references wherever an Azure child depends on a Terraform-managed parent. Do not repeat generated names as strings.

```powershell
terraform fmt
terraform validate
terraform plan
```

Review the completed plan. It should show three creates (group, VNet, subnet), and the subnet prefix must fit inside the VNet address space.

## 5. Complete outputs

Open `outputs.tf` and expose:

1. The managed resource-group name from `azurerm_resource_group.this.name`.
2. `vnet_id` from `azurerm_virtual_network.this.id`.
3. `subnet_id` from `azurerm_subnet.this.id`.

Create one `output "<name>" { value = <reference> }` block per value; name the first `resource_group_name`. Then save the final plan:

```powershell
terraform fmt
terraform fmt -check
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
```

Expect **3 to add, 0 to change, 0 to destroy**, with all three outputs. Stop if any TODO names, missing resources, or unexpected actions remain. After any further edit, generate and review a fresh saved plan.

## 6. Apply and test configurability

```powershell
terraform apply main.tfplan
terraform output
terraform state list
terraform plan
```

The saved-plan apply does not prompt for `yes`. Expect three state addresses and a no-change plan. Verify the subnet in Azure:

```powershell
$subnetId = terraform output -raw subnet_id
az network vnet subnet show --ids $subnetId --output json
```

Change only the VNet/subnet CIDRs in `terraform.tfvars` to `10.22.0.0/16` and `10.22.1.0/24`. Run `terraform plan` and identify updates or replacements; **do not apply this experiment**. Restore `10.2.0.0/16` and `10.2.1.0/24`, save, and run `terraform plan` again. It should return to no changes.

## Cleanup

Review `terraform plan -destroy` in the state that owns this deployment, then run `terraform destroy`. **This deletes the lab resource group and its contents**, not only the resources listed in this root. AzureRM may refuse deletion when unmanaged contents remain; inspect them rather than disabling that safety check. Never put unrelated resources in this group. Verify `az group exists --name "rg-tf-lab02-u01"` returns `false` (use your actual name). Other labs' distinct groups and the platform VM/backend storage must remain. Keep local inputs, state, plans, and populated backend files out of Git.

Type `yes` at the reviewed destroy prompt, then confirm `terraform state list` is empty. Do not remove state as a substitute for destroying resources.
