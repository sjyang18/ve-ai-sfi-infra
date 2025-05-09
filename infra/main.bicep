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

@description('List of CIDR blocks to allow access to the Azure OpenAI service and Azure Search.')
param allowedCidrBlocks array

var varAllowedCidrBlocks = [for cidrBlock in allowedCidrBlocks: {
  value: cidrBlock
}]

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

var _embeddingsDeploymentName = 'text-embedding-3-large-deployment'
var _embeddingsModelName = 'text-embedding-3-large'
var _embeddingsModelVersion = '1'
var _embeddingsDeploymentType = 'Standard'
var _embeddingsDeploymentCapacity = 120

var ipAllowList = concat([
  {
    value: azurePortalAccessIp
  }
  {
    value: lbPublicIpAadress.outputs.ipAddress
  }
], varAllowedCidrBlocks)

// Add Log Analytics Workspace at resource group scope
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.5.0' = {
  name: 'log-analytics-workspace-deployment'
  scope: rg
  params: {
    name: '${resourceNamePrefix}-law'
    location: location
    dataRetention: 30
    skuName: 'PerGB2018'
    tags: tags
  }
}

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
        ]
        defaultOutboundAccess: false
      }
      {
        name: 'WebAppSubnet'
        addressPrefix: '10.0.2.0/24'
        delegation: 'Microsoft.Web/serverFarms'
        networkSecurityGroupResourceId: m365nsg.outputs.id
        defaultOutboundAccess: false       
      }
      {
        name: 'ShellSubnet'
        addressPrefix: '10.0.3.0/24'
        delegation: 'Microsoft.ContainerInstance/containerGroups'
        networkSecurityGroupResourceId: m365nsg.outputs.id
        defaultOutboundAccess: false
      }
      {
        name: 'JumpboxSubnet'
        addressPrefix: '10.0.63.0/26'
        networkSecurityGroupResourceId: bastionNsg.outputs.id
        defaultOutboundAccess: false
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.64.0/26'
        networkSecurityGroupResourceId: bastionNsg.outputs.id
        defaultOutboundAccess: false
      }
    ]
    tags: tags
  }
}

