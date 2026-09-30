# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new resource group owned only by this lab and state."
  type        = string
}

variable "management_source_cidr" {
  type = number # INTENTIONAL ISSUE: should be string.
}

# INTENTIONAL ISSUE: unique_suffix is referenced but not declared.

variable "location" {
  description = "Azure region for this lab resource group and its regional resources."
  type        = string
}
