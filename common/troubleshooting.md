<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Troubleshooting

## Unsupported Terraform Core version

Run `terraform version`, then read `required_version` in the current root's `terraform.tf`. An exact pin such as `= 1.14.3` rejects 1.14.5 even though both are 1.14 patch releases. This is separate from the AzureRM provider version; `terraform init -upgrade` does not upgrade Terraform itself.

The starter labs support 1.14.5 or newer 1.x; some reference solutions retain exact workshop pins. For instructor-approved local use with 1.14.5, create `local_version_override.tf` in the **same folder where you run Terraform**:

```hcl
# Local compatibility override; keep the shared workshop version pin unchanged.
terraform {
  required_version = "~> 1.14.0"
}
```

This accepts 1.14.x, not 1.15+. The repository ignores `*_override.tf`; do not force-add the file. Keep provider constraints unchanged, then rerun `terraform init` and `terraform validate`. A local override is not distributed by Git and is not a fix for unsupported features in a different Terraform release.

## Wrong folder, missing inputs, or unexpected plan counts

Run `Get-Location`: Terraform commands belong in the lab root, not the repository root, `solution`, or a child module directory. Follow the lab's expected counts only for a fresh deployment; an existing deployment should normally produce no changes until you edit it.

If Terraform prompts for an input unexpectedly, check that you copied and edited the example into `terraform.tfvars` in this same directory. Do not guess a group name at the prompt. A successful `validate` can still mean a starter is unfinished: comments/TODOs do not create resources.

After a failed plan, do not apply an older saved plan. Fix the cause, generate a fresh plan, and review it. If ownership is unclear, retain state and ask the instructor; do not remove state or import a shared resource to make the error disappear.

## Wrong subscription

Run the installed `Connect-WorkshopAzure.ps1` helper in your current VM terminal, then `az account show --output table`. Check `$env:ARM_SUBSCRIPTION_ID` and `$env:ARM_TENANT_ID` as well: Terraform's managed-identity settings are independent of the Azure CLI account selection.

Do not switch to a different subscription unless the identity has explicitly approved access there. Your personal subscription permissions are not inherited by the VM identity.

## Name or CIDR conflict

Use a new, unique RG per lab and per state, keep lab-qualified resource names, and confirm that subnet prefixes do not overlap within a VNet. Never apply starter and solution to the same RG under separate states. Lab 09's canonical private DNS zone name is not affected by the suffix: use different RGs or destroy the active deployment before switching roots.

If Terraform says an RG already exists and must be imported, stop and check ownership. Do not import a shared RG merely to get past the error. Prefer a new lab RG name; see the [migration guidance](../README.md#existing-deployments-from-earlier-workshop-versions).

## Provider or module initialization error

Run `terraform init -upgrade` only when intentionally evaluating newer allowed versions. Keep the lock file during a lab session so every command uses the same selections.

## Authorization failure

Read the denied action, principal and scope. Verify that the VM's system-assigned identity has its intended subscription Contributor assignment. Creating new RGs requires subscription-level authorization; an assignment on an existing RG cannot authorize creation of a sibling RG. Do not respond by granting Owner broadly.

The lab RG is expected to be absent before its first apply. Confirm that its Terraform resource block is present and completed; do not create the RG manually. Lab 05 creates it through a one-time targeted Terraform apply before the CLI VNet import exercise.

If a provider is unregistered, have the subscription administrator register it. For Lab 05 storage failures, check the container-scoped Blob data role, backend MSI/Entra settings and desktop network access. Role changes may take several minutes to propagate.

## Managed identity or certificate sign-in failure

First confirm where you are running: `az login --identity` and the workshop helper are for the provisioned Azure VM, not an ordinary laptop. For an approved workstation, follow the separate [user-login instructions](azure-authentication.md#running-without-the-workshop-vm). Do not copy the VM's backend MSI flags to a laptop.

Use `az login --identity` on the VM, not interactive `az login`. Check that the VM identity is enabled, its metadata endpoint is reachable and no proxy intercepts that endpoint. Run the helper again in your own Windows administrator terminal; a bootstrap login under SYSTEM does not establish your CLI session.

User Conditional Access requirements do not apply to this managed-identity token flow, but they can still govern your own portal/Bastion sign-in. An actual TLS certificate validation failure requires the correct trusted certificates/proxy configuration; never disable certificate verification.

## State lock or interrupted command

Confirm no other Terraform process is active before considering `terraform force-unlock`. Never remove a lock merely to bypass another deployment. Local state has limited concurrency protection; enterprise remote state in Azure Blob Storage provides centralized locking.

## Cleanup failure

Run `terraform plan -destroy` to inspect the scope, then `terraform destroy`. If Azure Policy created related resources, identify ownership before deleting anything manually.

The lab RG is now a managed resource and is expected to be deleted. Confirm it contains only this lab's resources before proceeding. The AzureRM provider may block deletion when unexpected contents remain; inspect ownership rather than disabling that safeguard. Other lab RGs and the VM platform/backend must remain intact.

For older shared-RG states, stop and follow the [existing-deployment migration guidance](../README.md#existing-deployments-from-earlier-workshop-versions) before applying or destroying with the new configuration.
