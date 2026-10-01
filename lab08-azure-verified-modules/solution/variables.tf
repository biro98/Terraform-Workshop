# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new dedicated resource group owned only by this solution state."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group and its regional resources."
  type        = string
  default     = "swedencentral"
}
variable "unique_suffix" {
  description = "Personalized solution suffix, distinct from the starter deployment."
  type        = string
}
variable "management_cidr" {
  description = "Approved scoped source CIDR for application HTTPS; never an unrestricted source."
  type        = string
}
variable "subnets" {
  description = "Application, data, and private_endpoints subnet prefixes keyed by stable names."
  type        = map(object({ address_prefix = string }))
}
