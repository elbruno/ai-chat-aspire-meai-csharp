targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param aichatappWebisolExists bool
@secure()
param aichatappWebisolDefinition object

@description('Id of the user or app to assign application roles')
param principalId string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    aichatappWebisolExists: aichatappWebisolExists
    aichatappWebisolDefinition: aichatappWebisolDefinition
  }
}

////////////////////////////////////////
// START DEEPSEEK MODEL DEPLOYMENT
////////////////////////////////////////
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// var disableKeyBasedAuth = true

var aiServicesNameAndSubdomain = 'aideepseekr1-${resourceToken}'
module deepseekr1 'br/public:avm/res/cognitive-services/account:0.7.2' = {
  name: 'deepseek'
  scope: rg
  params: {
    name: aiServicesNameAndSubdomain
    location: location
    tags: tags
    kind: 'AIServices'
    customSubDomainName: aiServicesNameAndSubdomain
    publicNetworkAccess: 'Enabled'
    sku:  'S0'
    deployments: [
      {
        name: 'DeepSeek-R1'
        model: {
          format: 'DeepSeek'
          name: 'DeepSeek-R1'
          version: '1'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 1
        }
      }]
    disableLocalAuth: false
    roleAssignments: [
      {
        principalId: resources.outputs.MANAGED_IDENTITY_PRINCIPAL_ID 
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'        
      }
      {
        principalId: resources.outputs.MANAGED_IDENTITY_PRINCIPAL_ID
        roleDefinitionIdOrName: 'Cognitive Services User'
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'        
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Cognitive Services User'
      }
    ]
  }
}

////////////////////////////////////////
// END DEEPSEEK MODEL DEPLOYMENT
////////////////////////////////////////


output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_KEY_VAULT_ENDPOINT string = resources.outputs.AZURE_KEY_VAULT_ENDPOINT
output AZURE_KEY_VAULT_NAME string = resources.outputs.AZURE_KEY_VAULT_NAME
output AZURE_RESOURCE_AICHATAPP_WEBISOL_ID string = resources.outputs.AZURE_RESOURCE_AICHATAPP_WEBISOL_ID

  output CONNECTIONSTRINGS__OPENAI string = 'Endpoint=https://${deepseekr1.outputs.name}.services.ai.azure.com/'