targetScope = 'subscription'

// param newBuild bool
param resourceGroupName string
param location string
param tags object
// param privateDnsZoneName string
param ComputeSubnetId string
param countAVDInstances int
param vmSku string
param hostPoolName string
param hostPoolFriendlyName string
param hostPoolType string
param appGroupName string
param appGroupFriendlyName string
param loadBalancerType string
param workspaceName string
param customRdpProperty string
param avdVMAdmin string
param customTags object

@secure()
param avdVMPassword string

param vmDiskCachingType string = 'ReadWrite'
param vmDiskType string = 'Standard_LRS'

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module avdModule './avd.bicep' = {
  scope: resourceGroup
  name: 'AVDDeploy'
  params: {
    location: location
    // logworkspaceSub: logworkspaceSub
    // logworkspaceResourceGroup: logworkspaceResourceGroup
    // logworkspaceName: logworkspaceName
    hostPoolName: hostPoolName
    hostPoolFriendlyName: hostPoolFriendlyName
    hostPoolType: hostPoolType
    appGroupName: appGroupName
    appGroupFriendlyName: appGroupFriendlyName
    loadBalancerType: loadBalancerType
    workspaceName: workspaceName
    customRdpProperty: customRdpProperty
    ComputeSubnetId: ComputeSubnetId
    countAVDInstances: countAVDInstances
    vmSku: vmSku
    avdVMAdmin: avdVMAdmin
    avdVMPassword: avdVMPassword
    vmDiskCachingType: vmDiskCachingType
    vmDiskType: vmDiskType
    // tokenExpirationTime:
    maxSessionLimit: 5
    newBuild: true
    tags: tags
  }
}
