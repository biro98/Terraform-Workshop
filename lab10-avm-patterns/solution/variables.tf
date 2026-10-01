# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "New dedicated Lab 10 resource group owned only by this state."
  type        = string
}

variable "location" {
  description = "Approved region supporting Bastion, Standard NAT Gateway and Private DNS Resolver."
  type        = string
  default     = "swedencentral"
}

variable "unique_suffix" {
  description = "Short lowercase suffix identifying your Lab 10 deployment."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.unique_suffix))
    error_message = "Use 2-8 lowercase letters or digits."
  }
}

variable "private_dns_zones" {
  description = "Stable service keys mapped to canonical Private Link DNS zone names."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to lab resources."
  type        = map(string)
  default     = {}
}
