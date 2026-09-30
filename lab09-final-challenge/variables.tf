# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

variable "resource_group_name" {
  description = "Name of the new resource group owned only by this lab and state."
  type        = string
}

# TODO: Define unique_suffix, hub and spoke address spaces, a hub
# subnet map, private DNS zone, management CIDR, central appliance IP, tags,
# and a structured spoke subnet map. Each spoke subnet must declare its CIDR,
# whether it hosts private endpoints, and whether it routes through the hub.

variable "location" {
  description = "Azure region for this lab resource group and its regional resources."
  type        = string
}
