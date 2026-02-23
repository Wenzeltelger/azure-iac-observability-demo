@description('Location for all resources')
param location string = resourceGroup().location

@description('Web App name (frontend)')
param appName string

@description('Tags object')
param tags object = {
  environment: 'dev'
  project: 'azure-iac-observability-demo'
}

@description('Name of the Key Vault secret to read')
param secretName string = 'DemoSecret'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${appName}-plan'
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  tags: tags
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-appi'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
  tags: tags
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

var kvName = 'kv${uniqueString(subscription().id, resourceGroup().id, appName)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }

    // RBAC-based permissions (recommended)
    enableRbacAuthorization: true

    // For demo simplicity. In “pro hardening” we can restrict networks later.
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

var storageName = toLower('st${uniqueString(subscription().id, resourceGroup().id, appName)}')

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

var storageKeys = listKeys(storage.id, '2023-01-01')
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

var funcPlanName = 'aspfunc-${uniqueString(resourceGroup().id, appName)}'

resource functionPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: funcPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  tags: tags
}

var functionAppName = 'func${uniqueString(subscription().id, resourceGroup().id, appName)}'

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: functionPlan.id
    siteConfig: {
      appSettings: [
        // Required for Functions
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }

        // Key Vault settings consumed by your code
        {
          name: 'KEYVAULT_URI'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'SECRET_NAME'
          value: secretName
        }
      ]
    }
    httpsOnly: true
  }
}

var kvSecretsUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
)

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // name debe ser calculable al inicio -> NO uses principalId ni reference() aquí
  name: guid(keyVault.id, 'kv-secrets-user', functionApp.name)
  scope: keyVault
  properties: {
    roleDefinitionId: kvSecretsUserRoleDefinitionId
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output webAppName string = webApp.name
output appInsightsName string = appInsights.name
output keyVaultName string = keyVault.name
output functionAppName string = functionApp.name
output functionBaseUrl string = 'https://${functionApp.name}.azurewebsites.net'