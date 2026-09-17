@description('Name of the shared storage account.')
param storageAccountName string

@description('Name of the Key Vault.')
param keyVaultName string

@description('Name of the Service Bus namespace.')
param serviceBusNamespaceName string

@description('Name of the ping-queue queue.')
param serviceBusQueueName string

@description('System-assigned identity principal ID of func-ping.')
param pingPrincipalId string

@description('System-assigned identity principal ID of func-play.')
param playPrincipalId string

@description('System-assigned identity principal ID of func-pong.')
param pongPrincipalId string

@description('System-assigned identity principal ID of the Logic App.')
param logicAppPrincipalId string

var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var serviceBusDataSenderRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
var serviceBusDataReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource pingQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' existing = {
  name: '${serviceBusNamespaceName}/${serviceBusQueueName}'
}

// Host storage (blob) -- every Function App's identity needs this for deployment + internal bookkeeping
resource pongHostStorageRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, pongPrincipalId, storageBlobDataOwnerRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: pongPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource pingHostStorageRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, pingPrincipalId, storageBlobDataOwnerRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: pingPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource playHostStorageRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, playPrincipalId, storageBlobDataOwnerRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: playPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// App-level pings table -- Ping only
resource pingTableRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, pingPrincipalId, storageTableDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorRoleId)
    principalId: pingPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ping-queue -- Ping receives, the Logic App sends
resource pingQueueReceiveRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(pingQueue.id, pingPrincipalId, serviceBusDataReceiverRoleId)
  scope: pingQueue
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataReceiverRoleId)
    principalId: pingPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource logicAppQueueSendRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(pingQueue.id, logicAppPrincipalId, serviceBusDataSenderRoleId)
  scope: pingQueue
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataSenderRoleId)
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault -- every Function App's identity, for the (currently empty) set of secrets that
// can't be identity-based. Provisioned for extensibility per the approved architecture.
resource pongKeyVaultRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, pongPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: pongPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource pingKeyVaultRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, pingPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: pingPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource playKeyVaultRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, playPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: playPrincipalId
    principalType: 'ServicePrincipal'
  }
}
