# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new resource group owned only by this lab and state."
  type        = string
}
variable "unique_suffix" { type = string }

# TODO: Define typed string variables named vnet_name,
# vnet_address_space, subnet_name, and subnet_prefix.

variable "location" {
  description = "Azure region for this lab resource group and its regional resources."
  type        = string
}
