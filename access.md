<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Workshop Tools and Access

Deploy a dedicated Windows VM in your own approved training subscription using the [VM setup guide](scripts/workshop-vm/README.md). The VM uses a system-assigned managed identity for Azure CLI and Terraform. There is no guest invitation, cohort group or roster workflow.

## Required tools

| Tool | Requirement | Used by |
| --- | --- | --- |
| Terraform CLI | 1.14.5 or newer 1.x | All labs |
| Azure CLI | Installed by VM bootstrap | All except Lab 02A |
| VS Code + HashiCorp Terraform extension | Installed by VM bootstrap | All labs |
| Git | Installed by VM bootstrap | Lab 07; recommended throughout |
| GitHub account and browser | Repository access, branch/PR permissions and Actions enabled | Lab 07 |
| Internet access | Microsoft, HashiCorp, GitHub, VS Code Marketplace and Terraform Registry downloads | Tool setup and Azure labs |

PowerShell commands are used in the guides. Azure managed identity does not authenticate GitHub: use your own approved GitHub authentication for private repositories.

## Roles and subscription preparation

| Identity | Required access |
| --- | --- |
| Person running VM setup | Resource provisioning and role-assignment permissions in the target subscription, such as Owner or Contributor plus appropriately scoped Role Based Access Control Administrator |
| VM system-assigned managed identity | Contributor on the target subscription, allowing Terraform to create and remove lab RGs and workloads |
| VM system-assigned managed identity, Lab 05 | Storage Blob Data Contributor on its platform state container |
| Person connecting to the VM | Authorized access to the subscription's VM/Bastion resources and the VM's local Windows credentials |

Contributor alone cannot assign roles. Your personal Azure permissions are not inherited by the VM identity: setup must explicitly grant its roles. No Entra directory role or guest-management permission is needed by these scripts.

**Subscription-scoped Contributor is broad.** It includes other resources and the VM platform in that subscription. Use a dedicated training subscription and restrict who can access the VM. Setup uses one local Windows administrator credential; any process/user on the VM can potentially use its managed identity. The identity is not granted Owner or role-assignment privileges.

VM setup registers `Microsoft.Network`, `Microsoft.Storage`, `Microsoft.Compute` and `Microsoft.DevTestLab`. Lab AzureRM configurations disable automatic provider registration. Azure Policy, allowed regions, quotas, resource locks and network controls still apply.

## Azure access by lab

Each Azure lab creates a separate resource group using its `resource_group_name` and `location` inputs.

| Lab | Resources managed in its own RG |
| --- | --- |
| 01-04 | VNet, subnets and NSGs as applicable |
| 02A | None; local `terraform_data` and local state only |
| 05 | Terraform-created RG and CLI-created VNet subsequently imported into Terraform; drift and state migration |
| 06-07 | Lab networks; Lab 07's validation-only GitHub Actions example needs no Azure identity or secret |
| 08 | AVM VNet/subnets and root-owned NSG, rules and associations |
| 09 | Hub/spoke VNets, subnets, NSGs, routes, peering and private DNS zone/links |
| 10 (optional) | AVM connectivity/DNS patterns: hub/spoke, peerings, Basic Bastion, Standard NAT, two public IPs, DNS Resolver inbound endpoint and two private zones/four links; no firewall, VPN/ExpressRoute gateways or DDoS Protection Plan |

Lab 05's storage account/container are created by VM setup in the separate platform RG. Shared-key access is disabled. Backend authentication uses managed identity and Entra Blob authorization, not account keys. Keep this backend available until all state using it has been safely cleaned up.

## Preflight inside the VM

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
terraform version
az version
git --version
az account show --output table
$env:ARM_USE_MSI
$env:ARM_SUBSCRIPTION_ID
```

Copy each lab's example input file and choose a new lab-specific RG name, an allowed location and a unique suffix. Do not pre-create that RG with CLI. Lab 05 explicitly creates its RG through a one-time targeted Terraform apply before the VNet import exercise; follow its instructions rather than applying the full configuration first.

Before Lab 05, verify access to the platform Blob container. Before Labs 08-10, verify Registry and GitHub module downloads. A successful local `terraform validate` is not evidence that Azure permissions, policy, quota or networking will allow deployment.

Lab 10 additionally needs budget approval and regional availability/quota for
Bastion, Standard NAT Gateway (zone 1), public IPs and DNS Private Resolver.
Run it locally with an authorized sandbox user or on the supplied VM with its
existing identity. AzureRM and AzAPI use the selected authentication path; no extra
role assignment or change to the workshop VM network is required. All lab resources
are created in a new group, with local state and no dependency on earlier labs or
the platform storage account. Check `Microsoft.Network` registration as described
in the lab. Paid services continue billing until deletion completes. Follow the
lab's reviewed destroy and absence checks.

## Cleanup

Each lab's `terraform destroy` removes its RG and managed workloads. Never place other resources in that RG: deleting an Azure RG can remove contents outside Terraform's state. Use separate RGs for other labs and solution states, and never use the platform RG as a lab RG.

Destroy lab resources while state is still available. Only then review teardown of the VM/platform and its subscription role assignment. Do not commit local passwords, tokens, state, plans, populated `.tfvars`, backend settings or generated deployment outputs.