module lbPublicIpAadress 'br/public:avm/res/network/public-ip-address:0.8.0' = {
  name: 'loadBalancerPublicIp'
  scope: rg
  params: {
    name: '${resourceNamePrefix}-lb-pip'
    location: location
    skuName: 'Standard'
    skuTier: 'Regional'
    publicIPAllocationMethod: 'Static'
    tags: tags
  }
}
module loadBalancer 'br/public:avm/res/network/load-balancer:0.4.1' = {
  name: 'loadBalancerDeployment'
  scope: rg
  params: {
    name: '${resourceNamePrefix}-lb'
    location: location
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontend'
        publicIPAddressId: lbPublicIpAadress.outputs.resourceId
      }
    ]
    backendAddressPools: [
      {
        name: 'JumpboxBackendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'JumpboxLoadBalancingRule'
        frontendIPConfigurationName: 'LoadBalancerFrontend'
        backendAddressPoolName: 'JumpboxBackendPool'
        frontendPort: 3389
        backendPort: 3389
        protocol: 'Tcp'
        enableFloatingIP: false
        idleTimeoutInMinutes: 4
        enableTcpReset: false
        probeName: 'JumpboxHealthProbe'
      }
    ]
    outboundRules: [
      {
        name: 'OutboundRule1'
        protocol: 'All'
        frontendIPConfigurationName: 'LoadBalancerFrontend'
        backendAddressPoolName: 'JumpboxBackendPool'
        idleTimeoutInMinutes: 4
        enableTcpReset: false
      }
    ]
    probes: [
      {
        name: 'JumpboxHealthProbe'
        protocol: 'Tcp'
        port: 3389
        intervalInSeconds: 15
        numberOfProbes: 2
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

// Generate a more unpredictable password for the jumpbox VM
param utcTime string = utcNow()
var deploymentTimeHash = uniqueString(deployment().name, utcTime)
var subscriptionHash = uniqueString(subscription().subscriptionId)
var resourceGroupHash = uniqueString(resourceGroupName)
var jumpboxPassword = 'JBox${toUpper(substring(deploymentTimeHash, 0, 3))}@${substring(subscriptionHash, 0, 4)}${substring(resourceGroupHash, 0, 3)}!'
var jumpboxVmName = substring('${resourceNamePrefix}jbx', 0, min(15, length('${resourceNamePrefix}jbx')))

// Add jumpbox VM for remote administration
module jumpboxVm 'br/public:avm/res/compute/virtual-machine:0.12.3' = {
  name: 'jumpbox-vm-deployment'
  scope: rg
  params: {
    name: jumpboxVmName
    location: location
    adminUsername: 'azureuser'
    licenseType: 'Windows_Server'
    zone: 3
    adminPassword: jumpboxPassword
    // Fix NIC configurations to remove backend pool association that's causing the conflict
    nicConfigurations: [
      {
        name: '${resourceNamePrefix}-jumpbox-nic-configuration'  // Add explicit name
        nicSuffix: '-nic'  // Add suffix
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: vnetDeployment.outputs.subnetResourceIds[3] // JumpboxSubnet
            privateIPAllocationMethod: 'Dynamic'
            // Removing loadBalancerBackendAddressPools to avoid conflict with load balancer
          }
        ]
        enableAcceleratedNetworking: true
      }
    ]
    osType: 'Windows'
    computerName: jumpboxVmName
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition-hotpatch-smalldisk'
      version: 'latest'
    }
    osDisk: {
      createOption: 'FromImage'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    vmSize: 'Standard_DS1_v2'
    enableAutomaticUpdates: true
    vTpmEnabled: true
    secureBootEnabled: true
    securityType: 'TrustedLaunch'
    patchMode: 'AutomaticByPlatform'
    patchAssessmentMode: 'ImageDefault'
    provisionVMAgent: true
    encryptionAtHost: false
    rebootSetting: 'IfRequired'
    tags: tags
  }
  dependsOn: [
    bastionHost
  ]
}

// After the jumpbox VM deployment, add this module to associate the VM's NIC with the backend pool
module associateJumpboxToBackendPool 'br/public:avm/res/network/network-interface:0.5.0' = {
  name: 'associate-jumpbox-to-backendpool'
  scope: rg
  params: {
    name: '${jumpboxVmName}-nic'
    location: location
    ipConfigurations: [
      {
        name: 'ipconfig1'
        subnetResourceId: vnetDeployment.outputs.subnetResourceIds[3] // JumpboxSubnet
        privateIPAllocationMethod: 'Dynamic'
        loadBalancerBackendAddressPools: [
          {
            id: loadBalancer.outputs.backendpools[0].id // JumpboxBackendPool
          }
        ]
      }
    ]
    tags: tags
  }
  dependsOn: [
    jumpboxVm
    loadBalancer
  ]
}

module privateDnsZones 'modules/privateDnsZones.bicep' = {
  name: 'privateDnsZones'
  scope: rg
  params: {
    vnetId: vnetDeployment.outputs.resourceId
    tags: tags
  }
}

// Add App Service Plan and Web App
var appServicePlanName = '${resourceNamePrefix}-plan'
var webAppName = '${resourceNamePrefix}-webapp'

module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'app-service-plan-deployment'
  scope: rg
  params: {
    name: appServicePlanName
    location: location
    skuName: 'S1' 
    skuCapacity: 1 
    reserved: true
    tags: tags
  }
}

