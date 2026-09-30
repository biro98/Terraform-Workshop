<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# One Windows workshop VM in your own subscription

Run **one host script**, [New-Workshop.ps1](New-Workshop.ps1), to deploy one private Windows VM. Its separate [bootstrap-windows.ps1](bootstrap-windows.ps1) runs through managed Azure VM Run Command and installs Git, VS Code (plus the HashiCorp Terraform extension), Terraform and Azure CLI.

There are no guest invitations, directory groups, rosters, identity mappings or pre-created lab resource groups. You sign in to Azure on the host with your own privileged account; inside the VM, Azure CLI and Terraform use its **system-assigned managed identity**. One local Windows administrator account is used to connect and work on the VM; no second credential is required.

## Prerequisites

- Windows, Linux or macOS host with PowerShell **7.2+**, Azure CLI and Bicep (`az bicep version`). On Linux/macOS, `chmod` must be available to protect temporary credentials. The deployed VM and its bootstrap remain Windows-only.
- Your own Azure subscription and permission to create resources, register providers and **assign roles at subscription scope**: for example Owner, or Contributor plus appropriately authorized Role Based Access Control Administrator. Contributor alone cannot complete provisioning. No Microsoft Graph or directory invitation permissions are needed.
- An allowed region, Windows Server 2022 Azure Edition image availability, VM quota and budget.
- Allow outbound downloads from Microsoft, GitHub, HashiCorp, VS Code Marketplace and Terraform Registry. NAT is not a content-filtering firewall.
- Verify Windows Server/RDS licensing for your intended desktop use.

### Important: subscription-wide managed identity power

| Principal | Role | Scope |
| --- | --- | --- |
| VM system-assigned managed identity | Contributor | **Entire selected subscription** |
| Same VM identity | Storage Blob Data Contributor | Its external state container only |

Subscription Contributor is intentional: the labs **create their own resource groups**, rather than receiving a pre-created RG. Any process/user on this VM can access its identity endpoint. It can create, modify and delete resources across the subscription, including the workstation platform. Use a dedicated personal training subscription without production resources, restrict VM access, and review inherited access. The identity is **not** granted Owner or RBAC Administrator and cannot create role assignments. Windows administrator rights do not change Azure RBAC. Labs that explicitly manage RBAC require a separate, deliberate privileged workflow; do not elevate this identity.

## Preview and deploy

From the repository root, in PowerShell 7:

```powershell
az login
$admin = Get-Credential -UserName "workshopadmin" -Message "Local Windows administrator for the VM"
$setup = @{
  SubscriptionId = "<your-subscription-guid>"
  Location = "swedencentral"
  AdminCredential = $admin
}
.\scripts\workshop-vm\New-Workshop.ps1 @setup -WhatIf
$access = .\scripts\workshop-vm\New-Workshop.ps1 @setup
$access
```

Alternatively, copy these four files into any single directory: [New-Workshop.ps1](New-Workshop.ps1), [platform.bicep](platform.bicep), [workstation.bicep](workstation.bicep), and [bootstrap-windows.ps1](bootstrap-windows.ps1). No repository checkout or fixed host path is required. The deployment script resolves dependencies beside itself, not from your current working directory. From that directory, use `& (Join-Path $PWD "New-Workshop.ps1") @setup` in PowerShell. Do not run the Windows bootstrap on your Linux/macOS host; the deployment runs it inside the VM.

Use a local username such as `workshopadmin`, not your email or `DOMAIN\username`. The script accepts 1-20 characters, starting with a letter, followed by letters, digits, underscores or hyphens; uppercase is allowed. Azure/Windows reserved names such as `admin`, `administrator` and `user` are rejected. The script checks only four password requirements: at least 8 characters, at least one uppercase letter, at least one number and at least one special character. It imposes no maximum length or additional password checks. Azure and Windows can still enforce their own provisioning policies; passing this local check does not guarantee Azure acceptance. Store this single credential in your password manager; do not reuse corporate credentials. Never pass passwords or tokens as CLI arguments, export plaintext credentials or enable transcript/debug logging during provisioning.

