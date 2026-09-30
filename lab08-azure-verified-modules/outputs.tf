# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

# TODO: Output the AVM resource_id, its complete subnets output, and the
# application NSG ID owned by this root.
