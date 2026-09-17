@description('Name of the Application Insights component.')
param name string

@description('Azure region for the component.')
param location string = resourceGroup().location

@description('Tags applied to the component.')
param tags object = {}

@description('Resource ID of the Log Analytics workspace backing this component.')
param logAnalyticsWorkspaceResourceId string

@description('Sampling percentage for telemetry (100 = no sampling).')
param samplingPercentage int = 100

module appInsights 'br/public:avm/res/insights/component:0.8.0' = {
  name: 'app-insights-${name}'
  params: {
    name: name
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspaceResourceId
    kind: 'web'
    applicationType: 'web'
    samplingPercentage: samplingPercentage
  }
}

output resourceId string = appInsights.outputs.resourceId
output name string = appInsights.outputs.name
output connectionString string = appInsights.outputs.connectionString
