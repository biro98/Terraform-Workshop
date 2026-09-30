# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "this" {
  name                = "vnet-tf-lab03-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]
}
resource "azurerm_subnet" "application" {
  name                              = "snet-application"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = ["10.10.1.0/24"]
  private_endpoint_network_policies = "Enabled"
}
resource "azurerm_subnet" "data" {
  name                              = "snet-data"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = ["10.10.2.0/24"]
  private_endpoint_network_policies = "Enabled"
}
resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = ["10.10.3.0/24"]
  private_endpoint_network_policies = "Disabled"
}
resource "azurerm_network_security_group" "application" {
  name                = "nsg-tf-lab03-application-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_network_security_rule" "https" {
  name                        = "Allow-Https-From-VNet"
  description                 = "Allow HTTPS from the virtual network to the application subnet."
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.application.name
}
resource "azurerm_subnet_network_security_group_association" "application" {
  subnet_id                 = azurerm_subnet.application.id
  network_security_group_id = azurerm_network_security_group.application.id
}

moved {
  from = azurerm_subnet.private_endpoint
  to   = azurerm_subnet.private_endpoints
}
