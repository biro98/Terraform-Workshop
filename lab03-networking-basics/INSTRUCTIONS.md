<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 03 Attendee Instructions

Build the network from parent resources to child resources. Validate after each checkpoint instead of writing the entire configuration at once.

For command and state-safety conventions, see [Beginner: start here](../README.md#beginner-start-here).

## 1. Prepare

From the repository root in PowerShell, enter the lab folder itself; there is no `starter/` subfolder to enter. If in another lab, first run `Set-Location ..`; if already in Lab 03, skip the first command. Copy inputs only once.

```powershell
Set-Location .\lab03-networking-basics
Copy-Item terraform.tfvars.example terraform.tfvars
Get-Location
```

On the **workshop VM**, run in this same terminal:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

Laptop users must instead follow [workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm); managed identity does not work from a laptop.

Edit `terraform.tfvars`: choose a new group such as `rg-tf-lab03-u01` with your own suffix, an allowed region, and matching `unique_suffix`. Never use a VM/platform, shared, or another lab's group. Keep provider/version files unchanged; build only in this lab's root, not a reference solution.

The starter only declares a group, so it may validate while missing the entire network. Intermediate plans are for inspection only; apply after completing all three `main.tf` TODOs and the outputs.

## 2. Create the VNet

Open `main.tf`. Below TODO 1, add `azurerm_virtual_network.this`, named `"vnet-tf-lab03-${var.unique_suffix}"`. Use `address_space = ["10.10.0.0/16"]` and the group's `.name` and `.location` references.

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Checkpoint: this intermediate fresh-state plan has **2 to add, 0 to change, 0 to destroy** (group and VNet). The VNet name includes `vnet-tf-lab03-` and your suffix, and its group and location arguments reference the managed group. Do not apply yet.

## 3. Add three subnets

Below TODO 2, add separate `azurerm_subnet` blocks with these local labels and Azure names:

| Local label | Azure `name` | `address_prefixes` |
| --- | --- | --- |
| `application` | `snet-application` | `["10.10.1.0/24"]` |
| `data` | `snet-data` | `["10.10.2.0/24"]` |
| `private_endpoints` | `snet-private-endpoints` | `["10.10.3.0/24"]` |

For each subnet:

1. Give it the required name and `/24` prefix.
2. Use `virtual_network_name = azurerm_virtual_network.this.name` and `resource_group_name = azurerm_resource_group.this.name`. Subnets do not take a `location` argument.
3. Confirm its prefix is inside the VNet `/16`.
4. Set `private_endpoint_network_policies = "Disabled"` explicitly on `private_endpoints`. Use `"Enabled"` for the ordinary application/data subnets to make the intended distinction explicit.

Run `terraform fmt`, `terraform validate`, and `terraform plan`. This intermediate fresh-state plan has **5 to add, 0 to change, 0 to destroy**: the group, VNet, and three subnets. This is the cumulative total, not five additional resources after the previous checkpoint; nothing has been applied yet.

## 4. Add application security

Below TODO 3, create `azurerm_network_security_group.application`, named `"nsg-tf-lab03-application-${var.unique_suffix}"`, using the group's name and location. Add a **separate** `azurerm_network_security_rule` block, not an inline `security_rule` inside the NSG. Set `network_security_group_name` from the NSG's `.name`, and set:

- `priority = 100`, `direction = "Inbound"`, `access = "Allow"`, `protocol = "Tcp"`.
- `source_port_range = "*"`, `destination_port_range = "443"`.
- `source_address_prefix = "VirtualNetwork"`, `destination_address_prefix = "*"`.
- A descriptive rule `name`, `description`, and the managed group's name.

The wildcard source **port** allows client ephemeral ports; do not replace the scoped source **address** with `"*"`. Azure's built-in NSG rules still exist: this exercise does not implement a complete deny-all policy.

The rule does not attach the NSG. Add `azurerm_subnet_network_security_group_association.application` with `subnet_id = azurerm_subnet.application.id` and `network_security_group_id = azurerm_network_security_group.application.id`. Do not associate it with the other two subnets.

Checkpoint: inspect the dependency graph in the plan. The association must wait for both the subnet and NSG.

## 5. Review and deploy

In `outputs.tf`, add `application_subnet_id`, `data_subnet_id`, and `private_endpoints_subnet_id`, each with `value` referencing the matching `azurerm_subnet.<label>.id`.

```powershell
terraform fmt
terraform fmt -check
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
```

Expect **8 to add, 0 to change, 0 to destroy**: group, VNet, three subnets, NSG, separate rule, and association. If you edit anything now, save and review a fresh plan first. Then run:

```powershell
terraform apply main.tfplan
terraform state list
terraform output
terraform plan
$applicationSubnetId = terraform output -raw application_subnet_id
az network vnet subnet show --ids $applicationSubnetId --query "{name:name,nsg:networkSecurityGroup.id,policies:privateEndpointNetworkPolicies}" --output json
```

Saved-plan apply does not prompt for `yes`. Expect eight state addresses, three outputs, a no-change plan, and the application NSG attached. Inspect the other subnet IDs in the same way: neither should have an NSG association; private endpoint policies should be disabled only on the designated subnet.

## 6. Make a controlled change

Change only the HTTPS rule's `description`, run `terraform plan`, and identify the in-place update. **Do not apply this experiment.** Restore the description, save, and run `terraform plan` again; expect no changes.

## Cleanup

Review `terraform plan -destroy` in the state that owns this deployment, then run `terraform destroy`. **This deletes the lab resource group and its contents**, not only the resources listed in this root. AzureRM may refuse deletion when unmanaged contents remain; inspect them rather than disabling that safety check. Never put unrelated resources in this group. Verify `az group exists --name "rg-tf-lab03-u01"` returns `false` (use your actual name). Other labs' distinct groups and the platform VM/backend storage must remain. Keep local inputs, state, plans, and populated backend files out of Git.

Type `yes` at the reviewed destroy prompt and confirm `terraform state list` is empty. Keep state until deletion completes.
