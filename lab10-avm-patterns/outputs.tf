# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  description = "Dedicated resource group owned by this lab."
  value       = azurerm_resource_group.this.name
}

# TODO: Add the network, platform-service and DNS outputs from INSTRUCTIONS.md.
