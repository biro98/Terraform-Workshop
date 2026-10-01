# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

mock_provider "azurerm" {
  mock_data "azurerm_public_ip" {
    defaults = {
      id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/publicIPAddresses/bastion"
      zones = []
    }

  }
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10"
    }
  }
  mock_resource "azurerm_private_dns_resolver" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/dnsResolvers/resolver"
    }
  }
  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/publicIPAddresses/bastion"
      ip_address = "192.0.2.10"
    }
  }
}

mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "11111111-1111-1111-1111-111111111111"
    }
  }
  mock_data "azapi_resource_action" {
    defaults = {
      output = {
        value = [{
          name        = "swedencentral"
          displayName = "Sweden Central"
          metadata = {
            geography      = "Sweden"
            geographyGroup = "Europe"
            regionCategory = "Recommended"
            regionType     = "Physical"
            pairedRegion   = [{ name = "swedensouth" }]
          }
          availabilityZoneMappings = [{ logicalZone = "1" }, { logicalZone = "2" }, { logicalZone = "3" }]
        }]
      }
    }
  }
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/virtualNetworks/hub/subnets/mock"
      output = { properties = { addressPrefixes = ["10.70.0.0/24"] } }
    }
  }
}

mock_provider "modtm" {
  mock_data "modtm_module_source" {
    defaults = {
      module_source  = "registry.terraform.io/Azure/avm-res-network-natgateway/azurerm"
      module_version = "0.3.0"
    }
  }
}
mock_provider "random" {}

override_resource {
  target = module.spoke.azapi_resource.vnet
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/virtualNetworks/spoke"
  }
}

override_resource {
  target = module.connectivity.module.hub_and_spoke_vnet.module.hub_virtual_networks["hub"].azapi_resource.vnet
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/virtualNetworks/hub"
  }
}

override_resource {
  target = module.connectivity.module.hub_and_spoke_vnet.module.hub_virtual_network_subnets["hub-bastion"].azapi_resource.subnet[0]
  values = {
    id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/virtualNetworks/hub/subnets/AzureBastionSubnet"
    output = { properties = { addressPrefixes = ["10.70.0.0/26"] } }
  }
}

override_resource {
  target = module.connectivity.module.private_dns_zones["hub"].module.avm_res_network_privatednszone["blob"].azapi_resource.private_dns_zone
  values = {
    id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    output = { name = "privatelink.blob.core.windows.net" }
  }
}

override_resource {
  target = module.connectivity.module.private_dns_zones["hub"].module.avm_res_network_privatednszone["vault"].azapi_resource.private_dns_zone
  values = {
    id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab10-ref10/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    output = { name = "privatelink.vaultcore.azure.net" }
  }
}

run "pattern_contract" {
  command = apply

  assert {
    condition     = output.resource_group_name == var.resource_group_name && azurerm_resource_group.this.location == "swedencentral"
    error_message = "The lab must use its dedicated resource group and sample region."
  }

  assert {
    condition = (
      length(output.virtual_networks) == 2 &&
      output.virtual_networks.hub.name == "vnet-hub-tf-lab10-${var.unique_suffix}" &&
      output.virtual_networks.spoke.name == "vnet-spoke-tf-lab10-${var.unique_suffix}" &&
      toset(module.spoke.address_spaces) == toset(["10.80.0.0/16"]) &&
      length(module.spoke.subnets) == 1 &&
      module.spoke.subnets.application.resource.body.properties.natGateway == null &&
      module.spoke.subnets.application.resource.body.properties.defaultOutboundAccess == false
    )
    error_message = "The spoke must be isolated from the hub NAT and have no implicit outbound access."
  }

  assert {
    condition = (
      length(output.platform_services) == 3 &&
      toset(values(output.resolver_inbound_ip_addresses)) == toset(["10.70.0.68"]) &&
      length(output.private_dns_zone_ids) == 2 &&
      length(module.connectivity.private_dns_zone_auto_registration_resource_ids) == 0 &&
      length(module.connectivity.firewall_resource_ids) == 0 &&
      length(module.connectivity.virtual_network_gateway_resource_ids) == 0 &&
      module.connectivity.ddos_protection_plan_resource_id == null &&
      length(module.connectivity.route_tables_firewall) == 0 &&
      length(module.connectivity.route_tables_user_subnets) == 0 &&
      length(module.connectivity.dns_resolver_policy_resource_ids) == 0
    )
    error_message = "Create only the selected DNS zones and services, without firewall, gateways, DDoS, resolver policy or routes."
  }

  assert {
    condition = (
      azurerm_virtual_network_peering.hub_to_spoke.remote_virtual_network_id == output.virtual_networks.spoke.id &&
      azurerm_virtual_network_peering.spoke_to_hub.remote_virtual_network_id == output.virtual_networks.hub.id &&
      azurerm_virtual_network_peering.hub_to_spoke.allow_virtual_network_access &&
      azurerm_virtual_network_peering.spoke_to_hub.allow_virtual_network_access &&
      !azurerm_virtual_network_peering.hub_to_spoke.allow_forwarded_traffic &&
      !azurerm_virtual_network_peering.spoke_to_hub.allow_forwarded_traffic &&
      !azurerm_virtual_network_peering.hub_to_spoke.allow_gateway_transit &&
      !azurerm_virtual_network_peering.spoke_to_hub.use_remote_gateways
    )
    error_message = "Both peering directions must use real VNet IDs with no appliance forwarding or gateway transit."
  }
}

run "dns_change_preview" {
  command = plan

  variables {
    private_dns_zones = {
      blob  = "privatelink.blob.core.windows.net"
      vault = "privatelink.vaultcore.azure.net"
      queue = "privatelink.queue.core.windows.net"
    }
  }

  assert {
    condition     = length(module.connectivity.private_link_private_dns_zones_maps["hub"]) == 3
    error_message = "The DNS-only preview must add exactly one selected zone."
  }
}

run "restored_plan" {
  command = plan

  assert {
    condition     = length(module.connectivity.private_link_private_dns_zones_maps["hub"]) == 2
    error_message = "Restoring the inputs must return to the two-zone pattern."
  }
}
