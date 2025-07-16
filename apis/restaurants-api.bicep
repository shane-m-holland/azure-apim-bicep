// -------------------------------------------
// 📡 Restaurants API - OpenAPI Import and Configuration
// -------------------------------------------

@description('Name of the API Management instance')
param apimName string

@description('Array of product IDs to associate this API with (e.g., ["starter", "unlimited"])')
param productIds array

@description('Array of gateway names to associate this API with (e.g., ["managed", "my-self-hosted-gateway"])')
param gatewayNames array

// -------------------------------------------
// Import the Restaurants API using OpenAPI Specification
// -------------------------------------------
resource restaurantsApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: '${apimName}/restaurants-api'
  properties: {
    format: 'openapi'
    value: loadTextContent('./openapi/restaurants-api.json') // <-- OpenAPI JSON file
    path: 'fun' // This sets the base path segment: https://<gateway>/fun/<api-route>
    protocols: [
      'https'
    ]
    subscriptionRequired: true
  }
}

// -------------------------------------------
// Associate the API with multiple products
// -------------------------------------------
@batchSize(1)
resource apiProducts 'Microsoft.ApiManagement/service/products/apis@2021-08-01' = [for productId in productIds: {
  name: '${apimName}/${productId}/restaurants-api'
  dependsOn: [
    restaurantsApi
  ]
}]

// -------------------------------------------
// Associate the API with one or more gateways
// -------------------------------------------
@batchSize(1)
resource apiGateways 'Microsoft.ApiManagement/service/gateways/apis@2021-08-01' = [for gatewayName in gatewayNames: {
  name: '${apimName}/${gatewayName}/restaurants-api'
  dependsOn: [
    restaurantsApi
  ]
}]