module webApp 'br/public:avm/res/web/site:0.15.1' = {
  name: 'web-app-deployment'
  scope: rg
  params: {
    name: webAppName
    location: location
    kind: 'app,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    virtualNetworkSubnetId: vnetDeployment.outputs.subnetResourceIds[1] // WebAppSubnet
    managedIdentities: {
      systemAssigned: true
    }
    siteConfig: {
      acrUseManagedIdentityCreds: false
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 0
      alwaysOn: true
      linuxFxVersion: 'PYTHON|3.11'
      vnetRouteAllEnabled: true // Route all traffic through VNet
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      appSettings: [
        {
          name: 'AZURE_OPENAI_SERVICE'
          value: aoaiServiceName
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: aoaiDeployment.outputs.endpoint
        }
        {
          name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT'
          value: _chatGptDeploymentName
        }
        {
          name: 'AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT'
          value: _embeddingsDeploymentName
        }
        {
          name: 'AZURE_SEARCH_SERVICE'
          value: searchServiceName
        }
        {
          name: 'AZURE_SEARCH_ENDPOINT'
          value: lookupSearchService.properties.endpoint
        }
        {
          name: 'AZURE_SEARCH_INDEX'
          value: 'your-search-index'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: ''
        }
      ]
    }
    tags: tags
  }
  dependsOn: [
    keyvaultDeployment
  ]
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
    diagnosticSettings: [
      {
        name: 'keyvault-diagnostic-settings'
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
        logCategoriesAndGroups:[
          {
            category: null
            categoryGroup: 'audit'
            enabled: true
          }
          {
            category: null
            categoryGroup: 'allLogs'
            enabled: true
          }
        ]
      }
      
    ]
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
    privateDnsZoneGroup: {
      name: 'default'
      privateDnsZoneGroupConfigs: [
        {
          name: 'keyvaultDnsZone'
          privateDnsZoneResourceId: privateDnsZones.outputs.keyvaultDnsZoneId
        }
      ]
    }
    tags: tags
  }
}

module aoaiDeployment 'br/public:avm/res/cognitive-services/account:0.10.2' = {
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
      ]
      ipRules: ipAllowList
      bypass: 'AzureServices'
    }
    diagnosticSettings: [
      {
        name: 'aoai-diagnostic-settings'
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
        logCategoriesAndGroups:[
          {
            category: null
            categoryGroup: 'audit'
            enabled: true
          }
          {
            category: null
            categoryGroup: 'allLogs'
            enabled: true
          }
        ]
      }
    ]
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

