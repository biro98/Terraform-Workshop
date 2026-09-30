<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 04 Attendee Instructions

This lab replaces repeated subnet resources with structured input and stable `for_each` instances. Work from the input type to the resource and then to the output.

For command and state-safety conventions, see [Beginner: start here](../README.md#beginner-start-here).

## 1. Prepare

From the repository root in PowerShell, enter this lab folder, which is the starter root. Do not enter a `starter/` or `solution/` subfolder. If in another lab, first run `Set-Location ..`; if already here, skip the first command. Copy inputs only on the first visit.

```powershell
Set-Location .\lab04-loops-data-structures
Copy-Item terraform.tfvars.example terraform.tfvars
Get-Location
```

On the **workshop VM**, run in this same terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

Laptop users must instead follow [workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm); managed identity cannot be used locally.

Edit `terraform.tfvars`: personalize the Lab 04 group name and matching `unique_suffix`, choose an allowed `location`, and keep the initial three subnet entries. Never reuse Lab 03's group or state, or the VM/platform or another shared group. This is a separate deployment, not a migration of Lab 03.

The starter's group and VNet already validate; missing subnets do not make validation fail. Leave provider/version files unchanged and complete the two TODOs before applying.

## 2. Inspect the supplied subnet type

Open `variables.tf`. **`subnets` is already declared** as `map(object({ address_prefix = string }))`; do not add a second declaration. Compare it with the `application`, `data`, and `private_endpoints` entries in `terraform.tfvars`.

Checkpoint:

```powershell
terraform init
terraform fmt
terraform validate
```

If the value does not match the type, compare the object property spelling on both sides.

## 3. Create map-driven subnet instances

Open `main.tf`. Keep the supplied group and VNet. Below the TODO, add one `resource "azurerm_subnet" "this"` block:

1. Set `for_each` to the subnet map.
2. Use the map key to derive the Azure subnet name.
3. A naming hint is `"snet-${replace(each.key, "_", "-")}"`: the `private_endpoints` key becomes `snet-private-endpoints` in Azure while its state key keeps the underscore.
4. Use `address_prefixes = [each.value.address_prefix]`; the brackets turn one string into the collection the provider expects.
5. Use `resource_group_name = azurerm_resource_group.this.name` and `virtual_network_name = azurerm_virtual_network.this.name`. Subnets do not take a `location` argument.

Remember: inside a resource using `for_each`, `each.key` is the stable instance identity and `each.value` is that key's object.

```powershell
terraform validate
terraform plan
```

Checkpoint: the plan should show three addresses shaped like `azurerm_subnet.this["<key>"]`, not three copied resource labels. Expect five managed creates: group, VNet, and three subnets.

## 4. Build a useful output

Open `outputs.tf`. Add `output "subnet_ids"`, with `value = { for key, subnet in azurerm_subnet.this : key => subnet.id }`. This is an object/map expression, not a list expression in square brackets.

Run `terraform validate`. Optionally open `terraform console`, evaluate `keys(var.subnets)`, and type `exit` before running more PowerShell commands. Subnet IDs are not known until apply.

## 5. Deploy and inspect addresses

```powershell
terraform fmt
terraform fmt -check
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
```

Expect **5 to add, 0 to change, 0 to destroy**. Review names, keys, and CIDRs before applying; regenerate the plan after any edits.

```powershell
terraform apply main.tfplan
terraform state list
terraform output subnet_ids
terraform plan
```

Saved-plan apply does not ask for confirmation. Confirm the three output keys match the inputs, state contains five addresses, and the final plan shows no changes.

## 6. Prove stable iteration

Inside the existing `subnets = { ... }` map in `terraform.tfvars`, add `management = { address_prefix = "10.10.4.0/24" }`. Do not create another `subnets` assignment or rename existing keys. Run `terraform plan`.

Expect exactly **1 to add**, at `azurerm_subnet.this["management"]`, with no replacements. For the shortest path, do not apply: remove only that test entry, save, and run `terraform plan`; expect no changes. If you choose to deploy the fourth subnet, save and review a **new** `main.tfplan`, apply it, and leave its input entry present until cleanup.

## Cleanup

Review `terraform plan -destroy` in the state that owns this deployment, then run `terraform destroy`. **This deletes the lab resource group and its contents**, not only the resources listed in this root. AzureRM may refuse deletion when unmanaged contents remain; inspect them rather than disabling that safety check. Never put unrelated resources in this group. Verify `az group exists --name "rg-tf-lab04-u01"` returns `false` (use your actual name). Other labs' distinct groups and the platform VM/backend storage must remain. Keep local inputs, state, plans, and populated backend files out of Git.

Type `yes` after reviewing the destroy prompt, then confirm `terraform state list` is empty. Keep state until deletion succeeds.
