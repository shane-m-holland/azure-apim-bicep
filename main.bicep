param subscriptionId string
param apimName string
param location string
param skuName string
param skuCapacity int
param publisherEmail string
param publisherName string
param vnetResourceId string

module apimService 'apimService.bicep' = {
  name: 'deploy-apim-service'
  params: {
    apimName: apimName
    location: location
    skuName: skuName
    skuCapacity: skuCapacity
    publisherEmail: publisherEmail
    publisherName: publisherName
    vnetResourceId: vnetResourceId
  }
}

module echoApi 'apis/echo-api.bicep' = {
  name: 'deploy-echo-api'
  params: {
    apimName: apimName
  }
}

module products 'products/products.bicep' = {
  name: 'deploy-products'
  params: {
    apimName: apimName
  }
}

module gateway 'gateways/gateway.bicep' = {
  name: 'deploy-gateway'
  params: {
    apimName: apimName
  }
}
