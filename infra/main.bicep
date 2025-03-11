targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('resource group where resources will be deployed')
param resourceGroupName string

@description('resource name prefix')
param resourceNamePrefix string

@description('user principal id passed thru azd')
param userPrincipalId string

@description('azurePortalAccessIp')
param azurePortalAccessIp string = '52.252.175.48'  // nslookup stamp2.ext.search.windows.net


// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var identityName = '${resourceNamePrefix}-mi'
var nsgName = '${resourceNamePrefix}-nsg'
var vnetName = '${resourceNamePrefix}-vnet'
var keyvaultName = '${resourceNamePrefix}kv'
var storageAccountName = '${resourceNamePrefix}sa'
var aoaiServiceName = '${resourceNamePrefix}oai'
var searchServiceName = '${resourceNamePrefix}srch'
var bastionhostName = '${resourceNamePrefix}bh'

// openai chat gpt deployment onfiguration
var _chatGptDeploymentName = 'gpt-4o-deployment'
var _chatGptModelName = 'gpt-4o'
var _chatGptModelVersion = '2024-11-20'
var _chatGptModelDeploymentType = 'GlobalStandard'
var _chatGptDeploymentCapacity = 100

var _embeddingsDeploymentName = 'text-embedding-3-small-deployment'
var _embeddingsModelName = 'text-embedding-3-small'
var _embeddingsModelVersion = '1'
var _embeddingsDeploymentType = 'Standard'
var _embeddingsDeploymentCapacity = 120


resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: identityName
  scope: rg
  params: {
    name: identityName
    location: location
    tags: tags
  }
}

module contributorRoleAssignment 'modules/rgRoleAssignment.bicep' = {
  name: 'contributorRoleAssignment'
  scope: rg
  params: {
    reousrceGroupId: rg.id
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalId: userAssignedIdentity.outputs.principalId
  }
}


module m365nsg 'modules/m365nsg.bicep' = {
  name: 'm365nsg'
  scope: rg
  params: {
    networkSecurityGroupName: nsgName
    tags: tags
  }
}
module bastionNsg 'modules/bastionNsg.bicep' = {
  name: 'bastionNsg'
  scope: rg
  params: {
    networkSecurityGroupName: 'bastion-nsg'
    tags: tags
  }
}

module vnetDeployment 'br/public:avm/res/network/virtual-network:0.5.4' = {
  name: 'vnet-deployment'
  scope: rg
  params: {
    name: vnetName
    location: location
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      {
        name: 'KeyServicesSubnet'
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroupResourceId: m365nsg.outputs.id
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        serviceEndpoints: [ 
          'Microsoft.CognitiveServices'
          'Microsoft.KeyVault'
          'Microsoft.Storage'
          'Microsoft.Web'
        ]
      }
      {
        name: 'WebAppSubnet'
        addressPrefix: '10.0.2.0/24'
        delegation: 'Microsoft.Web/serverFarms'
        networkSecurityGroupResourceId: m365nsg.outputs.id
        
      }
      {
        name: 'ShellSubnet'
        addressPrefix: '10.0.3.0/24'
        delegation: 'Microsoft.ContainerInstance/containerGroups'
        networkSecurityGroupResourceId: m365nsg.outputs.id
      }
      {
        name: 'JumpboxSubnet'
        addressPrefix: '10.0.63.0/26'
        networkSecurityGroupResourceId: bastionNsg.outputs.id
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.64.0/26'
        networkSecurityGroupResourceId: bastionNsg.outputs.id

      }
    ]
    tags: tags
  }
}


module bastionHost 'br/public:avm/res/network/bastion-host:0.6.1' = {
  name: 'bastionHostDeployment'
  scope: rg
  params: {
    name: bastionhostName
    virtualNetworkResourceId: vnetDeployment.outputs.resourceId
    location: location
    skuName: 'Basic'
    tags: tags
  }
}



module privateDnsZones 'modules/privateDnsZones.bicep' = {
  name: 'privateDnsZones'
  scope: rg
  params: {
    vnetId: vnetDeployment.outputs.resourceId
    tags: tags
  }
}

