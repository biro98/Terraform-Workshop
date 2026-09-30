# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "vnet_id" {
  value = module.network.vnet_id
}
output "subnet_ids" {
  value = module.network.subnet_ids
}
