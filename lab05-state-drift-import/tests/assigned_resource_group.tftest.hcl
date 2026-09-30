# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  resource_group_name = "rg-tf-lab05-test01"
  location            = "swedencentral"
  unique_suffix       = "test01"
}

run "bootstrap_only_the_resource_group" {
  command = apply

  plan_options {
    target = [azurerm_resource_group.this]
  }

  assert {
    condition     = azurerm_resource_group.this.name == var.resource_group_name && azurerm_resource_group.this.location == var.location
    error_message = "The one-time targeted bootstrap must create the lab group from its explicit inputs."
  }
}

run "starter_creates_own_group" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this.name == var.resource_group_name && azurerm_virtual_network.this.resource_group_name == azurerm_resource_group.this.name
    error_message = "The VNet must use this state's managed resource group."
  }

  assert {
    condition     = azurerm_resource_group.this.location == var.location && azurerm_virtual_network.this.location == azurerm_resource_group.this.location
    error_message = "The input location must flow through the managed group to the VNet."
  }

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-tf-lab05-test01" && azurerm_virtual_network.this.address_space == toset(["10.5.0.0/16"]) && azurerm_virtual_network.this.tags.owner == "network-team"
    error_message = "The VNet import configuration must match the documented CLI creation settings."
  }

  assert {
    condition     = length(regexall("(?m)^use_(msi|azuread_auth)\\s*=\\s*true\\s*$", file("${path.module}/backend.hcl.example"))) == 2 && length(regexall("(?m)^use_cli\\s*=", file("${path.module}/backend.hcl.example"))) == 0
    error_message = "The independent backend must explicitly use both MSI and Entra Blob authorization, never CLI auth."
  }

  assert {
    condition     = length(regexall("(?m)^(tenant_id|subscription_id)\\s*=\\s*\"[^\"]+\"\\s*$", file("${path.module}/backend.hcl.example"))) == 2 && can(regex("(?m)^key\\s*=\\s*\"lab05.tfstate\"\\s*$", file("${path.module}/backend.hcl.example")))
    error_message = "Backend migration must retain explicit VM tenant/subscription settings and the starter's state key."
  }

  assert {
    condition     = regex("(?m)^resource_group_name\\s*=\\s*\"([^\"]+)\"", file("${path.module}/backend.hcl.example"))[0] != regex("(?m)^resource_group_name\\s*=\\s*\"([^\"]+)\"", file("${path.module}/terraform.tfvars.example"))[0]
    error_message = "Platform backend storage must remain outside the Terraform-managed lab group."
  }
}
