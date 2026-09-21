param location string = resourceGroup().location
param prefix string = 'commerce'
param adminGroupId string
param sqlAdmin string = 'portfolioadmin'
@secure()
param sqlPassword string
var suffix = uniqueString(resourceGroup().id)
module cluster 'cluster.bicep' = { name: 'cluster', params: { location: location, prefix: prefix, adminGroupId: adminGroupId } }
resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
 name: 'sql-${suffix}'
 location: location
 properties: { administratorLogin: sqlAdmin, administratorLoginPassword: sqlPassword, version: '12.0', minimalTlsVersion: '1.2', publicNetworkAccess: 'Disabled' }
}
resource db 'Microsoft.Sql/servers/databases@2023-08-01' = {
 parent: sqlServer
 name: 'commerce'
 location: location
 sku: { name: 'Basic', tier: 'Basic', capacity: 5 }
 properties: { maxSizeBytes: 2147483648, requestedBackupStorageRedundancy: 'Local' }
}
resource redis 'Microsoft.Cache/redisEnterprise@2025-07-01' = {
 name: 'redis-${suffix}'
 location: location
 sku: { name: 'Balanced_B0' }
 properties: { minimumTlsVersion: '1.2', publicNetworkAccess: 'Disabled', highAvailability: 'Disabled' }
}
resource redisDb 'Microsoft.Cache/redisEnterprise/databases@2025-07-01' = {
 parent: redis
 name: 'default'
 properties: { clientProtocol: 'Encrypted', port: 10000, clusteringPolicy: 'EnterpriseCluster', evictionPolicy: 'AllKeysLRU', accessKeysAuthentication: 'Enabled' }
}
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
 name: 'st${suffix}'
 location: location
 kind: 'StorageV2'
 sku: { name: 'Standard_LRS' }
 properties: { minimumTlsVersion: 'TLS1_2', supportsHttpsTrafficOnly: true, allowBlobPublicAccess: false, allowSharedKeyAccess: false, publicNetworkAccess: 'Disabled' }
}
resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = { parent: storage, name: 'default' }
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = { parent: blobs, name: 'products', properties: { publicAccess: 'None' } }
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = { name: '${prefix}-app', location: location }
resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
 parent: appIdentity
 name: 'aks-commerce'
 properties: { issuer: cluster.outputs.oidcIssuer, subject: 'system:serviceaccount:portfolio:commerce', audiences: ['api://AzureADTokenExchange'] }
}
resource blobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
 name: guid(storage.id,appIdentity.id,'blob')
 scope: storage
 properties: { principalId: appIdentity.properties.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions','ba92f5b4-2d11-453d-a403-e96b0029c9fe') }
}
module sqlPe 'private-endpoint.bicep' = { name: 'sql-network', params: { location: location, name: 'sql-private', resourceId: sqlServer.id, groupId: 'sqlServer', dnsZone: 'privatelink${environment().suffixes.sqlServerHostname}', vnetId: cluster.outputs.vnetId, subnetId: cluster.outputs.privateSubnetId } }
module redisPe 'private-endpoint.bicep' = { name: 'redis-network', params: { location: location, name: 'redis-private', resourceId: redis.id, groupId: 'redisEnterprise', dnsZone: 'privatelink.redis.azure.net', vnetId: cluster.outputs.vnetId, subnetId: cluster.outputs.privateSubnetId } }
module storagePe 'private-endpoint.bicep' = { name: 'storage-network', params: { location: location, name: 'storage-private', resourceId: storage.id, groupId: 'blob', dnsZone: 'privatelink.blob.${environment().suffixes.storage}', vnetId: cluster.outputs.vnetId, subnetId: cluster.outputs.privateSubnetId } }
output aksName string = cluster.outputs.aksName
output acrName string = cluster.outputs.acrName
output acrLoginServer string = cluster.outputs.acrLoginServer
output sqlHost string = sqlServer.properties.fullyQualifiedDomainName
output redisName string = redis.name
output redisHost string = redis.properties.hostName
output storageName string = storage.name
output appClientId string = appIdentity.properties.clientId
