# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "name" {
  type = string
}
variable "location" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "address_space" {
  type = list(string)
}
variable "subnets" {
  type = map(object({ address_prefix = string }))
}
