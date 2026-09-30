# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "name_prefix" {
  value = local.name_prefix
}

output "subnets" {
  value = local.subnets
}

output "routed_subnets" {
  value = local.routed_subnets
}

output "common_tags" {
  value = local.common_tags
}

output "summary" {
  value = local.summary
}