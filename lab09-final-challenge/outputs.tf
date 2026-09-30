# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

# TODO: Output both VNet IDs, both subnet ID maps, peering IDs, the spoke route
# table ID, and the private DNS zone ID.
