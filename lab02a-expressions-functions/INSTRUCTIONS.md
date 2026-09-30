<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 02A Attendee Instructions

This lab runs locally and creates no Azure resources. Use `terraform console` to discover each expression before writing it in `main.tf`.

For command and state-safety conventions, see [Beginner: start here](../README.md#beginner-start-here); skip Azure authentication for this local-only lab.

## 1. Prepare

From the repository root in PowerShell, enter the lab folder itself, not a `starter/` or `solution/` subfolder. If coming from another lab, first run `Set-Location ..`; if already here, skip `Set-Location`. Copy the inputs only if you have not already personalized them.

```powershell
Set-Location .\lab02a-expressions-functions
Copy-Item terraform.tfvars.example terraform.tfvars
Get-Location
terraform init
terraform validate
```

Read `terraform.tfvars` and the validation rules in `variables.tf`. Keep the supplied data shape. No Azure login is needed. `main.tf` and `outputs.tf` initially contain only guidance comments, so successful validation or a no-change plan **does not mean the exercise is finished**.

The starter's README step numbers are stale: use [Build the calculated values](README.md#3-build-the-calculated-values), [Use terraform_data](README.md#4-use-terraform_data), and the checkpoints below.

## 2. Explore expressions interactively

Start the console:

```powershell
terraform console -var-file="terraform.tfvars"
```

Paste one expression at a time at the `>` prompt (do not type the `>`):

| Expression | Expected result with the example inputs |
| --- | --- |
| `trimspace(var.project_name)` | `"Payments Platform"` |
| `replace(lower(trimspace(var.project_name)), " ", "-")` | `"payments-platform"` |
| `lower(var.environment) == "prod" ? "prod" : "nonprod"` | `"nonprod"` |
| `cidrsubnet(var.base_cidr, var.subnet_newbits, 0)` | `"10.20.0.0/24"` |
| `cidrhost(cidrsubnet(var.base_cidr, var.subnet_newbits, 0), 4)` | `"10.20.0.4"` |
| `merge(var.extra_tags, { environment = lower(var.environment) })` | Includes `environment = "dev"` |

Use `type(...)` when unsure whether an expression returns a string, tuple, object, or map. Read nested calls from the inside out. Type `exit` when done.

## 3. Build locals incrementally

Open `main.tf` and add one `locals` block below the comments. Use these names so the later outputs can reference them:

1. `normalized_project_name`: the nested cleaning expression tested above.
2. `environment_tier`: the `prod`/`nonprod` conditional above.
3. `name_prefix`: use `join("-", [local.normalized_project_name, local.environment_tier, var.unique_suffix])`.
4. `subnets`: transform `var.subnet_names` with `for index, name in ...`; use `lower(replace(name, " ", "_"))` as each map key. Each value needs `address_prefix`, a representative host IP from `cidrhost(..., 4)`, and a `private_endpoint` boolean from `strcontains(lower(name), "private")`.
5. `routed_subnets`: filter the previous map with `if !subnet.private_endpoint` in a `for key, subnet in local.subnets` expression.
6. `common_tags`: merge `var.extra_tags` first and your required map last. For this exercise, use required `environment = lower(var.environment)` and `managed_by = "terraform"` tags.
7. `summary`: use `format` with the prefix and `length(local.subnets)` / `length(local.routed_subnets)` to describe both counts.

After each local:

```powershell
terraform fmt
terraform validate
```

For the subnet transformation, use a `for` expression with both the item and its index. Derive each map key from the subnet name, and derive each CIDR from the index. Keep all subnet properties together in the resulting object.

Checkpoint: evaluate each `local.<name>` in `terraform console -var-file="terraform.tfvars"`, then type `exit`. Expect a prefix of `payments-platform-nonprod-rv02a` (unless you changed the suffix), three subnet keys, CIDRs `10.20.0.0/24`, `10.20.1.0/24`, `10.20.2.0/24`, and only `application` and `data` in `routed_subnets`. The loop index starts at **0**. Reordering the source list changes calculated CIDRs; do not treat that as safe for deployed networks.

## 4. Store the calculated plan

Add `resource "terraform_data" "network_plan"` in `main.tf`. Its `input` object needs keys `name_prefix`, `subnets`, `routed_subnets`, `tags`, and `summary`, referencing the matching locals (`tags` references `local.common_tags`). See the resource pattern in [README.md](README.md#4-use-terraform_data). This stores data in local state, not Azure.

## 5. Expose outputs

In `outputs.tf`, add exactly the five requested outputs: `name_prefix`, `subnets`, `routed_subnets`, `common_tags`, and `summary`. Each `output "<name>"` block needs `value = local.<name>`. `environment_tier` is an intermediate local, not a required sixth output.

```powershell
terraform fmt
terraform fmt -check
terraform validate
terraform plan -out main.tfplan
terraform show main.tfplan
```

The first complete plan should show **1 to add, 0 to change, 0 to destroy**: `terraform_data.network_plan`, plus five outputs and no Azure resources. Regenerate the saved plan after any file edit.

## 6. Apply and inspect

```powershell
terraform apply main.tfplan
terraform output
terraform state list
terraform state show terraform_data.network_plan
```

A saved-plan apply does not ask for `yes`. Compare the stored input with the five outputs; state should contain exactly `terraform_data.network_plan`. Run `terraform plan` again and expect no changes.

## 7. Test validation and clean up

Temporarily set `environment = "qa"` in `terraform.tfvars`. Run `terraform plan` and expect `Environment must be dev, test, or prod.` Restore `"dev"` before continuing. To test merge precedence, temporarily add `managed_by = "manual"` in `extra_tags`: evaluate `local.common_tags` in the console and confirm it still says `"terraform"`. Exit the console, undo the test entry, and confirm a no-change plan. Do not apply either experiment.

```powershell
terraform destroy
terraform state list
```

Review the single-resource destroy plan and type `yes`. State should then be empty; no Azure resources are deleted. Keep `terraform.tfvars`, plans, and state out of Git.
