# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "swedencentral"
}
variable "unique_suffix" {
  description = "Unique naming suffix."
  type        = string
}
variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}
variable "vnet_name" {
  description = "Virtual network name."
  type        = string
}
variable "vnet_address_space" {
  description = "Virtual network CIDR."
  type        = string
}
variable "subnet_name" {
  description = "Subnet name."
  type        = string
}
variable "subnet_prefix" {
  description = "Subnet CIDR."
  type        = string
}
