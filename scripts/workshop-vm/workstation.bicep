// SPDX-FileCopyrightText: 2026 biro98
// SPDX-License-Identifier: MIT

param location string = resourceGroup().location
param workshopId string
param vmName string
param vmSize string = 'Standard_D2as_v5'
param subnetId string
param storageAccountName string
param adminUsername string = 'workshopadmin'
param terraformVersion string = '1.14.5'
param shutdownTime string = '1900'
param bootstrapRevision string

@secure()
param adminPassword string

var tags = {
  WorkshopId: workshopId
  Purpose: 'SingleWorkstation'
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'private'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: subnetId }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 127
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }
}

resource shutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: { time: shutdownTime }
    timeZoneId: 'UTC'
    targetResourceId: vm.id
    notificationSettings: { status: 'Disabled' }
  }
}

resource bootstrap 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm
  name: 'workshop-bootstrap'
  location: location
  properties: {
    asyncExecution: false
    treatFailureAsDeploymentFailure: true
    timeoutInSeconds: 5400
    source: {
      script: loadTextContent('bootstrap-windows.ps1')
    }
    parameters: [
      { name: 'TerraformVersion', value: terraformVersion }
      { name: 'VmUsername', value: adminUsername }
      { name: 'BootstrapRevision', value: bootstrapRevision }
      { name: 'SubscriptionId', value: subscription().subscriptionId }
      { name: 'TenantId', value: subscription().tenantId }
      { name: 'StorageAccountName', value: storageAccountName }
      { name: 'ContainerName', value: container.name }
      { name: 'PlatformResourceGroup', value: resourceGroup().name }
    ]
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storage
  name: 'default'
}
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'tfstate'
  properties: { publicAccess: 'None' }
}
resource stateAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: container
  name: guid(container.id, vm.id, 'blob-data-contributor')
  properties: {
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

output vmId string = vm.id
output containerName string = container.name
output managedIdentityPrincipalId string = vm.identity.principalId
output subscriptionId string = subscription().subscriptionId
output tenantId string = subscription().tenantId
