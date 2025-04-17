// Azure Cognitive Search Role Assignment module
// This module assigns roles to a principal ID for Azure Cognitive Search services

@description('The principal ID to assign the role to')
param principalId string

@description('The full resource ID of the Azure Cognitive Search service')
param searchAccountName string

@description('Role to assign - must match a key in the roleMapping object')
param roleName string

var roleMapping = {
  'Search Index Data Reader': '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  'Search Index Data Contributor': '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  'Search Service Contributor': '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
}

// Get the search service resource
// Note: the parameter is expected to be a resource ID, so we'll extract the name
var searchResourceParts = split(searchAccountName, '/')
var searchServiceName = length(searchResourceParts) > 1 ? last(searchResourceParts) : searchAccountName

resource searchService 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchServiceName
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleMapping[roleName])

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId) && !empty(roleMapping[roleName])) {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  scope: searchService
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
