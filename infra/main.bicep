targetScope = 'subscription'

@description('Environment name: test or prod. Drives naming, SKUs, and retention/scale settings.')
@allowed(['test', 'prod'])
param environment string

@description('Azure region for all resources.')
param location string = 'australiaeast'

@description('Publisher email required by API Management.')
param apimPublisherEmail string = 'admin@pingpongmania.dev'

@description('Publisher name required by API Management.')
param apimPublisherName string = 'PingPongMania'

@description('.NET isolated worker runtime version for the Function Apps.')
param dotnetVersion string = '10.0'

// --- Environment-specific deltas ---
var isProd = environment == 'prod'
var appInsightsSamplingPercentage = isProd ? 50 : 100
var functionMaxInstanceCount = isProd ? 10 : 40
var serviceBusMessageTtl = isProd ? 'P7D' : 'P1D'
var apimRateLimitCalls = isProd ? 30 : 100
var keyVaultSoftDeleteRetentionDays = isProd ? 90 : 7

var workload = 'pingpongmania'
var tags = {
  environment: environment
  workload: workload
  'managed-by': 'bicep'
}

var names = {
  resourceGroup: 'rg-${workload}-${environment}'
  logAnalytics: 'log-${workload}-${environment}'
  appInsights: 'appi-${workload}-${environment}'
  keyVault: 'kv-${workload}-${environment}'
  storageAccount: 'st${workload}${environment}'
  serviceBus: 'sb-${workload}-${environment}'
  functionPlan: 'asp-${workload}-${environment}'
  functionPing: 'func-ping-${environment}'
  functionPlay: 'func-play-${environment}'
  functionPong: 'func-pong-${environment}'
  logicApp: 'logic-${workload}-${environment}'
  apim: 'apim-${workload}-${environment}'
}

var deploymentContainers = {
  ping: 'app-package-ping'
  play: 'app-package-play'
  pong: 'app-package-pong'
}

var pingTableName = 'pings'
var pingQueueName = 'ping-queue'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: names.resourceGroup
  location: location
  tags: tags
}

// prod is protected from accidental deletion; test is left removable for iteration
module prodLock 'modules/resource-lock.bicep' = if (isProd) {
  name: 'prod-lock'
  scope: rg
  params: {
    name: 'CanNotDelete-${names.resourceGroup}'
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of the prod PingPongMania resource group.'
  }
}

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    name: names.logAnalytics
    location: location
    tags: tags
  }
}

module appInsights 'modules/app-insights.bicep' = {
  name: 'app-insights'
  scope: rg
  params: {
    name: names.appInsights
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    samplingPercentage: appInsightsSamplingPercentage
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    name: names.keyVault
    location: location
    tags: tags
    softDeleteRetentionInDays: keyVaultSoftDeleteRetentionDays
  }
}

module storageAccount 'modules/storage-account.bicep' = {
  name: 'storage-account'
  scope: rg
  params: {
    name: names.storageAccount
    location: location
    tags: tags
    containerNames: [
      deploymentContainers.ping
      deploymentContainers.play
      deploymentContainers.pong
    ]
    tableNames: [pingTableName]
  }
}

module serviceBus 'modules/service-bus.bicep' = {
  name: 'service-bus'
  scope: rg
  params: {
    name: names.serviceBus
    location: location
    tags: tags
    queueName: pingQueueName
    defaultMessageTimeToLive: serviceBusMessageTtl
  }
}

module functionPlan 'modules/flex-consumption-plan.bicep' = {
  name: 'function-plan'
  scope: rg
  params: {
    name: names.functionPlan
    location: location
    tags: tags
  }
}

module pongFunctionApp 'modules/function-app.bicep' = {
  name: 'function-app-pong'
  scope: rg
  params: {
    name: names.functionPong
    location: location
    tags: tags
    appServicePlanResourceId: functionPlan.outputs.resourceId
    storageAccountResourceId: storageAccount.outputs.resourceId
    storageAccountBlobEndpoint: storageAccount.outputs.primaryBlobEndpoint
    deploymentContainerName: deploymentContainers.pong
    applicationInsightsResourceId: appInsights.outputs.resourceId
    dotnetVersion: dotnetVersion
    maximumInstanceCount: functionMaxInstanceCount
  }
}

