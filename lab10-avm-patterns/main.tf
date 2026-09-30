# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# TODO: Follow INSTRUCTIONS.md to add locals, the spoke resource module,
# the connectivity pattern and two directional peerings. Do not apply this starter.
