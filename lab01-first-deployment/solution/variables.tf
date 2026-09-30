# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new resource group owned only by this solution and state."
  type        = string
}

variable "location" {
  description = "Azure region for the lab resources."
  type        = string
  default     = "swedencentral"
}

variable "unique_suffix" {
  description = "Short lowercase suffix that makes resource names unique."
  type        = string
}
