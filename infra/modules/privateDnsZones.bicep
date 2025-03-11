param vnetId string
param tags object = {}
var AzureDotNetDnsZoneSuffix = environment().name == 'AzureUSGovernment' ? 'usgovcloudapi.net' : 'azure.net'
var AzureDotComDnsZoneSuffix = environment().name == 'AzureUSGovernment' ? 'usgovcloudapi.net' : 'azure.com'
var WindowsDotNetDnsZoneSuffix = environment().name == 'AzureUSGovernment' ? 'usgovcloudapi.net' : 'windows.net'
var virtualNetworkLinks = [
  {
    virtualNetworkResourceId: vnetId
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
  }
]

module keyvaultDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'keyvaultDnsZone'
  params: {
    name: 'privatelink.vaultcore.${AzureDotNetDnsZoneSuffix}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module cosmosdbDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'cosmosdbDnsZone'
  params: {
    name: 'privatelink.documents.${AzureDotComDnsZoneSuffix}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module aiSearchDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'aiSearchDnsZone'
  params: {
    name: 'privatelink.cognitiveservices.${AzureDotComDnsZoneSuffix}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module openAIDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'openAIDnsZone'
  params: {
    name: 'privatelink.openai.${AzureDotComDnsZoneSuffix}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module redisDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'redisDnsZone'
  params: {
    name: 'privatelink.redis.cache.${WindowsDotNetDnsZoneSuffix}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}
module blobDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'blobDnsZone'
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module fileShareDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'fileShareDnsZone'
  params: {
    name: 'privatelink.file.${environment().suffixes.storage}'
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}
