targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention, the name of the resource group for your application will use this name, prefixed with rg-')
param environmentName string

@minLength(1)
@description('The location used for all deployed resources')
// Look for the desired model in availability table. Default model is gpt-4o-mini:
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#standard-deployment-model-availability
@allowed([
  'westus3'
])
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Flag to decide where to create OpenAI role for current user')
param createRoleForUser bool = true

var userId = createRoleForUser ? principalId : ''

var tags = {
  'azd-env-name': environmentName
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
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
  }
}

////////////////////////////////////////
// START DEEPSEEK MODEL DEPLOYMENT
////////////////////////////////////////
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var disableKeyBasedAuth = true

var aiServicesNameAndSubdomain = '${resourceToken}-aiservices'
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
        principalId: principalId
        principalType: 'User'
        roleDefinitionIdOrName: 'Cognitive Services User'
      }
    ]
  }
}

////////////////////////////////////////
// END DEEPSEEK MODEL DEPLOYMENT
////////////////////////////////////////

// module deepseekr1 'deepseekr1/deepseekr1.bicep' = {
//   name: 'deepseekr1'
//   params: {
//     location: location
//     environmentName: environmentName
//     principalId: principalId
//     userId: userId
//   }
// }

// module openai 'openai/openai.module.bicep' = {
//   name: 'openai'
//   scope: rg
//   params: {
//     location: location
//     principalId: resources.outputs.MANAGED_IDENTITY_PRINCIPAL_ID
//     principalType: 'ServicePrincipal'
//     userId: userId
//   }
// }


output MANAGED_IDENTITY_CLIENT_ID string = resources.outputs.MANAGED_IDENTITY_CLIENT_ID
output MANAGED_IDENTITY_NAME string = resources.outputs.MANAGED_IDENTITY_NAME
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = resources.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = resources.outputs.AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN
output AZURE_RESOURCE_GROUP string = rg.name
output CONNECTIONSTRINGS__OPENAI string = 'Endpoint=https://${deepseekr1.outputs.name}.services.ai.azure.com/'
//output CONNECTIONSTRINGS__OPENAI string = deepseekr1.outputs.connectionString
