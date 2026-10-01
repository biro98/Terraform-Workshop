# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab08-solution-u01"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab08-solution-u01/providers/Microsoft.Network/networkSecurityGroups/application"
    }
  }
}

mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab08-solution-u01/providers/Microsoft.Network/virtualNetworks/lab08/subnets/mock"
      output = {}
    }
  }
}

mock_provider "modtm" {}
mock_provider "random" {}

override_resource {
  target = module.virtual_network.azapi_resource.vnet
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab08-solution-u01/providers/Microsoft.Network/virtualNetworks/lab08"
  }
}

run "example_contract" {
  command = apply

  assert {
    condition     = output.resource_group_name == var.resource_group_name && azurerm_resource_group.this.location == "swedencentral"
    error_message = "The solution must own the configured group in the example region."
  }

  assert {
    condition = (
      azurerm_network_security_group.application.name == "nsg-application-tf-lab08-${var.unique_suffix}" &&
      azurerm_network_security_rule.management_https.source_address_prefix == var.management_cidr &&
      azurerm_network_security_rule.management_https.destination_port_range == "443" &&
      azurerm_network_security_rule.management_https.protocol == "Tcp" &&
      azurerm_network_security_rule.management_https.access == "Allow" &&
      azurerm_network_security_rule.management_https.direction == "Inbound" &&
      azurerm_network_security_rule.management_https.priority == 100
    )
    error_message = "Application HTTPS must use the lab-specific NSG and scoped rule."
  }

  assert {
    condition = (
      length(output.subnets) == 3 &&
      output.subnets.application.resource.body.properties.networkSecurityGroup.id == output.application_nsg_id &&
      output.subnets.data.resource.body.properties.networkSecurityGroup == null &&
      output.subnets.private_endpoints.resource.body.properties.networkSecurityGroup == null
    )
    error_message = "AVM must attach the root NSG only to the application subnet."
  }

  assert {
    condition = alltrue([
      for key, subnet in output.subnets :
      subnet.name == "snet-${replace(key, "_", "-")}" &&
      subnet.resource.body.properties.privateEndpointNetworkPolicies == (key == "private_endpoints" ? "Disabled" : "Enabled") &&
      toset(subnet.resource.body.properties.addressPrefixes) == toset([var.subnets[key].address_prefix])
    ])
    error_message = "The actual AVM subnet/helper composition must retain names, CIDRs, and intended policies."
  }

  assert {
    condition     = toset(module.virtual_network.address_spaces) == toset(["10.8.0.0/16"]) && output.vnet_id == module.virtual_network.resource_id
    error_message = "The VNet address space and published ID must match the guide."
  }
}
