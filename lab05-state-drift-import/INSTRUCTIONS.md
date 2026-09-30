<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 05 Attendee Instructions

**Goal:** teach Terraform to manage a VNet that already exists, repair a manual change, then move the state file to Azure Storage. You do not need an earlier lab's deployment.

Read the [beginner conventions](../README.md#beginner-start-here) first. Run one command at a time; stop on unexpected errors. The [README](README.md) explains the architecture and troubleshooting.

| Term | Meaning in this lab |
| --- | --- |
| Configuration (`.tf`) | The desired RG, VNet and tags. |
| State | Terraform's record linking resource addresses to real Azure IDs. Never edit it manually. |
| Import | Record an existing VNet in state; do not create a second VNet. |
| Drift | An Azure setting no longer matches the configuration. |
| Backend migration | Move the state's storage location, not the Azure resources. |

## 1. Open the starter and choose your environment

From the repository root in PowerShell:

```powershell
Set-Location .\lab05-state-drift-import
Get-Location
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
```

The path must end in `lab05-state-drift-import`, **not** `solution`. Keep this terminal open: later commands reuse its PowerShell variables.

- **Workshop VM:** run `& "C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1"`, then `az account show --output table`. Confirm the training subscription.
- **Laptop:** use the [workstation authentication instructions](../common/azure-authentication.md#running-without-the-workshop-vm), not `az login --identity`. Sections 2-5 work with approved user access. Section 6 additionally needs instructor-approved, reachable storage; the VM's helper/files and MSI settings do not work on a laptop.

Edit your copied `terraform.tfvars` using the [supplied input example](terraform.tfvars.example). For example:

```hcl
resource_group_name = "rg-tf-lab05-u01"
location            = "swedencentral"
unique_suffix       = "u01"
```

Replace `u01` with your own suffix in both places. Use Sweden Central only if allowed in your subscription. The RG must be new and belong only to this lab/state. Never use the VM/platform RG or another lab's RG.

**Before proceeding:** if this directory already has state or an active `backend.tf`, you may be resuming rather than starting. Run `terraform state list` after initialization and ask the instructor where to resume. Do not delete state/backend files to force a fresh start.

## 2. Complete the two code TODOs

1. In [data.tf](data.tf), add this block below the existing comments:

   ```hcl
   data "azurerm_client_config" "current" {}
   ```

   It reads the provider's active identity context; it creates nothing.

2. In [outputs.tf](outputs.tf), keep the two existing outputs and add:

   ```hcl
   output "current_subscription_id" {
     value = data.azurerm_client_config.current.subscription_id
   }
   ```

3. Leave [main.tf](main.tf) unchanged. It already describes the RG and VNet we want to manage.

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

**Checkpoint:** validation succeeds. A fresh full plan shows **2 to add: RG + VNet**. A data-source read is not a managed create. **Do not apply or save this full plan.** Applying it would create the VNet through Terraform and skip the import lesson.

## 3. Create only the resource group with Terraform

```powershell
terraform plan "-target=azurerm_resource_group.this" "-out=rg-bootstrap.tfplan"
terraform show rg-bootstrap.tfplan
```

**Stop and inspect:** exactly **1 to add**, `azurerm_resource_group.this`; no VNet creation or deletion. Then:

```powershell
terraform apply rg-bootstrap.tfplan
```

Targeting warnings are expected here. This one-time exception creates a prerequisite for the lesson; all later plans are unrestricted. The RG is now already managed: **do not import the RG**.

## 4. Create the VNet with Azure CLI, then import it

Set these PowerShell values to match your input file, not the example if you changed it:

```powershell
$resourceGroup = "rg-tf-lab05-u01"
$suffix = "u01"
$vnetName = "vnet-tf-lab05-$suffix"
$location = az group show --name $resourceGroup --query location --output tsv
if ($LASTEXITCODE -ne 0) { throw "Cannot read the Terraform-created Lab 05 group." }
terraform state list
```

**Checkpoint before creation:** state contains the RG, but not `azurerm_virtual_network.this`. In the Azure portal, confirm this dedicated group does not already contain `$vnetName`. If it does, stop and check ownership; do not run a create command over it.

Create the VNet with the same CIDR and tags as [main.tf](main.tf), without any subnet:

```powershell
az network vnet create --resource-group $resourceGroup --name $vnetName --location $location --address-prefixes "10.5.0.0/16" --tags environment=training owner=network-team
if ($LASTEXITCODE -ne 0) { throw "VNet creation failed; stop before import." }
$vnetId = az network vnet show --resource-group $resourceGroup --name $vnetName --query id --output tsv
if ($LASTEXITCODE -ne 0) { throw "Cannot read the VNet ID." }
$vnetId
```

The ID should look like `/subscriptions/.../resourceGroups/<your-lab05-group>/providers/Microsoft.Network/virtualNetworks/<your-vnet>`. Check its subscription, group and name before importing:

```powershell
terraform import azurerm_virtual_network.this "$vnetId"
terraform state show azurerm_virtual_network.this
terraform plan "-out=imported.tfplan"
terraform show imported.tfplan
```

**Checkpoint:** **0 to add, 0 to change, 0 to destroy** for resources. Output-only changes are acceptable. If there is a replacement (`-/+`) or a resource change, stop and compare names, group, location, CIDR and tags; ask about policy-added settings. Import did not generate or repair HCL.

After reviewing that no-resource-change plan:

```powershell
terraform apply imported.tfplan
terraform output -raw current_subscription_id
az account show --query id --output tsv
terraform state list
```

The subscription IDs must match. State should contain these **three addresses** (order may differ):

```text
data.azurerm_client_config.current
azurerm_resource_group.this
azurerm_virtual_network.this
```

## 5. Make drift visible and repair it

Leave the HCL tag as `owner = "network-team"`. Change only Azure:

```powershell
az network vnet update --resource-group $resourceGroup --name $vnetName --set tags.owner=manual-change
if ($LASTEXITCODE -ne 0) { throw "The drift change failed." }
terraform plan "-out=drift.tfplan"
terraform show drift.tfplan
```

**Checkpoint before apply:** **0 to add, 1 to change, 0 to destroy**. Find the VNet's in-place `~` change from `manual-change` back to `network-team`. A replacement is not expected.

```powershell
terraform apply drift.tfplan
terraform plan
```

Expected: `No changes.` Explain aloud: "Azure changed; our configuration did not. Terraform restored the desired tag."

## 6. Move the same state to the supplied backend

**Do not start this phase without backend access.** Storage must already exist outside the Lab 05 RG. Subscription Contributor alone does not provide Blob data access. Missing VM files or a storage 403 is a reason to stop, not to invent settings or disable a firewall.

The commands below are for the **workshop VM**. Laptop users must first arrange the [workstation backend settings](../common/azure-authentication.md#running-without-the-workshop-vm) with the instructor. They can finish import/drift with local state, but have not completed migration until the checks below pass.

```powershell
$workshopTools = "C:\Program Files\TerraformWorkshop"
Get-Content "$workshopTools\workshop.json"
Get-Content "$workshopTools\backend.lab05.hcl"
```

Read `storage_account_name` and `container_name` from that populated file. Replace the placeholder below with its real account name; do not include angle brackets:

```powershell
$stateStorageAccount = "<storage_account_name-from-backend.lab05.hcl>"
$stateContainer = "tfstate"
az storage container show --account-name $stateStorageAccount --name $stateContainer --auth-mode login
if ($LASTEXITCODE -ne 0) { throw "Backend access must work before migration." }
```

Confirm the container name matches the generated file. In the portal's Storage browser, check that `lab05.tfstate` is not another deployment's existing blob. If it exists, stop and establish ownership with the instructor before migration.

With Terraform idle, keep a private backup of the current local state:

```powershell
Copy-Item .\terraform.tfstate ".\terraform.tfstate.pre-migration-$(Get-Date -Format yyyyMMdd-HHmmss).backup"
Copy-Item .\backend.tf.example .\backend.tf
Copy-Item "$workshopTools\backend.lab05.hcl" .\backend.hcl
```

These copy commands assume a first migration; do not overwrite existing backend files on a resumed run. State and backups may contain sensitive data; keep them out of Git and shared chat.

Open the copied backend files and verify:

| Setting | Must refer to |
| --- | --- |
| `resource_group_name` | The **platform storage RG**, not your Lab 05 RG. |
| Account/container | Your supplied state storage, not another participant's. |
| `key` | `lab05.tfstate` for this starter. A solution uses a separate key and separate Azure resources. |
| Tenant/subscription | The approved backend context; on the VM, match its ARM environment variables. |
| Authentication on the VM | Both `use_msi = true` and `use_azuread_auth = true`. |

Now migrate:

```powershell
terraform init -migrate-state "-backend-config=backend.hcl"
```

Read the copy-state prompt. Answer `yes` only after confirming the destination. Do not substitute `-reconfigure` (it does not copy state), `-force-copy`, or an empty new state.

```powershell
terraform state list
terraform plan
az storage blob show --account-name $stateStorageAccount --container-name $stateContainer --name lab05.tfstate --auth-mode login --query "{name:name,size:properties.contentLength}" --output table
```

**Checkpoint:** all three addresses remain, the plan says no changes, and the remote blob exists with nonzero size. If state is empty or the plan wants to create resources again, **stop before apply**. The migration moved the record, not the RG/VNet.

## 7. Clean up using the owning state

Keep backend access working. If you stopped before migration, use this same directory's local state instead.

```powershell
terraform plan -destroy "-out=cleanup.tfplan"
terraform show cleanup.tfplan
```

Expect **2 managed resources to destroy: VNet + RG**. Inspect the Azure group for unrelated contents before continuing. The platform VM, storage and other labs must not be in this plan or group.

```powershell
terraform apply cleanup.tfplan
az group exists --name $resourceGroup
```

Expected: `false`. If AzureRM refuses deletion because unmanaged contents remain, inspect ownership; do not disable the safeguard. Keep state/backend files until cleanup is verified. Do not run a solution against these same resources under another state.

**You are done when you can explain:** why we did not full-apply first, what import recorded, why the tag changed back, and why migration did not recreate the VNet.
