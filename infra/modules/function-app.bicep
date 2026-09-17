@description('Name of the Function App.')
param name string

@description('Azure region for the Function App.')
param location string = resourceGroup().location

@description('Tags applied to the Function App.')
param tags object = {}

@description('Resource ID of the Flex Consumption App Service Plan.')
param appServicePlanResourceId string

@description('Resource ID of the shared storage account (host storage + deployment package storage).')
param storageAccountResourceId string

@description('Primary blob endpoint of the shared storage account.')
param storageAccountBlobEndpoint string

@description('Blob container this app\'s deployment package is published to.')
param deploymentContainerName string

@description('Resource ID of the Application Insights component.')
param applicationInsightsResourceId string

@description('.NET version for the isolated worker runtime, e.g. "10.0". Verify Flex Consumption GA support for this version before deploying -- func Core Tools supports it locally as of Core Tools 4.12.1, but hosted runtime support was unverified at IaC-authoring time (no Azure subscription available in that session).')
param dotnetVersion string = '10.0'

@description('Memory allocated per instance, in MB.')
param instanceMemoryMB int = 2048

@description('Maximum instance count for Flex Consumption scaling.')
param maximumInstanceCount int = 40

@description('Extra app settings specific to this Function App (e.g. PongBaseUrl, ServiceBusConnection__fullyQualifiedNamespace).')
param additionalAppSettings object = {}

module functionApp 'br/public:avm/res/web/site:0.24.0' = {
  name: 'function-app-${name}'
  params: {
    kind: 'functionapp,linux'
    name: name
    location: location
    tags: tags
    serverFarmResourceId: appServicePlanResourceId
    managedIdentities: {
      systemAssigned: true
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccountBlobEndpoint}${deploymentContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: 'dotnet-isolated'
        version: dotnetVersion
      }
    }
    siteConfig: {
      alwaysOn: false
      minTlsVersion: '1.2'
    }
    configs: [
      {
        name: 'appsettings'
        storageAccountUseIdentityAuthentication: true
        storageAccountResourceId: storageAccountResourceId
        applicationInsightResourceId: applicationInsightsResourceId
        properties: additionalAppSettings
      }
    ]
  }
}

output resourceId string = resourceId('Microsoft.Web/sites', name)
output name string = functionApp.outputs.name
output defaultHostname string = functionApp.outputs.defaultHostname
output systemAssignedMIPrincipalId string = functionApp.outputs.?systemAssignedMIPrincipalId ?? ''
