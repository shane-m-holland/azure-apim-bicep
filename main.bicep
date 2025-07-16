param apimName string
param location string
param skuName string
param skuCapacity int
param publisherEmail string
param publisherName string
param nsgName string
param vnetName string
param vnetCidr string
param subnetName string
param subnetCidr string

module nsg 'network/nsg.bicep' = {
  name: 'deploy-nsg'
  params: {
    nsgName: nsgName
    location: location
  }
}

module vnet 'network/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    vnetName: vnetName
    location: location
    nsgResourceId: nsg.outputs.id
    vnetCidr: vnetCidr
    subnetName: subnetName
    subnetCidr: subnetCidr
  }
}

module apimService 'apimService.bicep' = {
  name: 'deploy-apim-service'
  params: {
    apimName: apimName
    location: location
    skuName: skuName
    skuCapacity: skuCapacity
    publisherEmail: publisherEmail
    publisherName: publisherName
    vnetResourceId: vnet.outputs.id
    subnetName: subnetName
  }
}

module products 'products/products.bicep' = {
  name: 'deploy-products'
  dependsOn: [apimService]
  params: {
    apimName: apimName
  }
}

module echoApi 'apis/echo-api.bicep' = {
  name: 'deploy-echo-api'
  dependsOn: [
    apimService
    products
  ]
  params: {
    apimName: apimName
  }
}

// module gateway 'gateways/gateway.bicep' = {
//   name: 'deploy-gateway'
//   params: {
//     apimName: apimName
//   }
// }
