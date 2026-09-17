@description('Name of the storage account (lowercase alphanumeric, <=24 chars).')
param name string

@description('Azure region for the storage account.')
param location string = resourceGroup().location

@description('Tags applied to the storage account.')
param tags object = {}

@description('Blob container names to create, e.g. one Flex Consumption deployment container per Function App.')
param containerNames array

@description('Table names to create, e.g. the app-level "pings" table.')
param tableNames array = []

module storageAccount 'br/public:avm/res/storage/storage-account:0.33.1' = {
  name: 'storage-account-${name}'
  params: {
    name: name
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    blobServices: {
      containers: [for containerName in containerNames: { name: containerName }]
    }
    tableServices: {
      tables: [for tableName in tableNames: { name: tableName }]
    }
  }
}

output resourceId string = storageAccount.outputs.resourceId
output name string = storageAccount.outputs.name
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint
output primaryTableEndpoint string = storageAccount.outputs.serviceEndpoints.table
