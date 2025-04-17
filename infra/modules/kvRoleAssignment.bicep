// Key Vault Role Assignment module
// This module assigns roles to a principal ID for Azure Key Vault

@description('The principal ID to assign the role to')
param principalId string

@description('The full resource ID of the Azure Key Vault')
param keyVaultId string

@description('Role to assign - must match a key in the roleMapping object')
param roleName string

var roleMapping = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Secrets Officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
  'Key Vault Certificates Officer': 'a4417e6f-fecd-4de8-b567-7b0420556985'
  'Key Vault Crypto Officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  'Key Vault Crypto User': '12338af0-0e69-4776-bea7-57ae8d297424'
}

// Get the Key Vault resource
// Note: the parameter is expected to be a resource ID, so we'll extract the name
var keyVaultResourceParts = split(keyVaultId, '/')
var keyVaultName = length(keyVaultResourceParts) > 1 ? last(keyVaultResourceParts) : keyVaultId

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleMapping[roleName])

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId) && !empty(roleMapping[roleName])) {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
