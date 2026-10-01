<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Terraform on Azure: Three-Day Workshop

This repository is a hands-on introduction to Terraform for Azure infrastructure and networking teams. Every lab is independent: start in any lab folder, copy `terraform.tfvars.example` to `terraform.tfvars`, complete the marked tasks, and work only with that folder's state.

## Beginner: start here

1. Open this repository folder in VS Code, then select **Terminal > New Terminal** and use **PowerShell**. Run `Get-Location` to check your current folder. If you are already inside a lab, `Set-Location ..` returns to the repository root.
2. Choose a lab below. Its **INSTRUCTIONS.md is the step-by-step path**; its README explains the concepts and provides reference material. Do not execute both documents from top to bottom as separate exercises.
3. Work in the lab's starter folder, not `solution`. Read each checkpoint before running the next command. Preserve the SPDX/MIT headers when editing files.
4. Copy the example inputs only on the first run. If `terraform.tfvars` already exists, edit it instead of overwriting it. Replace sample suffixes/group names with your own. `swedencentral` is an example region, not a guarantee that your subscription allows it.
5. Use the [VM or laptop authentication path](common/azure-authentication.md) appropriate to your machine. The VM helper and `az login --identity` do not work on an ordinary laptop. Lab 02A needs neither; Lab 07's static CI also needs no Azure login.
6. Complete the code TODOs before applying. Some incomplete starters pass validation because they contain only comments where resources should be. Compare the plan against the lab's expected resources, not just its exit code.
7. Run **one command at a time**. Stop if a command fails unexpectedly; PowerShell does not automatically stop a pasted sequence when a native command fails. Never run `apply` after a failed/unreviewed plan. Exceptions such as Lab 07's initial failures are explicitly labeled.

| Lab | Follow this guide | Main outcome |
| --- | --- | --- |
| 01 | [First deployment](lab01-first-deployment/INSTRUCTIONS.md) | Understand init, plan, apply and destroy. |
| 02 | [Variables and outputs](lab02-variables-outputs/INSTRUCTIONS.md) | Supply inputs and read deployment results. |
| 02A | [Expressions and functions](lab02a-expressions-functions/INSTRUCTIONS.md) | Transform values locally without Azure. |
| 03 | [Networking basics](lab03-networking-basics/INSTRUCTIONS.md) | Build explicit networking resources. |
| 04 | [Loops and data structures](lab04-loops-data-structures/INSTRUCTIONS.md) | Add resources through stable map keys. |
| 05 | [State, import and drift](lab05-state-drift-import/INSTRUCTIONS.md) | Adopt an existing VNet, fix drift, migrate state. |
| 06 | [Custom modules](lab06-custom-modules/INSTRUCTIONS.md) | Connect caller inputs, child resources and outputs. |
| 07 | [Enterprise practices](lab07-enterprise-practices/INSTRUCTIONS.md) | Repair defects and test a Pull Request workflow. |
| 08 | [Azure Verified Modules](lab08-azure-verified-modules/INSTRUCTIONS.md) | Compose a versioned module with security controls. |
| 09 | [Final challenge](lab09-final-challenge/INSTRUCTIONS.md) | Assemble and review a hub-and-spoke design. |
| 10 (optional) | [AVM networking patterns](lab10-avm-patterns/INSTRUCTIONS.md) | Compose connectivity and Private DNS patterns with Bastion, NAT and DNS Resolver; no firewall or VPN gateway. |

### What the commands mean

| Command | What happens |
| --- | --- |
| `terraform init` | Initialize this directory and install its providers/modules; follow Lab 05's separate instructions when migrating a backend. |
| `terraform fmt` / `fmt -check` | Format files / check formatting without editing. Use `-recursive` for child modules. |
| `terraform validate` | Check configuration consistency, not Azure permissions or whether every TODO is finished. |
| `terraform plan -out main.tfplan` | Preview and save proposed changes; this does not deploy resources. |
| `terraform show main.tfplan` | Read the saved plan before approving it. `+` creates, `~` updates, `-` deletes, and `-/+` replaces. |
| `terraform apply main.tfplan` | Execute that exact saved plan **without another yes/no approval prompt**. Review it first. |
| `terraform output` / `state list` | Read saved output values / addresses recorded in this directory's state. |
| `terraform plan -destroy -out cleanup.tfplan` | Save a deletion plan to review before `terraform apply cleanup.tfplan`. |

After any configuration/input/state change, create and review a **new** plan. Never reuse a pre-import plan or a plan from another folder. In fresh labs, unexpected deletions/replacements are a stop-and-check signal.

Keep each lab's state and backend settings until its cleanup is verified. Do not delete state to "reset" an exercise, import shared groups to bypass errors, or run a starter and solution against the same Azure resources. See [troubleshooting](common/troubleshooting.md) if you are resuming an earlier attempt.

## Schedule and lab order

| Day | Labs | Focus |
| --- | --- | --- |
| 1 | 01, 02, 02A | Workflow, HCL, variables, expressions, functions, locals, and outputs |
| 2 | 03-05 | Azure networking, `for_each`, structured data, drift, import, and Azure Blob state |
| 3 | 06-09 | Custom modules, enterprise delivery, AVM composition, and an advanced hub-and-spoke capstone |

[Lab 10](lab10-avm-patterns/README.md) is an optional follow-on challenge, outside
the core three-day schedule. Its fully guided instructions and Mermaid diagrams
show how an AVM pattern composes other modules. Bastion, NAT Gateway, public IPs
and DNS Resolver incur charges until deleted; get budget approval and complete
its explicit cleanup checks, or stop at the plan-only checkpoint.
It is a standalone sandbox exercise: run it locally or from the supplied VM,
with no earlier lab resources or shared storage/backend required.