If retrying from an older two-account example, rebuild `$setup` using the example above; the removed `LearnerCredential` parameter must not remain in the splat. Username/password validation happens locally before any Azure calls.

Password errors list the specific failed checks without displaying the password. Rerunning with `@setup` keeps the stored credential, even if you later change `$admin`. To enter a different password, replace the credential in `$setup` explicitly, then preview again:

```powershell
$setup.AdminCredential = Get-Credential -UserName $setup.AdminCredential.UserName
.\scripts\workshop-vm\New-Workshop.ps1 @setup -WhatIf
```

`-WhatIf` validates credentials and previews the target without any Azure calls, sign-in, builds or writes. The real run asks for confirmation and uses the explicit subscription on every Azure operation; it discovers the tenant without changing your host CLI default subscription.

Defaults: `-WorkshopId workshop`, `-VmSize Standard_D2as_v5`, Terraform **1.14.5**, 127 GiB Standard SSD and daily shutdown at **19:00 UTC**. Optional `-TerraformVersion` accepts a tested newer 1.x release; `-ShutdownTime HHmm` changes UTC shutdown. Output defaults to a unique run directory under `TerraformWorkshop` in the host's temporary directory, discovered automatically without `LOCALAPPDATA`. The script prints the location of `access.json`; temporary storage may be cleared by the host. To retain it longer, set `-OutputDirectory` to a private, non-synchronized location outside the repository or standalone script directory. Relative output paths resolve against your current PowerShell directory.

Names: `rg-workshop-platform`, `workshop-vm`, and state container `tfstate`. One RG holds the VM and its supporting resources. No lab RGs are created. Reuse the same subscription, WorkshopId, location and administrator credential to retry. Foreign/legacy RGs are rejected; use a new WorkshopId rather than repurposing an old multi-VM deployment. Deployment is incremental, not cleanup of older resources. Preserve the administrator username and password: the username cannot change on an existing VM, and redeployment is not a password reset. Bootstrap reruns installers but does not create or reset local accounts. An older second account is not automatically removed or elevated. Interrupted runs can leave Azure resources; retry after resolving the reported failure.

## What is deployed

- [platform.bicep](platform.bicep): existing private VNet/NAT pattern, NSG allowing RDP **only from Bastion**, Bastion Basic, and state storage restricted to the desktop subnet using a service endpoint. There is **no VM public IP or public RDP**. State storage disables shared keys, requires TLS 1.2+, blocks public blobs, and retains versioning and seven-day soft delete.
- [workstation.bicep](workstation.bicep): exactly one Trusted Launch Windows VM/NIC, system-assigned identity, shutdown schedule, private state container and container-scoped data role. Managed Run Command embeds the separate bootstrap script; `treatFailureAsDeploymentFailure` surfaces bootstrap failures.
- Bootstrap installs machine-wide tools; verifies signed Microsoft/Git/VS Code installers, Terraform's published SHA-256, installer exit codes and all four tool versions; installs the Terraform extension and checks its exit code. Git, VS Code and Azure CLI use current stable releases; Terraform is pinned by the parameter. Live endpoints therefore require connectivity and may change. No Azure CLI login is run by SYSTEM during bootstrap.

The administrator password is an ARM `secureString` used only for VM provisioning. Bootstrap receives the username, not the password, and does not create an extra account. CLI arguments contain only the restricted parameter-file path. Before writing credentials, the per-run directory is restricted to the caller and SYSTEM on Windows, or to the owner (`chmod 700`) on Linux/macOS. Permission failures stop provisioning rather than writing unprotected credentials. Parameter files and compiled templates are deleted in `finally`. Abrupt process termination can leave sensitive files: inspect and remove that specific run directory before sharing your host.

