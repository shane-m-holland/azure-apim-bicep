// -------------------------------------------
// 📡  API Endpoint Template - Publish configured endpoint
// -------------------------------------------

@description('Name of the API Management instance')
param apimName string

@description('API ID')
param apiId string

@description('API Display Name')
param displayName string

@description('API Description')
param apiDescription string = ''

@description('Target backend service URL')
@secure()
param serviceUrl string = ''

@description('Path segment for the API (i.e., public URL route)')
param path string

@description('Format of the spec (e.g., openapi+json, wsdl)')
param format string = 'openapi+json'

@description('API protocol(s)')
param protocols array = ['https']

@description('Whether an API or Product subscription is required for accessing the API.')
param subscriptionRequired bool = false

@description('Array of product IDs to associate this API with (e.g., ["starter", "unlimited"])')
param productIds array = ['unlimited']

@description('Array of gateway names to associate this API with (e.g., ["managed", "my-self-hosted-gateway"])')
param gatewayNames array = ['managed']

@description('Array of APIM tag names to associate this API with (for Developer Portal categorization)')
param tags array = []

@description('The type of endpoint (e.g. soap, http, graphql, websocket etc.)')
param apiType string = 'http'


// -------------------------------------------
// Import the API with given configuration
// -------------------------------------------
resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: '${apimName}/${apiId}'
  properties: {
    displayName: displayName
    description: apiDescription
    path: path
    format: format
    value: loadTextContent('__SPEC_PATH__')
    protocols: protocols
    type: apiType
    apiType: apiType
    subscriptionRequired: subscriptionRequired

    // Conditionally include the serviceUrl only if provided
    ...(empty(serviceUrl) ? {} : {
      serviceUrl: serviceUrl
    })
  }
}

// -------------------------------------------
// Associate the API with multiple products
// -------------------------------------------
@batchSize(1)
resource apiProducts 'Microsoft.ApiManagement/service/products/apis@2021-08-01' = [for productId in productIds: {
  name: '${apimName}/${productId}/${apiId}'
  dependsOn: [
    api
  ]
}]

// -------------------------------------------
// Associate the API with one or more gateways
// -------------------------------------------
@batchSize(1)
resource apiGateways 'Microsoft.ApiManagement/service/gateways/apis@2021-08-01' = [for gatewayName in gatewayNames: {
  name: '${apimName}/${gatewayName}/${apiId}'
  dependsOn: [
    api
  ]
}]

// -------------------------------------------
// Create APIM-visible tags if not already present (optional)
// -------------------------------------------
@batchSize(1)
resource tagDefinitions 'Microsoft.ApiManagement/service/tags@2022-08-01' = [for tag in tags: {
  name: '${apimName}/${tag}'
  properties: {
    displayName: tag
  }
}]

// -------------------------------------------
// Associate the API with APIM-visible tags (optional)
// -------------------------------------------
@batchSize(1)
resource apiTags 'Microsoft.ApiManagement/service/apis/tags@2021-08-01' = [for tag in tags: {
  parent: api
  name: tag
}]
