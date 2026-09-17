@description('Name of the Flex Consumption App Service Plan.')
param name string

@description('Azure region for the plan.')
param location string = resourceGroup().location

@description('Tags applied to the plan.')
param tags object = {}

module plan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'flex-consumption-plan-${name}'
  params: {
    name: name
    location: location
    tags: tags
    skuName: 'FC1'
    skuCapacity: 1
    reserved: true
    kind: 'functionapp,linux'
  }
}

output resourceId string = plan.outputs.resourceId
output name string = plan.outputs.name
