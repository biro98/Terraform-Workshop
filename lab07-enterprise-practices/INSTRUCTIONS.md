<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 07 Attendee Instructions

**Goal:** repair a deliberately broken network configuration and write a GitHub Actions YAML workflow for automatic checks. Writing the YAML and running its Terraform checks locally are required; installing it in GitHub and opening a Pull Request are optional. Initial failures are part of the exercise, not evidence that you broke your environment.

Read the [beginner conventions](../README.md#beginner-start-here). This guide separates **local static checks**, **GitHub CI**, and **Azure deployment**. Static checks need provider downloads/internet, but no Azure credentials. Only the final plan/apply needs Azure access.

## 1. Open the starter and record the initial failures

From the repository root in PowerShell:

```powershell
Set-Location .\lab07-enterprise-practices
Get-Location
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
Select-String -Path .\*.tf -Pattern "INTENTIONAL ISSUE"
terraform fmt -check
terraform init -backend=false
terraform validate
```

Run commands one at a time and read the output. Work here, **not in `solution`**.

- `fmt -check` should report the poorly formatted file without changing it.
- `init` installs providers; it may succeed before the repairs and is not a security check.
- `validate` should report undeclared `unique_suffix` and the nonexistent VNet reference. It does not necessarily report every design/input defect.

Write down which failures are expected. Download, certificate or authentication failures are not intentional exercise defects; use [troubleshooting](../common/troubleshooting.md). Do not run `apply`.

## 2. Repair versions and variable declarations

In [terraform.tf](terraform.tf):

1. Inside the existing `terraform { ... }` block, add `required_version = ">= 1.14.5, < 2.0.0"`.
2. Inside its existing `required_providers` -> `azurerm` block, retain the source and add `version = "~> 4.0"`.

The first constraint accepts your Terraform 1.14.5 and newer 1.x versions. The second keeps AzureRM on major version 4. Do not add duplicate Terraform/provider blocks.

In [variables.tf](variables.tf):

1. Change `management_source_cidr` from `type = number` to `type = string`: a value like `"10.200.0.0/24"` is CIDR text, not a number.
2. Declare the missing suffix:

   ```hcl
   variable "unique_suffix" {
     type = string
   }
   ```

3. Keep the existing `resource_group_name` and `location` inputs.

```powershell
terraform init -backend=false -upgrade
terraform validate
```

`-upgrade` is deliberate here to reselect a provider under the newly repaired constraint. The bad VNet reference will still fail validation until section 3. Retain the dependency lock file during the lab; do not delete it to hide an error.

## 3. Repair the network configuration

Edit [main.tf](main.tf). Keep its existing resource blocks and labels. Change the following arguments:

| Resource/block | Argument | Correct expression |
| --- | --- | --- |
| VNet `this` | `name` | `"vnet-tf-lab07-${var.unique_suffix}"` |
| VNet `this` | `address_space` | `["10.7.0.0/16"]` |
| Subnet `application` | `virtual_network_name` | `azurerm_virtual_network.this.name` |
| Subnet `application` | `address_prefixes` | `["10.7.1.0/24"]` |
| NSG's `Allow-Management` rule | `protocol` | `"Tcp"` |
| Same rule | `destination_port_range` | `"443"` |
| Same rule | `source_address_prefix` | `var.management_source_cidr` |

**Change both CIDRs.** The starter VNet is `10.7.0.0/24`; just changing the subnet to `10.7.1.0/24` would still leave it outside the VNet. The corrected `/16` contains the subnet's `/24`.

Keep `source_port_range = "*"`: client source ports are not the destination service port. Keep the rule's inbound direction, allow action and priority 100.

An NSG does nothing to this subnet until associated with it. After repairing the eight labeled issues, add this required wiring at the end of [main.tf](main.tf):

```hcl
resource "azurerm_subnet_network_security_group_association" "application" {
  subnet_id                 = azurerm_subnet.application.id
  network_security_group_id = azurerm_network_security_group.this.id
}
```

Keep the root RG and its input-based name/location. Then:

```powershell
terraform fmt
terraform fmt -check -recursive
terraform validate
```

**Checkpoint:** no formatting differences and `Success! The configuration is valid.` All eight items in the [README checklist](README.md#tasks) are addressed, and the association exists.

This narrows the **custom management rule**. Azure's default NSG rules still exist; it is not a complete "only HTTPS is allowed" policy. No VM or listening service is deployed, so a browser connectivity test is not a lab success criterion.

## 4. Complete the credential-free CI template

CI means continuous integration: automatic checks of a proposed code change. Open [pipeline-example.yml](pipeline-example.yml), retain the supplied workflow name, read-only permission, job, checkout, Terraform 1.14.5 setup and working directory.

For TODO 1, replace the empty `on:` entry with:

```yaml
on:
  pull_request:
    paths:
      - "lab07-enterprise-practices/**"
      - ".github/workflows/terraform-lab07-ci.yml"
  workflow_dispatch:
```

The second path makes edits to the workflow itself trigger checks too. Manual dispatch is normally available in GitHub's UI once the workflow is on the default branch; the optional example in section 5 uses a Pull Request for the first test.

Replace TODOs 2-4 with these entries under `steps`, aligned with the existing `- uses:` entries (six spaces before each `- name`):

```yaml
      - name: Check Terraform formatting
        run: terraform fmt -check -recursive

      - name: Initialize without backend
        run: terraform init -backend=false

      - name: Validate Terraform configuration
        run: terraform validate
```

Use spaces, not tabs. `-backend=false` avoids remote-state authentication during initialization; it does not make a future plan/apply credential-free.

**Checkpoint:** no Azure login step, secrets, `plan`, `apply`, or input-file upload. Formatting and validation need no real input values.

Run the three commands from your completed YAML locally, from the Lab 07 directory:

```powershell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Explain the triggers, working directory, permissions, and each step to the instructor.
Local Terraform checks do not validate GitHub's YAML execution, but together with
reviewing the completed YAML they satisfy this lab's required pipeline exercise.
No GitHub repository, runner provisioning, push, or PR is required.

## 5. Optional example: Install the workflow and test it on a Pull Request

**Skip this entire section and continue to section 6 if GitHub Actions is unavailable
or the instructor is not running a live CI demonstration.** Completing section 4
is sufficient; a green PR check is not required to complete the lab.

For this optional example, you need an instructor-approved repository/fork with
branch-push permission, GitHub Actions enabled, and access to a runner. The template
uses GitHub-hosted `ubuntu-latest`, not a self-hosted runner you must provision;
availability still depends on repository/organization policy and usage limits.
If unavailable, leave the completed YAML in the lab folder and record CI as not run.

From the Lab 07 directory:

```powershell
New-Item -ItemType Directory -Force ..\.github\workflows
Copy-Item .\pipeline-example.yml ..\.github\workflows\terraform-lab07-ci.yml
```

If that destination already exists, inspect it before replacing it. GitHub ignores a workflow left only inside the lab directory. After later template edits, copy it again so the installed workflow matches.

Move to the repository root for **Git commands only**:

```powershell
Set-Location ..
git status --short
git remote -v
git switch -c lab07-ci-practice
git add -- lab07-enterprise-practices/main.tf lab07-enterprise-practices/variables.tf lab07-enterprise-practices/terraform.tf lab07-enterprise-practices/pipeline-example.yml .github/workflows/terraform-lab07-ci.yml
git diff --cached
```

Use a new branch name if this one already exists. **Review staged files before committing.** Only your Lab 07 repairs and workflow should be included. Do not use `git add .` or force-add ignored inputs/state. If unrelated work was already staged, stop and separate it with the instructor.

```powershell
git commit -m "Complete Lab 07 repairs and static CI"
```

Confirm the intended remote from `git remote -v`, then replace the placeholder before running:

```powershell
git push -u <your-approved-remote> lab07-ci-practice
```

In that GitHub repository, choose **Compare & pull request**, confirm the intended base branch, and create the PR. Open its **Checks** tab; find workflow **Lab 07 Terraform CI**, job **validate**, and inspect each step.

For the fail/fix demonstration:

1. On this same branch, remove spaces around one `=` in an assignment in [main.tf](main.tf), without changing the value.
2. Run `terraform fmt -check` from the Lab 07 directory; it must fail.
3. Stage only that file, commit, and push this deliberate formatting change. Watch the PR's formatting step fail.
4. Run `terraform fmt` from the Lab 07 directory; then repeat `fmt -check` and `validate`.
5. Stage only the corrected file, commit, and push again. Wait for the **latest commit's** checks to pass. Do not merge the deliberately failing revision.

If the workflow is skipped or awaiting approval, check Actions policy/PR path filters with the instructor rather than adding credentials. Static CI does not prove CIDR design, permissions or Azure security.

## 6. Prepare inputs and review a local Azure plan

If you skipped section 5, you are already in the Lab 07 directory; stay there.
Only if you moved to the repository root for the optional Git commands, return with:

```powershell
Set-Location .\lab07-enterprise-practices
```

On the workshop VM, run `& "C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1"`, then `az account show --output table`. On a laptop use [workstation authentication](../common/azure-authentication.md#running-without-the-workshop-vm), not VM identity login.

Edit your copied `terraform.tfvars`:

```hcl
resource_group_name    = "rg-tf-lab07-u01"
location               = "swedencentral"
unique_suffix          = "u01"
management_source_cidr = "10.200.0.0/24"
```

Personalize the group/suffix; use an approved region. The management range is a training example, not automatic access from your laptop. Use the instructor-approved management source and never broaden it to `*` or `0.0.0.0/0` to make a test pass. Do not share a group with another lab, solution state or the platform.

```powershell
terraform plan -out main.tfplan
terraform show main.tfplan
```

**Checkpoint for a fresh deployment:** **5 to add, 0 to change, 0 to destroy**: RG, VNet, subnet, NSG, and subnet/NSG association. Check both CIDRs, the suffixed names, TCP/443, source CIDR and association. If counts differ or any replacement appears, stop and investigate existing state/configuration.

## 7. Apply locally, then clean up

Only after the repaired plan is reviewed:

```powershell
terraform apply main.tfplan
terraform state list
terraform output vnet_id
terraform plan
```

Expect five managed state addresses and `No changes.` Regenerate and review the plan if any HCL/input changed since planning. GitHub CI never applies this deployment.

For cleanup:

```powershell
terraform plan -destroy -out cleanup.tfplan
terraform show cleanup.tfplan
```

Confirm five managed deletions in this lab only and no unrelated contents in its RG. Then:

```powershell
terraform apply cleanup.tfplan
az group exists --name "rg-tf-lab07-u01"
```

Use your actual group name; expect `false`. Group deletion can delete other contents too. If AzureRM blocks it, investigate instead of disabling the safeguard. Preserve platform/backend resources and other labs, and never commit state, plans or private inputs.

**You are done when:** local checks pass, the pipeline YAML is complete and you can explain its steps, the reviewed Azure deployment is verified/cleaned up, and you can explain why production CD additionally needs remote state, OIDC, scoped permissions and approval before apply. Installing the workflow and opening a PR are optional; if you try section 5, record whether its latest check passed or was not run.
