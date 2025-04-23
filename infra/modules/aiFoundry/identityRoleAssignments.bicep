// Identity Role Assignments module
// This module handles all role assignments for a given AI Foundry identity (Hub or Project)

@description('The principal ID of the identity to assign roles to')
param principalId string

@description('Azure OpenAI service name')
param openaiAccountName string


@description('Azure Search service resource ID')
param searchResourceId string

@description('Key Vault resource ID')
param keyVaultId string

// Grant the managed identity access to Azure OpenAI
module grantOpenAiAccess '../../modules/aiServiceRoleAssignment.bicep' = {
  name: 'grantOpenAiAccess-${uniqueString(principalId, openaiAccountName)}'
  params: {
    principalId: principalId
    openaiAccountName: openaiAccountName
  }
}

// Define search role assignment
module searchRoleAssignment '../../modules/searchRoleAssignment.bicep' = {
  name: 'searchRoleAssignment-${uniqueString(principalId, searchResourceId)}'
  params: {
    principalId: principalId
    searchAccountName: searchResourceId
    roleName: 'Search Index Data Contributor'
  }
}


module searchServiceContributorRole '../../modules/searchRoleAssignment.bicep' = {
  name: 'searchServiceContributorRole-${uniqueString(principalId, searchResourceId)}'
  params: {
    principalId: principalId
    searchAccountName: searchResourceId
    roleName: 'Search Service Contributor'
  }
}


// Grant Key Vault Secrets Officer role
module kvSecretsOfficerRoleAssignment '../../modules/kvRoleAssignment.bicep' = {
  name: 'kvSecretsOfficerRoleAssignment-${uniqueString(principalId, keyVaultId)}'
  params: {
    principalId: principalId
    keyVaultId: keyVaultId
    roleName: 'Key Vault Secrets Officer'
  }
}
