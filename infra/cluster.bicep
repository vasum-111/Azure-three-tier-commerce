param location string = resourceGroup().location
param prefix string
@description('Object ID of an Entra group that administers the AKS cluster.')
param adminGroupId string
param nodeSize string = 'Standard_D2s_v5'
param nodeCount int = 1
var suffix = uniqueString(resourceGroup().id)
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
 name: '${prefix}-vnet'
 location: location
 properties: {
  addressSpace: { addressPrefixes: ['10.42.0.0/16'] }
  subnets: [
   { name: 'aks', properties: { addressPrefix: '10.42.0.0/22', privateLinkServiceNetworkPolicies: 'Disabled' } }
   { name: 'private', properties: { addressPrefix: '10.42.4.0/24', privateEndpointNetworkPolicies: 'Disabled' } }
  ]
 }
}
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
 name: '${prefix}-cluster'
 location: location
}
resource networkRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
 name: guid(vnet.id, identity.id, 'network')
 scope: vnet
 properties: { principalId: identity.properties.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions','4d97b98b-1d4f-4787-a291-c67834d212e7') }
}
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
 name: 'acr${suffix}'
 location: location
 sku: { name: 'Basic' }
 properties: { adminUserEnabled: false }
}
resource cluster 'Microsoft.ContainerService/managedClusters@2024-10-01' = {
 name: '${prefix}-aks'
 location: location
 identity: { type: 'UserAssigned', userAssignedIdentities: { '${identity.id}': {} } }
 sku: { name: 'Base', tier: 'Free' }
 properties: {
  dnsPrefix: '${prefix}-${suffix}'
  enableRBAC: true
  disableLocalAccounts: true
  aadProfile: { managed: true, enableAzureRBAC: true, adminGroupObjectIDs: [adminGroupId] }
  oidcIssuerProfile: { enabled: true }
  securityProfile: { workloadIdentity: { enabled: true } }
  agentPoolProfiles: [{ name: 'system', count: nodeCount, vmSize: nodeSize, osType: 'Linux', osSKU: 'AzureLinux', mode: 'System', type: 'VirtualMachineScaleSets', vnetSubnetID: '${vnet.id}/subnets/aks' }]
  networkProfile: { networkPlugin: 'azure', networkPluginMode: 'overlay', networkPolicy: 'azure', podCidr: '10.244.0.0/16', serviceCidr: '10.0.0.0/16', dnsServiceIP: '10.0.0.10', loadBalancerSku: 'standard', outboundType: 'loadBalancer', loadBalancerProfile: { backendPoolType: 'nodeIPConfiguration' } }
 }
 dependsOn: [networkRole]
}
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
 name: guid(registry.id,cluster.id,'pull')
 scope: registry
 properties: { principalId: cluster.properties.identityProfile.kubeletidentity.objectId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions','7f951dda-4ed3-4680-a7ca-43fe172d538d') }
}
output aksName string = cluster.name
output acrName string = registry.name
output acrLoginServer string = registry.properties.loginServer
output vnetId string = vnet.id
output privateSubnetId string = '${vnet.id}/subnets/private'
output oidcIssuer string = cluster.properties.oidcIssuerProfile.issuerURL