// Note: Due to this issue(https://github.com/Azure/AzOps/issues/740) and need for support for qna feature,
// for now, search service is deployed with addOrApiKey
module searchServiceDeployment 'br/public:avm/res/search/search-service:0.9.2' = {
  name: 'search-service-deployment'
  scope: rg
  params: {
    name: searchServiceName
    location: location
    sku: 'basic'
    partitionCount: 1
    replicaCount: 1
    disableLocalAuth: false // issue 740-> local authentication
    managedIdentities: {
      systemAssigned: true
    }
    authOptions:{
      aadOrApiKey:{ aadAuthFailureMode:'http401WithBearerChallenge'}
    }
    //Note: authOptions: null // disable local auth => this should be null
    publicNetworkAccess: 'Enabled' // to open up the service to firewall-based access.
    networkRuleSet: {
      ipRules: ipAllowList
      bypass: 'AzurePortal'
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Search Service Contributor'
        principalId: aoaiDeployment.outputs.?systemAssignedMIPrincipalId ?? ''
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName:'Search Index Data Contributor'
        principalId: aoaiDeployment.outputs.?systemAssignedMIPrincipalId ?? ''
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName:'Search Index Data Reader'
        principalId:  aoaiDeployment.outputs.?systemAssignedMIPrincipalId ?? ''
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
    diagnosticSettings: [
      {
        name: 'search-service-diagnostic-settings'
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
        logCategoriesAndGroups:[
          {
            category: null
            categoryGroup: 'audit'
            enabled: true
          }
          {
            category: null
            categoryGroup: 'allLogs'
            enabled: true
          }
        ]
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
      virtualNetworkRules: []
      ipRules: ipAllowList
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
      {
        principalId: userPrincipalId
        roleDefinitionIdOrName: 'Storage File Data Privileged Contributor'
        principalType: 'User'
      }
    ]
    diagnosticSettings: [
      {
        name: 'storage-account-diagnostic-settings'
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
        logCategoriesAndGroups:[
          {
            category: 'StorageRead'
            enabled: true
          }
          {
            category:'StorageWrite'
            enabled: true
          }
          {
            category:'StorageDelete'
            enabled: true
          }
        ]
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
    principalId: aoaiDeployment.outputs.?systemAssignedMIPrincipalId ?? ''
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
    privateDnsZoneGroup: {
      name: 'default'
      privateDnsZoneGroupConfigs: [
        {
          name: 'blobDnsZone'
          privateDnsZoneResourceId: privateDnsZones.outputs.blobDnsZoneId
        }
      ]
    }
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
    privateDnsZoneGroup: {
      name: 'default'
      privateDnsZoneGroupConfigs: [
        {
          name: 'onpenaiDnsZone'
          privateDnsZoneResourceId: privateDnsZones.outputs.openAIDnsZoneId
        }
      ]
    }
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
    privateDnsZoneGroup: {
      name: 'srcDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'srcDnsZoneGroup'
          privateDnsZoneResourceId: privateDnsZones.outputs.aiSearchDnsZoneId
        }
      ]
    }
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
  }
}

// Grant the Web App's managed identity access to Azure OpenAI
module webAppOpenAiRoleAssignment 'modules/aiServiceRoleAssignment.bicep' = {
  name: 'webAppOpenAiRoleAssignment'
  scope: rg
  params: {
    // Added safe access operator and default value
    principalId: webApp.outputs.?systemAssignedMIPrincipalId ?? '' 
    openaiAccountName: aoaiServiceName
  }
}

// Grant the Web App's managed identity access to Azure Search
module webAppSearchRoleAssignment 'modules/searchRoleAssignment.bicep' = {
  name: 'webAppSearchRoleAssignment'
  scope: rg
  params: {
    // Added safe access operator and default value
    principalId: webApp.outputs.?systemAssignedMIPrincipalId ?? '' 
    searchAccountName: searchServiceName
    roleName: 'Search Index Data Reader'
  }
  dependsOn: [
    searchServiceDeployment
  ]
}

// Grant the Web App's managed identity access to Key Vault secrets
module webAppKeyVaultRoleAssignment 'modules/kvRoleAssignment.bicep' = {
  name: 'webAppKeyVaultRoleAssignment'
  scope: rg
  params: {
    // Added safe access operator and default value
    principalId: webApp.outputs.?systemAssignedMIPrincipalId ?? '' 
    keyVaultId: keyvaultName
    roleName: 'Key Vault Secrets User'
  }
  dependsOn: [
    keyvaultDeployment
  ]
}

// Lookup the Azure Search service to get its endpoint for the AI Foundry hub
resource lookupSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: searchServiceName
  scope: rg
  dependsOn: [
    trustAzureServicesInSearch
    searchServiceDeployment
  ]
}

module aiFoundryResource 'modules/aiFoundry/main.bicep' = {
  name: 'aiFoundryDeployment'
  scope: rg
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    keyVaultId: keyvaultDeployment.outputs.resourceId
    openAiResourceId: aoaiDeployment.outputs.resourceId
    searchResourceId: searchServiceDeployment.outputs.resourceId
    openaiAccountName: aoaiServiceName
    searchResourceName: searchServiceName
    azureSearchTargetUrl: lookupSearchService.properties.endpoint
    azureOpenAiTargetUrl: aoaiDeployment.outputs.endpoint
    userPrincipalId: userPrincipalId
    ipAllowList: ipAllowList
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.resourceId
  }
  dependsOn: [
    trustAzureServicesInSearch
    storageAccountPrivateEndpoint
    keyvaultPrivateEndpoint
    aoaiPrivateEndpoint
    searchPrivateEndpoint
  ]
}


