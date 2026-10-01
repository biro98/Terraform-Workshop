# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

locals {
  prefix          = "tf-lab09-${var.unique_suffix}"
  hub_vnet_name   = "vnet-hub-${local.prefix}"
  spoke_vnet_name = "vnet-spoke-${local.prefix}"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_security_group" "spoke" {
  for_each = var.spoke_subnets

  name                = "nsg-${replace(each.key, "_", "-")}-${local.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "management_https" {
  name                        = "AllowManagementHttps"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.management_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.spoke["application"].name
}

resource "azurerm_route_table" "spoke" {
  name                          = "rt-spoke-${local.prefix}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false
  tags                          = var.tags
}

resource "azurerm_route" "default_to_hub" {
  name                   = "default-to-central-appliance"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.spoke.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.hub_virtual_appliance_ip
}

module "hub" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = local.hub_vnet_name
  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = var.hub_address_space
  subnets = {
    for name, subnet in var.hub_subnets : name => {
      name             = "snet-${replace(name, "_", "-")}"
      address_prefixes = [subnet.address_prefix]
    }
  }
  tags             = var.tags
  enable_telemetry = false
}

module "spoke" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = local.spoke_vnet_name
  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = var.spoke_address_space
  subnets = {
    for name, subnet in var.spoke_subnets : name => {
      name                              = "snet-${replace(name, "_", "-")}"
      address_prefixes                  = [subnet.address_prefix]
      private_endpoint_network_policies = subnet.private_endpoint ? "Disabled" : "Enabled"
      network_security_group            = { id = azurerm_network_security_group.spoke[name].id }
      route_table                       = subnet.route_via_hub ? { id = azurerm_route_table.spoke.id } : null
    }
  }
  tags             = var.tags
  enable_telemetry = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.hub.name
  remote_virtual_network_id    = module.spoke.resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [module.hub, module.spoke]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.spoke.name
  remote_virtual_network_id    = module.hub.resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [module.hub, module.spoke]
}

resource "azurerm_private_dns_zone" "this" {
  name                = var.private_dns_zone
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = {
    hub   = module.hub.resource_id
    spoke = module.spoke.resource_id
  }

  name                  = "link-${each.key}-${local.prefix}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

# Retain address history; physical name changes still require plan review.
moved {
  from = module.hub_virtual_network
  to   = module.hub
}

moved {
  from = module.spoke_virtual_network
  to   = module.spoke
}

moved {
  from = azurerm_network_security_group.this
  to   = azurerm_network_security_group.spoke
}
