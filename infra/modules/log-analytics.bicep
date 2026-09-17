@description('Name of the Log Analytics workspace.')
param name string

@description('Azure region for the workspace.')
param location string = resourceGroup().location

@description('Tags applied to the workspace.')
param tags object = {}

@description('Data retention in days.')
param retentionInDays int = 30

module workspace 'br/public:avm/res/operational-insights/workspace:0.16.1' = {
  name: 'log-analytics-${name}'
  params: {
    name: name
    location: location
    tags: tags
    dataRetention: retentionInDays
  }
}

output resourceId string = workspace.outputs.resourceId
output name string = workspace.outputs.name
