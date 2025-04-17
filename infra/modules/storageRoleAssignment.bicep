
param principalId string
param storageAccountName string
param roleName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}
var roleMapping = {
  'Storage Blob Data Contributor': 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  'Storage Blob Data Reader': '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  'Storage File Data Privileged Contributor': '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleMapping[roleName]) 

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId) && !empty(roleMapping[roleName])) {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

