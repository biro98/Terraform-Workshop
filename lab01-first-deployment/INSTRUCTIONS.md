<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 01 Attendee Instructions

Use this guide with [README.md](README.md). Work in the lab folder itself: it is the starter Terraform root, not a `starter/` or `solution/` subfolder.

New to the command workflow? Read [Beginner: start here](../README.md#beginner-start-here) first.

## 1. Prepare

Start in a PowerShell terminal at the repository root. If you are in another lab, run `Set-Location ..` first; if already in this lab, skip the first command. Copy the example only on your first visit; do not overwrite edited inputs.

```powershell
Set-Location .\lab01-first-deployment
Copy-Item terraform.tfvars.example terraform.tfvars
Get-Location
```

On the **workshop VM**, authenticate in this same terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

On a laptop, use the [workstation authentication path](../common/azure-authentication.md#running-without-the-workshop-vm) instead; managed identity is not a local laptop login.

Open `terraform.tfvars` in your editor. Set a new `resource_group_name` (such as `rg-tf-lab01-u01`, with your own suffix), an allowed `location`, and the matching `unique_suffix`. Keep these values fixed after deploying. Never use a shared, pre-existing, other-lab, or VM/platform group. Do not copy state from another directory.

The starter can validate even while the VNet name is `"TODO"`. Validation checks configuration syntax and types, not exercise completion. Complete the edits below before applying.

## 2. Inspect the starter

Read `terraform.tf`, `providers.tf`, `variables.tf`, `main.tf`, and `outputs.tf`. Identify the provider, three input variables, and two managed resources. Leave provider/version settings unchanged. `outputs.tf` is already complete.

Checkpoint: you can explain why the VNet must depend on the resource group.

## 3. Inspect the managed resource group

In `main.tf`, find the first TODO. Explain how `name = var.resource_group_name` and `location = var.location` configure the new group. This state owns the group; use a unique Lab 01 name.

Run:

```powershell
terraform fmt
terraform init
terraform validate
```

If validation fails, read the first error and check interpolation braces, quotes, and the variable name.

## 4. Complete the VNet reference

Find the second TODO in `main.tf`. Replace only `name = "TODO"` with `name = "vnet-tf-lab01-${var.unique_suffix}"`. Keep `address_space = ["10.1.0.0/16"]` and the existing resource-group name and location references.

Checkpoint: the references include the resource type, local label, and exported attribute, without a `data` prefix.

```powershell
terraform fmt
terraform fmt -check
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
```

The completed first plan should report **2 to add, 0 to change, 0 to destroy**: one group and one VNet. It must not include a subnet or unrelated resource. If you edit any `.tf` or `.tfvars` file after saving a plan, regenerate and review `main.tfplan` before applying; a saved plan does not pick up later edits.

## 5. Apply and inspect

```powershell
terraform apply main.tfplan
terraform output
terraform state list
terraform plan
```

Applying a saved plan does not ask for `yes`: review it before the apply command. Confirm state contains `azurerm_resource_group.this` and `azurerm_virtual_network.this`, outputs show the group name and VNet ID, and the last plan reports no changes.

To verify Azure without retyping names:

```powershell
$vnetId = terraform output -raw virtual_network_id
az network vnet show --ids $vnetId --query "{name:name,addressSpace:addressSpace.addressPrefixes,resourceGroup:resourceGroup}" --output json
```

Expect the personalized VNet name, `10.1.0.0/16`, and your Lab 01 group.

## Cleanup

Review `terraform plan -destroy` in the state that owns this deployment, then run `terraform destroy`. **This deletes the lab resource group and its contents**, not only the resources listed in this root. AzureRM may refuse deletion when unmanaged contents remain; inspect them rather than disabling that safety check. Never put unrelated resources in this group. Verify `az group exists --name "rg-tf-lab01-u01"` returns `false` (use your actual name). Other labs' distinct groups and the platform VM/backend storage must remain. Keep local inputs, state, plans, and populated backend files out of Git.

Type `yes` only after reviewing the destroy prompt. Run `terraform state list` afterward; it should be empty. Keep state until deletion succeeds; deleting a state file is not cleanup.
