# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "subnet_ids" {
  value = { for name, subnet in azurerm_subnet.this : name => subnet.id }
}
