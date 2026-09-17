@description('Name of the Key Vault.')
param name string

@description('Azure region for the vault.')
param location string = resourceGroup().location

@description('Tags applied to the vault.')
param tags object = {}

@description('Number of days deleted secrets are retained for recovery.')
param softDeleteRetentionInDays int = 7

module keyVault 'br/public:avm/res/key-vault/vault:0.14.2' = {
  name: 'key-vault-${name}'
  params: {
    name: name
    location: location
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    sku: 'standard'
  }
}

output resourceId string = keyVault.outputs.resourceId
output name string = keyVault.outputs.name
