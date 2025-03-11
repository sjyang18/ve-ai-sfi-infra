param name string
param managedIdentityResourceId string
param location string = resourceGroup().location
param resourceId string
param azurePortalAccessIp string = '52.252.175.48'  // nslookup stamp2.ext.search.windows.net


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
      {
        name: 'AZURE_PORTAL_ACCESS_IP'
        value: azurePortalAccessIp
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

      # Get the access token using managed identity
      # accessToken=$(curl -H "Metadata: true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https://management.azure.com" | jq -r '.access_token')

      # Define the resource ID
      rid="$RESOURCE_ID"
      
      # Use a here document to allow variable expansion in the JSON body
      az rest --method PATCH --uri "https://management.azure.com$rid?api-version=2024-06-01-Preview" \
      --headers "Content-Type=application/json" \
      --body @- << EOF
      {
          "properties": {
              "networkRuleSet": {
                  "bypass": "AzureServices",
                  "ipRules": [
                  {
                      "value": "$AZURE_PORTAL_ACCESS_IP"
                  }
              ],
              }
          }
      }
EOF
    '''
  }
}
