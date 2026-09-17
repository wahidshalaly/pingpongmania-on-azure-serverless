@description('Name of the Service Bus namespace.')
param name string

@description('Azure region for the namespace.')
param location string = resourceGroup().location

@description('Tags applied to the namespace.')
param tags object = {}

@description('SKU tier for the namespace.')
@allowed(['Basic', 'Standard', 'Premium'])
param skuName string = 'Standard'

@description('Name of the queue used to replace the Dapr pub/sub topic.')
param queueName string = 'ping-queue'

@description('Message TTL for the queue.')
param defaultMessageTimeToLive string = 'P1D'

@description('Max delivery attempts before dead-lettering.')
param maxDeliveryCount int = 5

module serviceBusNamespace 'br/public:avm/res/service-bus/namespace:0.17.1' = {
  name: 'service-bus-${name}'
  params: {
    name: name
    location: location
    tags: tags
    skuObject: {
      name: skuName
    }
    disableLocalAuth: true
    queues: [
      {
        name: queueName
        defaultMessageTimeToLive: defaultMessageTimeToLive
        maxDeliveryCount: maxDeliveryCount
        deadLetteringOnMessageExpiration: true
        requiresDuplicateDetection: false
        requiresSession: false
      }
    ]
  }
}

output resourceId string = serviceBusNamespace.outputs.resourceId
output name string = serviceBusNamespace.outputs.name
output fullyQualifiedNamespace string = '${serviceBusNamespace.outputs.name}.servicebus.windows.net'
output queueResourceId string = '${serviceBusNamespace.outputs.resourceId}/queues/${queueName}'