module keyvaultDeployment 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'keyvault-deployment'
  scope: rg
  params: {
    name: keyvaultName
    location: location
    sku: 'standard'
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    roleAssignments:[
      {
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'Key Vault Administrator'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]
    tags: tags
  }
  dependsOn: [privateDnsZones]
}

module keyvaultPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.10.1' = {
  name: 'keyvault-pe'
  scope: rg
  params: {
    name: 'keyvault-pe'
    location: location
    subnetResourceId: vnetDeployment.outputs.subnetResourceIds[0]
    privateLinkServiceConnections: [
      {
        name: 'keyvault-plsc'
        properties: {
          privateLinkServiceId: keyvaultDeployment.outputs.resourceId
          groupIds: ['Vault']
        }
      }
    ]
    tags: tags
  }
}

module aoaiDeployment 'br/public:avm/res/cognitive-services/account:0.5.3' = {
  name: 'aoai-deployment'
  scope: rg
  params: {
    kind: 'OpenAI'
    name: aoaiServiceName
    location: location
    publicNetworkAccess: 'Enabled' // to open up the service to firewall-based access.
    disableLocalAuth: true // Disable local authentication
    managedIdentities: {
      systemAssigned: true
    }
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: vnetDeployment.outputs.subnetResourceIds[0]
          action: 'Allow'
        }
      ]
      ipRules: [] // add your azure portal client ip here once you log in bastion
      bypass: 'AzureServices'
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Cognitive Services Contributor'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: '64702f94-c441-49e6-a78b-ef80e0188fee' //'Azure AI Developer'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: '64702f94-c441-49e6-a78b-ef80e0188fee' //'Azure AI Developer'
        principalId: userPrincipalId
        principalType: 'User'
      }      
    ]
    customSubDomainName: '${resourceNamePrefix}-local'
    deployments: [
      {
        name: _chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: _chatGptModelName
          version: _chatGptModelVersion
        }
        sku: {
          name: _chatGptModelDeploymentType
          capacity: _chatGptDeploymentCapacity
        }
      }
     {
        name: _embeddingsDeploymentName
        model: {
          format: 'OpenAI'
          name: _embeddingsModelName
          version: _embeddingsModelVersion
        }
        sku: {
          name: _embeddingsDeploymentType
          capacity: _embeddingsDeploymentCapacity
        }
      }    
    ]
    tags: tags
  }
  dependsOn: [privateDnsZones]
}


module searchServiceDeployment 'br/public:avm/res/search/search-service:0.9.1' = {
  name: 'search-service-deployment'
  scope: rg
  params: {
    name: searchServiceName
    location: location
    sku: 'basic'
    partitionCount: 1
    replicaCount: 1
    disableLocalAuth: true // Disable local authentication
    managedIdentities: {
      systemAssigned: true
    }
    authOptions: null // disable local auth => this should be null
    publicNetworkAccess: 'Enabled' // to open up the service to firewall-based access.
    networkRuleSet: {
      ipRules: [
        {
          value: azurePortalAccessIp
        }
        // add your azure portal client ip here once you log in bastion
      ]
      bypass: 'AzurePortal'
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Search Service Contributor'
        principalId: aoaiDeployment.outputs.systemAssignedMIPrincipalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName:'Search Index Data Contributor'
        principalId: aoaiDeployment.outputs.systemAssignedMIPrincipalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName:'Search Index Data Reader'
        principalId:  aoaiDeployment.outputs.systemAssignedMIPrincipalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName:'Search Index Data Contributor'
        principalId: userPrincipalId
        principalType: 'User'
      }
    ]
    sharedPrivateLinkResources: [
      {
        privateLinkResourceId: aoaiDeployment.outputs.resourceId
        groupId: 'openai_account'
        requestMessage: 'Please approve the request to connect to the OpenAI account from search service'
      }
      {
        privateLinkResourceId: storageAccountDeployment.outputs.resourceId
        groupId: 'blob'
        requestMessage: 'Please approve the request to connect to the storage account from search service'
      }
    ]
    tags: tags
  }
  dependsOn: [privateDnsZones]
}

