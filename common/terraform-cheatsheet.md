<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Terraform Cheat Sheet

| Command | Purpose | What to observe |
| --- | --- | --- |
| `terraform init` | Install providers/modules and initialize the working directory | Selected versions and backend initialization |
| `terraform init -migrate-state -backend-config=backend.hcl` | Reinitialize after a backend change and offer to copy existing state | Confirm the source, destination, and state key before approving |
| `terraform fmt -check` | Check canonical formatting | No output and exit code 0 means formatted |
| `terraform validate` | Check syntax and internal references | `Success!` does not prove Azure will accept the design |
| `terraform plan -out main.tfplan` | Compare configuration, state, and provider results | `+`, `~`, `-`, and replacement indicators |
| `terraform show main.tfplan` | Inspect a saved plan | Exact proposed arguments and sensitive-value handling |
| `terraform apply main.tfplan` | Apply the reviewed plan | Resource progress and final outputs |
| `terraform output` | Read root outputs | Values intentionally exposed by the configuration |
| `terraform state list` | List tracked addresses | Resource and module addresses, including keyed instances |
| `terraform state show ADDRESS` | Inspect one state object | Provider-recorded attributes; state may be sensitive |
| `terraform destroy` | Plan and remove managed resources | Confirm the scope before approval |

Useful language forms:

```hcl
var.resource_group_name
local.name_prefix
azurerm_resource_group.this.name
azurerm_resource_group.this.location
module.network.subnet_ids
[for name, subnet in azurerm_subnet.this : subnet.id]
```

Each Azure lab owns a separate RG through a resource block, using `var.resource_group_name` and `var.location`. Data sources only read existing information; resources own lifecycle. Keep state and RGs separate per lab and per starter/solution. `destroy` removes the lab RG; never put unrelated resources in it.

On the workshop VM, run `& 'C:\Program Files\TerraformWorkshop\Connect-WorkshopAzure.ps1'` to initialize Azure CLI identity login and Terraform's direct managed-identity environment.

Lab 05 first creates only its RG through Terraform, then uses `terraform import azurerm_virtual_network.this "<vnet-id>"` to adopt a CLI-created VNet before the full apply. Its remote state is kept in the separate VM platform RG.