module pingFunctionApp 'modules/function-app.bicep' = {
  name: 'function-app-ping'
  scope: rg
  params: {
    name: names.functionPing
    location: location
    tags: tags
    appServicePlanResourceId: functionPlan.outputs.resourceId
    storageAccountResourceId: storageAccount.outputs.resourceId
    storageAccountBlobEndpoint: storageAccount.outputs.primaryBlobEndpoint
    deploymentContainerName: deploymentContainers.ping
    applicationInsightsResourceId: appInsights.outputs.resourceId
    dotnetVersion: dotnetVersion
    maximumInstanceCount: functionMaxInstanceCount
    additionalAppSettings: {
      PongBaseUrl: 'https://${pongFunctionApp.outputs.defaultHostname}'
      PingsTableConnection__tableServiceUri: storageAccount.outputs.primaryTableEndpoint
      PingsTableConnection__credential: 'managedidentity'
      ServiceBusConnection__fullyQualifiedNamespace: serviceBus.outputs.fullyQualifiedNamespace
      ServiceBusConnection__credential: 'managedidentity'
    }
  }
}

module playFunctionApp 'modules/function-app.bicep' = {
  name: 'function-app-play'
  scope: rg
  params: {
    name: names.functionPlay
    location: location
    tags: tags
    appServicePlanResourceId: functionPlan.outputs.resourceId
    storageAccountResourceId: storageAccount.outputs.resourceId
    storageAccountBlobEndpoint: storageAccount.outputs.primaryBlobEndpoint
    deploymentContainerName: deploymentContainers.play
    applicationInsightsResourceId: appInsights.outputs.resourceId
    dotnetVersion: dotnetVersion
    maximumInstanceCount: functionMaxInstanceCount
    additionalAppSettings: {
      // Not used by the live Azure call path (the Logic App calls Ping directly) -- kept so
      // this Function App still works standalone for direct testing, mirroring local dev.
      PingBaseUrl: 'https://${pingFunctionApp.outputs.defaultHostname}'
    }
  }
}

// RBAC: least-privilege, scoped to the specific resource each identity actually needs.
// Wrapped in its own resource-group-scoped module because a subscription-scoped root
// template can't set a module's `scope:` to an arbitrary existing-resource symbol directly.
module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    storageAccountName: storageAccount.outputs.name
    keyVaultName: keyVault.outputs.name
    serviceBusNamespaceName: serviceBus.outputs.name
    serviceBusQueueName: pingQueueName
    pingPrincipalId: pingFunctionApp.outputs.systemAssignedMIPrincipalId
    playPrincipalId: playFunctionApp.outputs.systemAssignedMIPrincipalId
    pongPrincipalId: pongFunctionApp.outputs.systemAssignedMIPrincipalId
    logicAppPrincipalId: logicApp.outputs.systemAssignedMIPrincipalId
  }
}

// Ping's default host key, so the Logic App can call api/ping without Easy Auth/AAD app-to-app
// complexity -- a deliberate simplification for this sample's "pragmatic" rigor level.
// (Computed inside logic-app.bicep itself -- see the note there.)
module logicApp 'modules/logic-app.bicep' = {
  name: 'logic-app'
  scope: rg
  params: {
    name: names.logicApp
    location: location
    tags: tags
    serviceBusFullyQualifiedNamespace: serviceBus.outputs.fullyQualifiedNamespace
    serviceBusQueueName: pingQueueName
    pingFunctionAppName: pingFunctionApp.outputs.name
    pingFunctionAppUrl: 'https://${pingFunctionApp.outputs.defaultHostname}'
  }
}

module apim 'modules/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    name: names.apim
    location: location
    tags: tags
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    logicAppName: logicApp.outputs.name
    rateLimitCalls: apimRateLimitCalls
  }
}

output resourceGroupName string = rg.name
output apimGatewayUrl string = apim.outputs.gatewayUrl
output functionAppNames object = {
  ping: pingFunctionApp.outputs.name
  play: playFunctionApp.outputs.name
  pong: pongFunctionApp.outputs.name
}
