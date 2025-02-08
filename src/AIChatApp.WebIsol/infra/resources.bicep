@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}


param aichatappWebisolExists bool
@secure()
param aichatappWebisolDefinition object

@description('Id of the user or app to assign application roles')
param principalId string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    acrAdminUserEnabled: true
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: aichatappWebisolIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module aichatappWebisolIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'aichatappWebisolidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}aichatappWebisol-${resourceToken}'
    location: location
  }
}

module aichatappWebisolFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'aichatappWebisol-fetch-image'
  params: {
    exists: aichatappWebisolExists
    name: 'aichatapp-webisol'
  }
}

var aichatappWebisolAppSettingsArray = filter(array(aichatappWebisolDefinition.settings), i => i.name != '')
var aichatappWebisolSecrets = map(filter(aichatappWebisolAppSettingsArray, i => i.?secret != null), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var aichatappWebisolEnv = map(filter(aichatappWebisolAppSettingsArray, i => i.?secret == null), i => {
  name: i.name
  value: i.value
})

module aichatappWebisol 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'aichatappWebisol'
  params: {
    name: 'aichatapp-webisol'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  union([
      ],
      map(aichatappWebisolSecrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    containers: [
      {
        image: aichatappWebisolFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: union([
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: aichatappWebisolIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '80'
          }
        ],
        aichatappWebisolEnv,
        map(aichatappWebisolSecrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
        }))
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [aichatappWebisolIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: aichatappWebisolIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'aichatapp-webisol' })
  }
}
// Create a keyvault to store secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyvault'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enableRbacAuthorization: false
    accessPolicies: [
      {
        objectId: principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
      {
        objectId: aichatappWebisolIdentity.outputs.principalId
        permissions: {
          secrets: [ 'get', 'list' ]
        }
      }
    ]
    secrets: [
    ]
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_RESOURCE_AICHATAPP_WEBISOL_ID string = aichatappWebisol.outputs.resourceId

output MANAGED_IDENTITY_CLIENT_ID string = aichatappWebisolIdentity.outputs.clientId
output MANAGED_IDENTITY_NAME string = aichatappWebisolIdentity.name
output MANAGED_IDENTITY_PRINCIPAL_ID string = aichatappWebisolIdentity.outputs.principalId