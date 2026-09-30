# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "project_name" {
  description = "Human-readable workload name to normalize for Azure naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], lower(var.environment))
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "unique_suffix" {
  description = "Short suffix that makes names unique."
  type        = string
}

variable "base_cidr" {
  description = "Address space from which subnet prefixes are calculated."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.base_cidr))
    error_message = "base_cidr must be a valid IPv4 CIDR."
  }
}

variable "subnet_newbits" {
  description = "Additional prefix bits used to calculate each subnet."
  type        = number
  default     = 8
}

variable "subnet_names" {
  description = "Ordered subnet names used to derive stable map keys and CIDRs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_names) > 0 && length(distinct(var.subnet_names)) == length(var.subnet_names)
    error_message = "Provide at least one subnet name, and do not repeat names."
  }
}

variable "extra_tags" {
  description = "Additional tags merged with the required lab tags."
  type        = map(string)
  default     = {}
}