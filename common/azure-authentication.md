<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Azure Authentication for the Labs

## On the workshop VM: managed identity

The [VM deployment script](../scripts/workshop-vm/README.md) enables a system-assigned managed identity and grants it the roles required for these labs. The bootstrap installs the tools and an authentication helper.

Run this in your own PowerShell terminal on the provisioned VM:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

The helper selects the configured subscription and sets up two independent authentication paths:

- **Azure CLI:** `az login --identity` signs in as the VM identity, not your personal account.
- **Terraform AzureRM provider:** `ARM_USE_MSI=true`, `ARM_SUBSCRIPTION_ID` and `ARM_TENANT_ID` select direct managed-identity authentication. Terraform does not depend on a prior CLI login or its token cache.

The provider blocks contain no credentials. For this system-assigned identity, do not supply a client secret or a user-assigned identity client ID. Remove stale credential overrides from previous experiments before authenticating.

The helper must run in the terminal where you will use Terraform. Starting a separate PowerShell process to set environment variables does not update the parent terminal. Open a fresh terminal after bootstrap to pick up machine environment settings.

Managed identity works from its assigned Azure VM, not from your laptop. The VM does not need Entra device registration for this workload authentication. Your personal portal/VM access is separate and can still be subject to Conditional Access. A TLS certificate-trust or proxy problem must still be fixed; changing identities does not repair certificate validation.

## Permissions and resource ownership

The VM identity receives subscription-scoped Contributor because every Azure lab creates its own RG. This is intentionally a training-subscription model, not RG-scoped isolation. Anyone able to run code on the VM may use that identity's permissions. The deployment caller must be allowed to grant roles; creating a VM successfully does not prove that permission.

Automatic AzureRM provider registration is disabled in the labs. VM setup preregisters the required providers. Do not grant the VM identity Owner to fix registration or authorization errors.

## Lab 05 backend

The backend authenticates separately from the AzureRM provider. Use the Lab 05 backend examples with `use_msi = true` and `use_azuread_auth = true`, plus the correct platform storage account, container, tenant and subscription.

The identity needs Storage Blob Data Contributor on that container and network access to the storage account. Subscription Contributor alone does not grant Entra Blob data access. VM setup creates this assignment; allow for RBAC propagation before migrating state. Keep backend resources outside the lab RG so lab cleanup does not delete its own state.

## Running without the workshop VM

From an approved, compliant workstation, interactive Azure CLI user authentication is also possible for the AzureRM labs:

```powershell
az login
az account set --subscription "<your-training-subscription-id>"
if ($LASTEXITCODE -ne 0) { throw "Could not select the training subscription." }
$env:ARM_USE_MSI = "false"
$env:ARM_SUBSCRIPTION_ID = az account show --query id --output tsv
if ($LASTEXITCODE -ne 0) { throw "Could not read the subscription." }
```

Clear any unrelated client credentials and tenant overrides. Your user needs permissions to create the lab RGs. Lab 05 additionally requires a reachable backend with Blob data access and user-authentication settings (`use_msi = false`, `use_cli = true`, `use_azuread_auth = true`); the VM platform storage firewall is configured for its desktop subnet, not arbitrary laptops. Do not weaken the firewall merely to use this alternative.

For CI/CD deployment, use a separate approved workload identity with federation and scoped roles. Lab 07's included pipeline only validates Terraform; it does not deploy Azure resources.

References: [Terraform managed-identity authentication](https://learn.microsoft.com/azure/developer/terraform/authenticate/authenticate-to-azure-with-managed-identity-for-azure-services), [Azure CLI managed identity sign-in](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-managed-identity), [AzureRM backend authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm).
