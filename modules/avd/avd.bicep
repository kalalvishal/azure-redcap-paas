param location string
param ComputeSubnetId string
param countAVDInstances int
param vmSku string
param avdVMAdmin string
param avdVMPassword string
param vmDiskCachingType string
param vmDiskType string
// @allowed([
//   'eastus'
//   'westus'
//   'westeurope'
//   'northeurope'
//   'uksouth'
// ])
// param workspaceLocation string

@description('If true Host Pool, App Group and Workspace will be created. Default is to join Session Hosts to existing AVD environment')
param newBuild bool = false

// @description('Expiration time for the HostPool registration token. This must be up to 30 days from todays date.')
// param tokenExpirationTime string

@allowed([
  'Personal'
  'Pooled'
])
param hostPoolType string = 'Pooled'
param hostPoolName string

// @allowed([
//   'Automatic'
//   'Direct'
// ])
// param personalDesktopAssignmentType string = 'Direct'
param maxSessionLimit int = 5

@allowed([
  'BreadthFirst'
  'DepthFirst'
  'Persistent'
])
param loadBalancerType string = 'BreadthFirst'

@description('Custom RDP properties to be applied to the AVD Host Pool.')
param customRdpProperty string 

@description('Friendly Name of the Host Pool, this is visible via the AVD client')
param hostPoolFriendlyName string

@description('Name of the AVD Workspace to used for this deployment')
param workspaceName string = 'AVD-PROD'
param appGroupFriendlyName string
param tags object
param appGroupName string
param AADJoin bool
param intune bool
param baseTime string = utcNow('u')
var avdRegistrationExpiriationDate = dateTimeAdd(baseTime, 'PT24H')
var configurationFileName = 'Configuration_01-19-2023.zip'
var artifactsLocation = 'https://wvdportalstorageblob.blob.${az.environment().suffixes.storage}/galleryartifacts/${configurationFileName}'

// @description('Log Analytics workspace ID to join AVD to.')
// param logworkspaceID string
// param logworkspaceSub string
// param logworkspaceResourceGroup string
// param logworkspaceName string

// @description('List of application group resource IDs to be added to Workspace. MUST add existing ones!')
// param applicationGroupReferences string

// var appGroupResourceID = array(resourceId('Microsoft.DesktopVirtualization/applicationgroups/', appGroupName))
// var applicationGroupReferencesArr = applicationGroupReferences == '' ? appGroupResourceID : concat(split(applicationGroupReferences, ','), appGroupResourceID)

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2019-12-10-preview' = if (newBuild) {
  name: hostPoolName
  location: location
  properties: {
    friendlyName: hostPoolFriendlyName
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    customRdpProperty: customRdpProperty
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: maxSessionLimit
    validationEnvironment: false
    registrationInfo: {
      expirationTime: avdRegistrationExpiriationDate
      token: null
      registrationTokenOperation: 'Update'
    }
  }
  tags: tags
}

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2019-12-10-preview' = if (newBuild) {
  name: appGroupName
  location: location
  properties: {
    friendlyName: appGroupFriendlyName
    applicationGroupType: 'Desktop'
    description: 'Deskop Application Group created through Abri Deploy process.'
    hostPoolArmPath: resourceId('Microsoft.DesktopVirtualization/hostpools', hostPoolName)
  }
  dependsOn: [
    hostPool
  ]
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2019-12-10-preview' = if (newBuild) {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [ applicationGroup.id ]
  }
}

// module Monitoring './Monitoring.bicep' = if (newBuild) {
//   name: 'Monitoring'
//   params: {
//     hostpoolName: hostPoolName
//     workspaceName: workspaceName
//     appgroupName: appGroupName
//     logworkspaceSub: logworkspaceSub
//     logworkspaceResourceGroup: logworkspaceResourceGroup
//     logworkspaceName: logworkspaceName
//   }
//   dependsOn: [
//     workspace
//     hostPool
//   ]
// }

output appGroupName string = appGroupName



// // Azure Virtual Desktop and Session Hosts region

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = [for i in range(0, countAVDInstances): {
  name: 'nic-redcap-${i}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: ComputeSubnetId
          }
        }
      }
    ]
  }
}]

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, countAVDInstances): {
  name: 'vm-redcap-${i}'
  location: location
  identity: AADJoin ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmSku
    }
    osProfile: {
      computerName: 'vm-redcap-${i}'
      adminUsername: avdVMAdmin
      adminPassword: avdVMPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'Manual'
        }
      }
    }
    storageProfile: {
      osDisk: {
        name: 'vm-OS-${i}'
        caching: vmDiskCachingType
        managedDisk: {
          storageAccountType: vmDiskType
        }
        osType: 'Windows'
        createOption: 'FromImage'
      }
      // TODO Turn into params
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'office-365'
        sku: '20h2-evd-o365pp'
        version: 'latest'
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic[i].id
        }
      ]
    }
  }
  dependsOn: [
    nic[i]
  ]
}]

// Deploy the AVD agents to each session host
resource avdAgentDscExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = [for i in range(0, countAVDInstances): {
  name: 'AvdAgentDSC'
  parent: vm[i]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: artifactsLocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        registrationInfoToken: hostPool.properties.registrationInfo.token
        aadJoin: false
      }
    }
  }
}]

resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, countAVDInstances): {
  name: 'AADJoin'
  parent: vm[i]
  location: location
  properties: AADJoin ? {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: intune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000' //https://github.com/MicrosoftDocs/azure-docs/issues/94148
    } : null
  } : null
  dependsOn: [
    avdAgentDscExtension[i]
  ]
}]

resource dependencyAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, countAVDInstances): {
  name: 'DAExtension'
  parent: vm[i]
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}]

resource antiMalwareExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, countAVDInstances): {
  name: 'IaaSAntiMalware'
  parent: vm[i]
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: true
    }
  }
}]
