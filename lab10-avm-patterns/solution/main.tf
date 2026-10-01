# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

locals {
  hub_name   = "vnet-hub-tf-lab10-${var.unique_suffix}"
  spoke_name = "vnet-spoke-tf-lab10-${var.unique_suffix}"
}

module "spoke" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name             = local.spoke_name
  location         = azurerm_resource_group.this.location
  parent_id        = azurerm_resource_group.this.id
  address_space    = ["10.80.0.0/16"]
  enable_telemetry = false
  tags             = var.tags
  subnets = {
    application = {
      name                            = "snet-application"
      address_prefixes                = ["10.80.1.0/24"]
      default_outbound_access_enabled = false
    }
  }
}

module "connectivity" {
  source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
  version = "0.17.5"

  enable_telemetry = false
  tags             = var.tags
  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = false
    }
  }
  hub_virtual_networks = {
    hub = {
      location                  = azurerm_resource_group.this.location
      default_parent_id         = azurerm_resource_group.this.id
      default_hub_address_space = "10.70.0.0/16"
      enabled_resources = {
        firewall                              = false
        firewall_policy                       = false
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = false
        bastion                               = true
        nat_gateway                           = true
        private_dns_zones                     = true
        private_dns_resolver                  = true
        dns_resolver_policy                   = false
      }
      hub_virtual_network = {
        name                             = local.hub_name
        address_space                    = ["10.70.0.0/16"]
        mesh_peering_enabled             = false
        route_table_firewall_enabled     = false
        route_table_user_subnets_enabled = false
        subnets = {
          workload = {
            name                            = "snet-workload"
            address_prefixes                = ["10.70.1.0/24"]
            default_outbound_access_enabled = false
            nat_gateway = {
              assign_generated_nat_gateway = true
            }
            route_table = {
              assign_generated_route_table = false
            }
          }
        }
      }
      bastion = {
        name                  = "bas-tf-lab10-${var.unique_suffix}"
        sku                   = "Basic"
        subnet_address_prefix = "10.70.0.0/26"
        zones                 = []
        bastion_public_ip = {
          name  = "pip-bastion-tf-lab10-${var.unique_suffix}"
          zones = []
        }
      }
      nat_gateway = {
        name  = "nat-tf-lab10-${var.unique_suffix}"
        sku   = "Standard"
        zones = ["1"]
        ip_configurations = {
          default = {
            is_default = true
            public_ip_configuration = {
              name  = "pip-nat-tf-lab10-${var.unique_suffix}"
              sku   = "Standard"
              zones = ["1"]
            }
          }
        }
      }
      private_dns_resolver = {
        name                             = "dnspr-tf-lab10-${var.unique_suffix}"
        subnet_name                      = "snet-dns-inbound"
        subnet_address_prefix            = "10.70.0.64/28"
        ip_address                       = "10.70.0.68"
        default_inbound_endpoint_enabled = true
      }
      private_dns_zones = {
        auto_registration_zone_enabled = false
        private_link_private_dns_zones = {
          for key, zone_name in var.private_dns_zones : key => {
            zone_name = zone_name
          }
        }
        virtual_network_link_additional_virtual_networks = {
          spoke = {
            virtual_network_resource_id = module.spoke.resource_id
          }
        }
      }
    }
  }
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-spoke"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.connectivity.name["hub"]
  remote_virtual_network_id    = module.spoke.resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = module.spoke.name
  remote_virtual_network_id    = module.connectivity.resource_id["hub"]
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
