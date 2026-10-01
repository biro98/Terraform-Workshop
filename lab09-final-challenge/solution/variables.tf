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
variable "hub_address_space" {
  description = "Hub VNet CIDRs, non-overlapping with the spoke."
  type        = list(string)
}
variable "spoke_address_space" {
  description = "Spoke VNet CIDRs, non-overlapping with the hub."
  type        = list(string)
}
variable "management_cidr" {
  description = "Approved scoped source CIDR for application HTTPS; never an unrestricted source."
  type        = string
}
variable "hub_virtual_appliance_ip" {
  description = "Simulated next-hop IP inside the hub shared-services subnet; no appliance is deployed."
  type        = string
}
variable "private_dns_zone" {
  description = "Canonical private DNS zone linked to both VNets."
  type        = string
}
variable "tags" {
  description = "Tags applied to the resource group and taggable lab resources."
  type        = map(string)
  default     = {}
}
variable "hub_subnets" {
  description = "Hub subnet prefixes keyed by stable shared-services and management names."
  type = map(object({
    address_prefix = string
  }))
}
variable "spoke_subnets" {
  description = "Spoke subnet prefixes and flags; private endpoints must bypass the simulated route."
  type = map(object({
    address_prefix   = string
    private_endpoint = bool
    route_via_hub    = bool
  }))
}
