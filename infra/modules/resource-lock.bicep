@description('Name of the lock.')
param name string

@description('Lock level.')
@allowed(['CanNotDelete', 'ReadOnly'])
param level string = 'CanNotDelete'

@description('Notes describing why the lock exists.')
param notes string = ''

resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: name
  properties: {
    level: level
    notes: notes
  }
}