## Connect and authenticate inside the VM

1. In your own Azure portal session, select the VM, **Connect > Bastion**, and enter the local administrator credential supplied during setup.
2. Open **Workshop PowerShell**. Its helper, `C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1`, runs `az login --identity --output none` as the signed-in workshop administrator and selects the subscription. No password, token or SYSTEM token cache is shared. Allow time for RBAC propagation and rerun the helper if needed.
3. Verify with `& 'C:\Program Files\TerraformWorkshop\verify-tools.ps1'`. Clone the repository yourself under `C:\Workshop`; never embed Git tokens in clone URLs. Open **VS Code - Terraform Workshop** for the shared Terraform extension.

The bootstrap sets machine environment defaults inherited by new terminals and VS Code:

```powershell
$env:ARM_USE_MSI = "true"
$env:ARM_USE_CLI = "false"
$env:ARM_USE_AZUREAD = "true"
$env:ARM_SUBSCRIPTION_ID = "<your-subscription-guid>"
$env:ARM_TENANT_ID = "<discovered-tenant-guid>"
```

Terraform uses MSI **directly**, independently of Azure CLI's login cache. The helper refreshes these settings in its current shell and clears competing ARM credentials. Restart already-open terminals/VS Code after provisioning. In any new terminal, run the helper if you also want Azure CLI login. Do not run lab instructions for interactive `az login`, service principals or guest tenant switching; do not override the subscription/tenant with unrelated provider/backend values.

### Lab 05: external state backend

Provisioning keeps state storage outside the lab resource groups, so destroying a lab does not destroy its backend. Password-free settings are returned as a PowerShell object and saved as `access.json` in the restricted host run directory:

`SubscriptionId`, `TenantId`, `PlatformResourceGroup`, `VmName`, `VmUsername`, `VmId`, `ManagedIdentityPrincipalId`, `BastionName`, `StorageAccountName`, `ContainerName`, `BackendKey`.

Inside the VM, the same backend coordinates are in `C:\Program Files\TerraformWorkshop\workshop.json`; a ready-to-use nonsecret backend configuration is alongside it. In **Lab05's Terraform working directory**, configure an empty `backend "azurerm" {}` block and use:

```powershell
terraform init -backend-config="C:\Program Files\TerraformWorkshop\backend.lab05.hcl"
```

The HCL supplies the external storage account, `tfstate` container, `lab05.tfstate` key, subscription/tenant, `use_msi = true` and `use_azuread_auth = true`. If migrating existing local state, use `terraform init -migrate-state` with the same backend config and review the prompt. Do not run Lab05's separate backend-creation steps or request storage keys/SAS. Storage data access works from the VM subnet, not your host. Use distinct keys for unrelated states.

## Validation and cleanup

Offline validation (no Azure account queries or deployments):

```powershell
az bicep build --file .\scripts\workshop-vm\platform.bicep --stdout | Out-Null
az bicep build --file .\scripts\workshop-vm\workstation.bicep --stdout | Out-Null
Invoke-Pester .\scripts\workshop-vm\tests\Workshop.Tests.ps1
```

Tests mock Azure CLI and cover offline preview, single-credential username/password validation, single-VM parameters, restricted secret files, subscription role scope, retries, failure cleanup and template/bootstrap contracts. They do not install tools or deploy resources. Live validation still requires successful deployment, Bastion login, administrator tool checks, MSI lab RG creation and Lab05 blob read/write.

Destroy each lab from its Terraform directory first. Export any state you need before removing the platform RG: that deletes the VM, Bastion, NAT and external backend. Also remove the managed identity's **subscription-scoped Contributor assignment** (use `ManagedIdentityPrincipalId` from `access.json`) with your privileged host account; deleting the VM can leave an orphaned role assignment. Recreating a deleted VM creates a new identity. Bastion, NAT and storage continue to cost money when the VM is shut down.
