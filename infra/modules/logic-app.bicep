@description('Name of the Logic App (Consumption) workflow.')
param name string

@description('Azure region for the workflow.')
param location string = resourceGroup().location

@description('Tags applied to the workflow.')
param tags object = {}

@description('Fully qualified Service Bus namespace host name, e.g. sb-pingpongmania-test.servicebus.windows.net.')
param serviceBusFullyQualifiedNamespace string

@description('Name of the queue the pub/sub branch sends to.')
param serviceBusQueueName string

@description('Name of the Ping Function App (used to look up its default host key at deployment time).')
param pingFunctionAppName string

@description('Base URL of the Ping Function App, e.g. https://func-ping-test.azurewebsites.net.')
param pingFunctionAppUrl string

// Computed here (rather than passed in from main.bicep) because listKeys() against a value
// derived from another module's runtime output isn't allowed outside the module that owns
// the dependency -- it must be evaluated where the target name is a plain, already-resolved parameter.
var pingFunctionKey = listKeys('${resourceId('Microsoft.Web/sites', pingFunctionAppName)}/host/default', '2022-09-01').functionKeys.default

// Play -> Ping -> Pong, modeled as a Logic App workflow instead of code-based branching:
// an HTTP Request trigger with a `method` query string selecting between two branches --
// a direct HTTP call to Ping (replacing Dapr service invocation), or a message sent to
// Service Bus (replacing Dapr pub/sub), which PingFunctions' queue trigger then picks up.
var workflowDefinition = {
  '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
  contentVersion: '1.0.0.0'
  triggers: {
    manual: {
      type: 'Request'
      kind: 'Http'
      inputs: {
        schema: {}
      }
    }
  }
  actions: {
    Check_method: {
      type: 'If'
      expression: {
        equals: [
          '@coalesce(triggerOutputs()?[\'queries\']?[\'method\'], \'http\')'
          'pubsub'
        ]
      }
      actions: {
        Send_to_ping_queue: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://${serviceBusFullyQualifiedNamespace}/${serviceBusQueueName}/messages'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://servicebus.azure.net/'
            }
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              Id: '@{guid()}'
              Timestamp: '@{utcNow()}'
            }
          }
          runAfter: {}
        }
      }
      else: {
        actions: {
          Call_Ping: {
            type: 'Http'
            inputs: {
              method: 'GET'
              uri: '${pingFunctionAppUrl}/api/ping'
              headers: {
                'x-functions-key': pingFunctionKey
              }
            }
            runAfter: {}
          }
        }
      }
      runAfter: {}
    }
    Respond_success: {
      type: 'Response'
      inputs: {
        statusCode: 200
      }
      runAfter: {
        Check_method: ['Succeeded']
      }
    }
    Respond_failure: {
      type: 'Response'
      inputs: {
        statusCode: 500
        body: {
          error: 'Failed to invoke Ping via the selected transport.'
        }
      }
      runAfter: {
        Check_method: ['Failed', 'TimedOut']
      }
    }
  }
  outputs: {}
}

module workflow 'br/public:avm/res/logic/workflow:0.6.0' = {
  name: 'logic-app-${name}'
  params: {
    name: name
    location: location
    tags: tags
    managedIdentities: {
      systemAssigned: true
    }
    workflowActions: workflowDefinition.actions
    workflowTriggers: workflowDefinition.triggers
    workflowOutputs: workflowDefinition.outputs
  }
}

output resourceId string = workflow.outputs.resourceId
output name string = workflow.outputs.name
output systemAssignedMIPrincipalId string = workflow.outputs.?systemAssignedMIPrincipalId ?? ''
