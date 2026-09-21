param location string = resourceGroup().location
param prefix string
param originHost string
param privateLinkId string
param groupId string = ''
param staticSite bool = false
resource profile 'Microsoft.Cdn/profiles@2024-09-01' = {
 name: '${prefix}-edge'
 location: 'global'
 sku: { name: 'Premium_AzureFrontDoor' }
 properties: { originResponseTimeoutSeconds: 30 }
}
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-09-01' = {
 parent: profile
 name: '${prefix}-${uniqueString(resourceGroup().id)}'
 location: 'global'
 properties: { enabledState: 'Enabled' }
}
resource origins 'Microsoft.Cdn/profiles/originGroups@2024-09-01' = {
 parent: profile
 name: 'application'
 properties: {
  loadBalancingSettings: { sampleSize: 4, successfulSamplesRequired: 3, additionalLatencyInMilliseconds: 50 }
  healthProbeSettings: { probePath: staticSite ? '/' : '/healthz', probeRequestType: 'GET', probeProtocol: staticSite ? 'Https' : 'Http', probeIntervalInSeconds: 60 }
  sessionAffinityState: 'Disabled'
 }
}
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-09-01' = {
 parent: origins
 name: 'private-origin'
 properties: {
  hostName: originHost
  originHostHeader: originHost
  httpPort: 80
  httpsPort: 443
  priority: 1
  weight: 1000
  enabledState: 'Enabled'
  enforceCertificateNameCheck: true
  sharedPrivateLinkResource: {
   privateLink: { id: privateLinkId }
   groupId: groupId
   privateLinkLocation: location
   requestMessage: 'Portfolio ${prefix} Front Door private origin'
  }
 }
}
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-09-01' = {
 parent: endpoint
 name: 'default'
 properties: {
  originGroup: { id: origins.id }
  supportedProtocols: ['Http', 'Https']
  patternsToMatch: ['/*']
  forwardingProtocol: staticSite ? 'HttpsOnly' : 'HttpOnly'
  httpsRedirect: 'Enabled'
  linkToDefaultDomain: 'Enabled'
  enabledState: 'Enabled'
  cacheConfiguration: staticSite ? { queryStringCachingBehavior: 'IgnoreQueryString', compressionSettings: { isCompressionEnabled: true, contentTypesToCompress: ['text/html','text/css','application/javascript'] } } : null
 }
 dependsOn: [origin]
}
resource waf 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2024-02-01' = {
 name: replace('${prefix}waf','-','')
 location: 'global'
 sku: { name: 'Premium_AzureFrontDoor' }
 properties: {
  policySettings: { enabledState: 'Enabled', mode: 'Prevention' }
  managedRules: { managedRuleSets: [{ ruleSetType: 'Microsoft_DefaultRuleSet', ruleSetVersion: '2.1', ruleSetAction: 'Block' }] }
  customRules: { rules: [{ name: 'RequestRateLimit', priority: 100, enabledState: 'Enabled', ruleType: 'RateLimitRule', rateLimitDurationInMinutes: 1, rateLimitThreshold: 120, matchConditions: [{ matchVariable: 'RequestUri', operator: 'BeginsWith', matchValue: ['/'] }], action: 'Block' }] }
 }
}
resource security 'Microsoft.Cdn/profiles/securityPolicies@2024-09-01' = {
 parent: profile
 name: 'waf'
 properties: {
  parameters: { type: 'WebApplicationFirewall', wafPolicy: { id: waf.id }, associations: [{ domains: [{ id: endpoint.id }], patternsToMatch: ['/*'] }] }
 }
}
output url string = 'https://${endpoint.properties.hostName}'
output profileName string = profile.name
output endpointName string = endpoint.name
