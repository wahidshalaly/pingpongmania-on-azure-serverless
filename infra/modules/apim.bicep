@description('Name of the API Management instance.')
param name string

@description('Azure region for APIM.')
param location string = resourceGroup().location

@description('Tags applied to APIM.')
param tags object = {}

@description('Publisher email required by APIM.')
param publisherEmail string

@description('Publisher name required by APIM.')
param publisherName string

@description('Name of the Logic App whose "manual" HTTP trigger api/play forwards to (its callback URL, including SAS signature, is resolved here at deployment time).')
param logicAppName string

// Computed here rather than passed in from main.bicep -- see the equivalent note in
// logic-app.bicep about listKeys()/listCallbackUrl() needing a plain, already-resolved name.
var playBackendUrl = listCallbackUrl('${resourceId('Microsoft.Logic/workflows', logicAppName)}/triggers/manual', '2019-05-01').value

@description('Rate limit (calls per period) applied to the test-tier product. Set higher for prod.')
param rateLimitCalls int = 30

@description('Rate limit renewal period in seconds.')
param rateLimitPeriodSeconds int = 60

module apimService 'br/public:avm/res/api-management/service:0.14.4' = {
  name: 'apim-${name}'
  params: {
    name: name
    location: location
    tags: tags
    publisherEmail: publisherEmail
    publisherName: publisherName
    sku: 'Consumption'
    skuCapacity: 0
    apis: [
      {
        name: 'pingpongmania'
        displayName: 'PingPongMania'
        path: ''
        protocols: ['https']
        serviceUrl: playBackendUrl
        subscriptionRequired: true
        operations: [
          {
            name: 'play'
            displayName: 'Play'
            method: 'GET'
            urlTemplate: '/play'
          }
        ]
      }
    ]
    products: [
      {
        name: 'pingpongmania'
        displayName: 'PingPongMania'
        subscriptionRequired: true
        state: 'published'
        apis: ['pingpongmania']
        policies: [
          {
            name: 'policy'
            format: 'xml'
            value: '<policies><inbound><base /><rate-limit calls="${rateLimitCalls}" renewal-period="${rateLimitPeriodSeconds}" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
          }
        ]
      }
    ]
  }
}

output resourceId string = apimService.outputs.resourceId
output name string = apimService.outputs.name
output gatewayUrl string = 'https://${apimService.outputs.name}.azure-api.net'
