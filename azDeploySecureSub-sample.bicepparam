using './azDeploySecureSub.bicep'

param location = 'eastus'
param environment = 'demo'
param workloadName = 'redcap'
param namingConvention = '{workloadName}-{env}-{rtype}-{loc}-{seq}'
param sequence = 1

param identityObjectId = '<Valid Entra ID object ID for permissions assignment>'
param vnetAddressSpace = '10.230.0.0/24'
param vmSku = 'Standard_D4s_v4'
param countAVDInstances = 1
