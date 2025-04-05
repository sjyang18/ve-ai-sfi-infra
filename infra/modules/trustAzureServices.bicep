param name string
param managedIdentityResourceId string
param location string = resourceGroup().location
param resourceId string


// This implements https://learn.microsoft.com/en-us/azure/ai-services/cognitive-services-virtual-networks?tabs=portal#using-the-azure-cli
module deploymentScript 'br/public:avm/res/resources/deployment-script:0.5.1' = {
  name: '${name}ScriptDeployment'
  params: {
    // Required parameters
    kind: 'AzureCLI'
    name:  name
    // Non-required parameters
    azCliVersion: '2.52.0'
    environmentVariables: [
      {
        name: 'RESOURCE_ID'
        value: resourceId
      }
    ]
    location: location
    managedIdentities: {
      userAssignedResourceIds: [
        managedIdentityResourceId
      ]
    }
    retentionInterval: 'P1D'
    scriptContent: '''
      #!/bin/bash
      set -e
      set -x

      # Define the resource ID
      rid="$RESOURCE_ID"
      
      # First, get the current network configuration
      current_config=$(az rest --method GET --uri "https://management.azure.com$rid?api-version=2024-06-01-Preview")
      
      # Extract the current IP rules if they exist
      # Use jq to safely handle cases where ipRules might not exist
      current_ip_rules=$(echo $current_config | jq -c '.properties.networkRuleSet.ipRules // []')
      
      # Use a here document to allow variable expansion in the JSON body
      az rest --method PATCH --uri "https://management.azure.com$rid?api-version=2024-06-01-Preview" \
      --headers "Content-Type=application/json" \
      --body @- << EOF
      {
          "properties": {
              "networkRuleSet": {
                  "bypass": "AzureServices",
                  "ipRules": $current_ip_rules
              }
          }
      }
EOF
    '''
  }
}
