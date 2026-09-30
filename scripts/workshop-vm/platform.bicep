// SPDX-FileCopyrightText: 2026 biro98
// SPDX-License-Identifier: MIT

param location string = resourceGroup().location
param workshopId string

var tags = {
  WorkshopId: workshopId
  Purpose: 'SingleWorkstation'
}

resource natIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${workshopId}-nat-ip'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource nat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: '${workshopId}-nat'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIpAddresses: [{ id: natIp.id }]
    idleTimeoutInMinutes: 4
  }
}

resource desktopNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${workshopId}-desktops-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'RdpFromBastion'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.250.0.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${workshopId}-platform-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.250.0.0/16'] }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: { addressPrefix: '10.250.0.0/26' }
      }
      {
        name: 'desktops'
        properties: {
          addressPrefix: '10.250.1.0/24'
          defaultOutboundAccess: false
          networkSecurityGroup: { id: desktopNsg.id }
          natGateway: { id: nat.id }
          serviceEndpoints: [{ service: 'Microsoft.Storage' }]
        }
      }
    ]
  }
}

resource bastionIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${workshopId}-bastion-ip'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: '${workshopId}-bastion'
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: {
    ipConfigurations: [
      {
        name: 'configuration'
        properties: {
          subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
          publicIPAddress: { id: bastionIp.id }
        }
      }
    ]
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${uniqueString(subscription().id, resourceGroup().id)}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
      virtualNetworkRules: [
        { id: '${vnet.id}/subnets/desktops', action: 'Allow' }
      ]
      ipRules: []
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: { enabled: true, days: 7 }
    containerDeleteRetentionPolicy: { enabled: true, days: 7 }
  }
}

output subnetId string = '${vnet.id}/subnets/desktops'
output storageAccountName string = storage.name
output bastionName string = bastion.name
