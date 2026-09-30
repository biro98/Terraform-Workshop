# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new resource group owned only by this lab and state."
  type        = string
}
variable "unique_suffix" {
  type = string
}
variable "subnets" {
  type = map(object({ address_prefix = string }))
}

variable "location" {
  description = "Azure region for this lab resource group and its regional resources."
  type        = string
}