Each Azure lab **creates and owns its own resource group**. Copy that lab's example inputs, choose a unique `resource_group_name`, set `location` to an allowed Azure region, and set `unique_suffix`. Never share a resource group between labs, participants, or starter and solution states. Lab 02A is local-only.

## Prerequisites

Review [access.md](access.md) before the workshop for the per-lab tool, Azure permission, storage RBAC, GitHub, and network-access requirements.

The [VM setup guide](scripts/workshop-vm/README.md) deploys one Windows VM into your own subscription. A deployment PowerShell script invokes a separate in-VM bootstrap script to install Git, VS Code, Terraform and Azure CLI. A system-assigned managed identity authenticates Azure operations from the VM; no guest invitations, cohort groups, roster or Entra device registration are part of this setup.

- Terraform CLI 1.14.5 or newer 1.x (validated with the instructor's installed 1.14.5; provider/module pins remain unchanged)
- Azure CLI
- An approved training subscription; the VM identity receives subscription-scoped Contributor so labs can create resource groups
- The person running VM setup needs resource provisioning and role-assignment permissions; Contributor alone cannot grant the VM identity its roles
- VS Code with the HashiCorp Terraform extension recommended
- Git for the enterprise workflow exercises

On the provisioned VM, open a new PowerShell terminal and authenticate before entering a lab:

```powershell
& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'
az account show --output table
```

The helper signs Azure CLI in with `az login --identity` and configures `ARM_USE_MSI`, `ARM_SUBSCRIPTION_ID` and `ARM_TENANT_ID` for Terraform. Terraform authenticates directly with managed identity, independently of the CLI token cache. See [authentication details](common/azure-authentication.md).

**Use a dedicated training subscription, not a shared production subscription.** The identity's Contributor role applies throughout the subscription, including the VM platform; it is not an isolation boundary between labs or users. Anyone able to run code on the VM can potentially use its identity. Do not commit credentials, state, populated inputs/backend files or environment-specific deployment outputs.

## Basic workflow

This is a command reference, **not a substitute for completing each lab's instructions**. In particular, follow Lab 05's import sequence and repair Lab 07 before planning. Run commands from one lab directory at a time:

```powershell
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
# Set your inputs and complete the lab's TODOs before continuing.
terraform init
terraform fmt -check
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
# Stop and review the saved plan before applying it.
terraform apply main.tfplan
terraform output
# Follow the lab's cleanup checkpoint before approving deletion.
terraform destroy
```

`init` installs pinned providers and modules. `plan` compares configuration, state, and Azure before proposing changes. Review the plan before `apply`; in a bank, plan and apply are commonly separated by Pull Request review and approval.

**Lab 05 exception:** first create only its resource group through Terraform, then create a VNet with Azure CLI and import it before the full apply, following [its instructions](lab05-state-drift-import/INSTRUCTIONS.md). Its remote backend is created separately by VM setup and uses managed-identity authentication. Lab 02A needs no RG or Azure credentials.

`destroy` deletes the lab's managed resource group and workloads. Azure resource-group deletion can also delete contents created outside that Terraform state; provider safeguards or locks may instead block deletion. Do not put unrelated resources into a lab RG. Other labs and the VM/backend platform remain separate. Use a different RG for a solution, or destroy the starter before switching; a separate directory or backend key alone does not isolate Azure resources.

## Existing deployments from earlier workshop versions

These labs replace the earlier shared, pre-created RG model. **Do not point the new managed RG resource at the old shared RG or import that RG into multiple states.**

Prefer a fresh working directory/state and new RG name per lab. Keep the old configuration and state available to review and destroy old workloads safely; do not delete or overwrite state as a migration shortcut. Back up state securely before making changes.

If retaining an existing deployment, review its actual state and ownership with the subscription administrator before applying. Changing the RG name can replace workloads, and adopting an existing RG makes its eventual deletion part of that state's cleanup. The old VM platform and any former guest/group role assignments are not removed by the new setup script; review and retire them separately when no longer needed.

## Repository layout

- `lab01` through `lab10`, including focused Lab 02A and optional Lab 10: student exercises and independent Terraform roots
- Reference solutions for Labs 01, 02, 02A, 03, 04, 05, 06, 07 and 08 are published. Solutions for Labs 09 and 10 may be supplied locally by the instructor. Use the starter instructions first; each solution is an independent Terraform root/state, not an extension of the starter.
- `common/`: optional reading only; no lab depends on it

Lab 02A is a no-cost Terraform language exercise using `terraform console` and the built-in `terraform_data` resource. Labs 08 and 09 are designed for a network platform team. Lab 08 introduces composition between a pinned Azure Verified Module and root-owned security controls. Lab 09 applies the pattern to AVM-managed hub and spoke VNets, bidirectional peering, subnet NSGs, centralized route intent, and shared private DNS without deploying AKS or a paid network appliance.

Do not run Terraform from the repository root. Do not commit `terraform.tfvars`, plan files, `.terraform/`, or state. Azure Policy, private networking standards, approved modules, and CI security checks remain governance layers around Terraform rather than substitutes for review.

## License

This workshop is licensed under the [MIT License](LICENSE), copyright (c) 2026 biro98. Repository files include SPDX copyright and MIT license headers in their format's comment syntax. Keep these notices when redistributing the workshop.

External tools, Terraform providers, and modules downloaded by the workshop retain their own licenses.
