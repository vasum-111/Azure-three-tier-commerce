param location string
param name string
param resourceId string
param groupId string
param dnsZone string
param vnetId string
param subnetId string
resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' = { name: dnsZone, location: 'global' }
resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
 parent: zone
 name: 'aks'
 location: 'global'
 properties: { registrationEnabled: false, virtualNetwork: { id: vnetId } }
}
resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
 name: name
 location: location
 properties: { subnet: { id: subnetId }, privateLinkServiceConnections: [{ name: name, properties: { privateLinkServiceId: resourceId, groupIds: [groupId] } }] }
}
resource group 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
 parent: pe
 name: 'default'
 properties: { privateDnsZoneConfigs: [{ name: 'default', properties: { privateDnsZoneId: zone.id } }] }
}
