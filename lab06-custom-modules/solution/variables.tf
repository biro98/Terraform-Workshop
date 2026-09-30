# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new resource group owned only by this solution and state."
  type        = string
}
variable "location" {
  type    = string
  default = "swedencentral"
}
variable "unique_suffix" {
  type = string
}
variable "subnets" {
  type = map(object({ address_prefix = string }))
}