module storageAccountDeployment 'br/public:avm/res/storage/storage-account:0.18.0' = {
  name: 'storage-account-deployment'
  scope: rg
  params: {
    name: storageAccountName
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    isLocalUserEnabled: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Enabled' // turning on firewall and private enpoints will block public nework access except ai services
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: vnetDeployment.outputs.subnetResourceIds[0]
          action: 'Allow'
        }
      ]

    }
    blobServices:{
      containers: [
        {
          name: 'fileuploads'
          publicAccess: 'None'
        }
      ]
      coresRules: [
        {
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://*.ai.azure.com'
        ]
          allowedMethods: [
            'DELETE', 'GET', 'HEAD', 'MERGE', 'POST', 'OPTIONS', 'PATCH', 'PUT'
          ]
          allowedHeaders: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 1800
        }
      ]
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        principalId: userPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        principalType: 'User'
      }
    ]
    tags: tags
  }
}

module grantStroageReaderToSearch 'modules/storageRoleAssignment.bicep' = {
  name: 'grantStroageReaderToSearch'
  scope: rg
  params: {
    principalId: searchServiceDeployment.outputs.?systemAssignedMIPrincipalId ?? ''
    storageAccountName: storageAccountName
    roleName: 'Storage Blob Data Reader'
  }
}

module grantStroageContributorToOpenAI 'modules/storageRoleAssignment.bicep' = {
  name: 'grantStroageReaderToOpenAI'
  scope: rg
  params: {
    principalId: aoaiDeployment.outputs.?systemAssignedMIPrincipalId
    storageAccountName: storageAccountName
    roleName: 'Storage Blob Data Contributor'
  }
}


module openaiAccessFromSearch './modules/aiServiceRoleAssignment.bicep' = {
  name: 'openaiAccessFromSearch'
  scope: rg
  params: {
    principalId:  searchServiceDeployment.outputs.?systemAssignedMIPrincipalId ?? ''
    openaiAccountName: aoaiServiceName
  }
}

// add private endpoint for storage account
module storageAccountPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.10.1' = {
  name: '${storageAccountName}-blob-pe'
  scope: rg
  params: {
    name: '${storageAccountName}-blob-pe'
    location: location
    subnetResourceId: vnetDeployment.outputs.subnetResourceIds[0]
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-blob-plsc'
        properties: {
          privateLinkServiceId: storageAccountDeployment.outputs.resourceId
          groupIds: ['blob']
        }
      }
    ]
    tags: tags
  }
}
module aoaiPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.10.1' = {
  name: '${aoaiServiceName}-pe'
  scope: rg
  params: {
    name: '${aoaiServiceName}-pe'
    location: location
    subnetResourceId: vnetDeployment.outputs.subnetResourceIds[0]
    privateLinkServiceConnections: [
      {
        name: '${aoaiServiceName}-plsc'
        properties: {
          privateLinkServiceId: aoaiDeployment.outputs.resourceId
          groupIds: ['account']
        }
      }
    ]
    tags: tags
  }
}

module searchPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.10.1' = {
  name: '${searchServiceName}-pe'
  scope: rg
  params: {
    name: '${searchServiceName}-pe'
    location: location
    subnetResourceId: vnetDeployment.outputs.subnetResourceIds[0]
    privateLinkServiceConnections: [
      {
        name: '${searchServiceName}-plsc'
        properties: {
          privateLinkServiceId: searchServiceDeployment.outputs.resourceId
          groupIds: ['searchService']
        }
      }
    ]
    tags: tags
  }
}

module trustAzureServicesInSearch 'modules/trustAzureServices.bicep' = {
  name: 'trustAzureServicesInSearch'
  scope: rg
  params: {
    name: 'trustAzureServicesInSearch'
    managedIdentityResourceId: userAssignedIdentity.outputs.resourceId
    location: location
    resourceId: searchServiceDeployment.outputs.resourceId
    azurePortalAccessIp: azurePortalAccessIp
  }
}
