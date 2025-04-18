// AI Foundry module - Deploys Azure AI Foundry (formerly AI Foundry) hub and project resources
// with a managed VNet that connects to Azure OpenAI, Storage, and Search via private endpoints

@description('Resource name prefix')
param resourceNamePrefix string

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Key Vault resource ID')
param keyVaultId string

@description('Azure OpenAI service resource ID')
param openAiResourceId string

@description('Azure Search service resource ID')
param searchResourceId string

@description('Azure OpenAI service name')
param openaiAccountName string

@description('Azure Search service name')
param searchResourceName string
@description('Azure Search service target URL')
param azureSearchTargetUrl string
@description('Azure OpenAI service target URL')
param azureOpenAiTargetUrl string

param skuName string = 'Basic'
@description('Enable or disable public network access to the AI Foundry Hub')
param publicNetworkAccess string = 'Enabled'

@description('IP address allow list for the AI Foundry Hub')
param ipAllowList array =[]

@description('user principal id passed thru azd')
param userPrincipalId string


var aiFoundaryHubStorageAccountName = '${resourceNamePrefix}hsa'
var aiFoundryHubName = '${resourceNamePrefix}-afhub'
var aiFoundaryPrjName = '${resourceNamePrefix}-afprj'


module aiFoundaryStorageAccountDeployment 'br/public:avm/res/storage/storage-account:0.18.0' = {
  name: 'aifoundary-storage-account-deployment'
  scope: resourceGroup()
  params: {
    name: aiFoundaryHubStorageAccountName
    location: location
    skuName: 'Standard_RAGRS'
    kind: 'StorageV2'
    isLocalUserEnabled: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: ipAllowList
    }
    roleAssignments: [
      {
        principalId: userPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        principalType: 'User'
      }
      {
        principalId: userPrincipalId
        roleDefinitionIdOrName: 'Storage File Data Privileged Contributor'
        principalType: 'User'
      }
    ]
    tags: tags
  }
}

// Azure AI Foundry Hub
module aiFoundryHub 'br/public:avm/res/machine-learning-services/workspace:0.12.0' = {
  name: 'aiFoundaryHubDeployment'
  params: {
    location: location
    tags: tags
    name: aiFoundryHubName
    managedIdentities: {
      systemAssigned: true
    }
    sku: skuName
    associatedStorageAccountResourceId: aiFoundaryStorageAccountDeployment.outputs.resourceId
    associatedKeyVaultResourceId: keyVaultId
    associatedApplicationInsightsResourceId: null
    associatedContainerRegistryResourceId: null
    kind: 'Hub'
    hbiWorkspace: true
    publicNetworkAccess: publicNetworkAccess
    systemDatastoresAuthMode: 'Identity'
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id
    }
    managedNetworkSettings: {
      isolationMode: 'AllowInternetOutbound'
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/64702f94-c441-49e6-a78b-ef80e0188fee' //'Azure AI Developer'
        principalId: userPrincipalId
      }
    ]
    provisionNetworkNow:true
  }
}

resource lookupAiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: aiFoundryHubName
  scope: resourceGroup()
  dependsOn: [
    aiFoundryHub
  ]
}

resource openAIOutboundFromHub 'Microsoft.MachineLearningServices/workspaces/outboundRules@2024-10-01' = {
  parent: lookupAiFoundryHub
  name: 'openAI-pe-from-hub'
  properties: {
    category: 'UserDefined'
    type: 'PrivateEndpoint'
    destination: {
      serviceResourceId: openAiResourceId
      sparkEnabled: false
      subresourceTarget: 'account'
    }
  }
  dependsOn: [
    aiFoundryHub
  ]
}

// Add connection to Azure OpenAI service
resource openAiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: lookupAiFoundryHub
  name: openaiAccountName
  properties: {
    category: 'AzureOpenAI'
    authType: 'AAD'
    target: azureOpenAiTargetUrl
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: openAiResourceId
      Location: location
      ApiVersion: '2023-07-01-preview'
      DeploymentApiVersion: '2023-10-01-preview'
    }
  }
  dependsOn: [
    openAIOutboundFromHub
  ]
}

resource searchOutboundFromHub 'Microsoft.MachineLearningServices/workspaces/outboundRules@2024-10-01' = {
  parent: lookupAiFoundryHub
  name: 'srch-pe-from-hub'
  properties: {
    category: 'UserDefined'
    type: 'PrivateEndpoint'
    destination: {
      serviceResourceId: searchResourceId
      sparkEnabled: false
      subresourceTarget: 'searchService'
    }
  }
  dependsOn: [
    aiFoundryHub
  ]
}

// Add connection to Azure Search service
resource searchConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: lookupAiFoundryHub
  name: searchResourceName
  properties: {
    category: 'CognitiveSearch'
    authType: 'AAD'
    target: azureSearchTargetUrl
    isSharedToAll: true
    metadata: {
      Location: location
      ApiType: 'Azure'
      ResourceId: searchResourceId
      ApiVersion: '2024-05-01-preview'
      DeploymentApiVersion: '2023-11-01'
    }
  }
  dependsOn: [
    searchOutboundFromHub
  ]
}

module project 'br/public:avm/res/machine-learning-services/workspace:0.12.0' = {
  name: 'aiFoundaryProjectDeployment'
  params: {
    location: location
    tags: tags
    name: aiFoundaryPrjName
    managedIdentities: {
      systemAssigned: true
    }
    sku: skuName
    kind: 'Project'
    hubResourceId: aiFoundryHub.outputs.resourceId
    friendlyName: aiFoundaryPrjName
    systemDatastoresAuthMode: 'Identity'
    roleAssignments: [
      {
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/64702f94-c441-49e6-a78b-ef80e0188fee' //'Azure AI Developer'
        principalId: userPrincipalId
      }
    ]
  }
  
  dependsOn: [
    searchConnection
    openAiConnection
    openAIOutboundFromHub
    searchOutboundFromHub
  ]
}

// Reference to AI Foundry Project resource to get its managed identity
resource lookupAiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: aiFoundaryPrjName
  scope: resourceGroup()
  dependsOn: [
    project
  ]
}

// Create a module to assign all roles to an identity
module assignRolesToHubIdentity 'identityRoleAssignments.bicep' = {
  name: 'assignRolesToHubIdentity'
  params: {
    principalId: lookupAiFoundryHub.identity.principalId
    openaiAccountName: openaiAccountName
    searchResourceId: searchResourceId
    keyVaultId: keyVaultId
  }
}

// Create a module to assign all roles to project identity
module assignRolesToProjectIdentity 'identityRoleAssignments.bicep' = {
  name: 'assignRolesToProjectIdentity'
  params: {
    principalId: lookupAiFoundryProject.identity.principalId
    openaiAccountName: openaiAccountName
    searchResourceId: searchResourceId
    keyVaultId: keyVaultId
  }
}

// Output the AI Foundry Hub resource ID and principal ID for potential use by other modules
output aiFoundryHubResourceId string = lookupAiFoundryHub.id
output aiFoundryHubPrincipalId string = lookupAiFoundryHub.identity.principalId
// Output the AI Foundry Project resource ID and principal ID
output aiFoundryProjectResourceId string = lookupAiFoundryProject.id
output aiFoundryProjectPrincipalId string = lookupAiFoundryProject.identity.principalId

