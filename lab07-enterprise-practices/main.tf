# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# INTENTIONAL ISSUE: formatting is inconsistent; run terraform fmt after repairs.
resource "azurerm_resource_group" "this" {
name=var.resource_group_name
location=var.location
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-tf-lab07-hardcoded" # INTENTIONAL ISSUE: derive from suffix.
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.7.0.0/24"]
}

resource "azurerm_subnet" "application" {
  name                 = "snet-application"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.missing.name # INTENTIONAL ISSUE: bad reference.
  address_prefixes     = ["10.8.1.0/24"]                      # INTENTIONAL ISSUE: outside VNet CIDR.
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-lab07-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  security_rule {
    name                       = "Allow-Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*" # INTENTIONAL ISSUE: overly broad.
    destination_address_prefix = "*"
  }
}
