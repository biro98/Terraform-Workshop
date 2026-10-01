# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_network_security_group" "application" {
  name                = "nsg-application-tf-lab08-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
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
  network_security_group_name = azurerm_network_security_group.application.name
}

module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = "vnet-tf-lab08-${var.unique_suffix}"
  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = ["10.8.0.0/16"]
  subnets = {
    for name, subnet in var.subnets : name => {
      name                              = "snet-${replace(name, "_", "-")}"
      address_prefixes                  = [subnet.address_prefix]
      private_endpoint_network_policies = name == "private_endpoints" ? "Disabled" : "Enabled"
      network_security_group            = name == "application" ? { id = azurerm_network_security_group.application.id } : null
    }
  }
  enable_telemetry = false
}
