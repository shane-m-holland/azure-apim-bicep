// -----------------------------------------------------------------------------
// 🧪 APIM Diagnostic Settings - Enable logging to Azure Monitor, Event Hub, or Storage
// -----------------------------------------------------------------------------

@description('Name of the API Management instance')
param apimName string

@description('Name of the diagnostic settings (commonly "applicationinsights")')
param diagnosticName string = 'applicationinsights'

@description('Instrumentation key or connection string for logging destination')
@secure()
param loggerResourceId string

@description('Specifies the sampling setting for request and response bodies')
param sampling string = 'always'

@description('Whether to log request body')
param logRequestBody bool = true

@description('Whether to log response body')
param logResponseBody bool = true

@description('List of API names to apply diagnostics to. Use ["*"] for all APIs')
param apiNames array = ['*']

resource diagnostics 'Microsoft.ApiManagement/service/diagnostics@2021-08-01' = {
  name: '${apimName}/${diagnosticName}'
  properties: {
    enabled: true
    loggerId: loggerResourceId
    sampling: {
      samplingType: 'fixed'
      percentage: sampling == 'always' ? 100 : (sampling == 'none' ? 0 : 50)
    }
    frontend: {
      request: {
        body: {
          bytes: logRequestBody ? 512 : 0
        }
      }
      response: {
        body: {
          bytes: logResponseBody ? 512 : 0
        }
      }
    }
    backend: {
      request: {
        body: {
          bytes: logRequestBody ? 512 : 0
        }
      }
      response: {
        body: {
          bytes: logResponseBody ? 512 : 0
        }
      }
    }
  }
}

@batchSize(1)
resource diagnosticsPerApi 'Microsoft.ApiManagement/service/apis/diagnostics@2021-08-01' = [for apiName in apiNames: {
  name: '${apimName}/${apiName}/${diagnosticName}'
  properties: diagnostics.properties
  dependsOn: [
    diagnostics
  ]
}]
