// -------------------------------------------
// 🚀 Main Deployment Entry Point
// -------------------------------------------

// -------------------------------------------
// 📍 Location & APIM Config
// -------------------------------------------

@description('Name of the API Management instance')
param apimName string

@description('Azure region to deploy resources into (e.g., eastus)')
param location string = 'eastus'

@description('APIM SKU name (e.g., Developer, Premium)')
param skuName string = 'Developer'

@description('Number of units for the APIM SKU')
param skuCapacity int = 1

@description('Email address for the APIM publisher')
param publisherEmail string

@description('Display name for the APIM publisher')
param publisherName string

// -------------------------------------------
// 🌐 Network Config
// -------------------------------------------

@description('Name of the Network Security Group')
param nsgName string = '${apimName}-nsg'

@description('Name of the Virtual Network')
param vnetName string = '${apimName}-vnet'

@description('CIDR block for the VNET')
param vnetCidr string = '10.0.0.0/16'

@description('Name of the subnet for APIM')
param subnetName string = 'default'

@description('CIDR block for the subnet')
param subnetCidr string = '10.0.0.0/24'

// -------------------------------------------
// 🚦 Gateway Config
// -------------------------------------------

@description('Whether to deploy a self-hosted gateway')
param selfHostedGatewayEnabled bool = false

@description('Name of the self-hosted gateway')
param selfHostedGatewayName string = 'default'


// -------------------------------------------
// 🧱 Deploy Network Security Group
// -------------------------------------------
module nsg 'network/nsg.bicep' = {
  name: 'deploy-nsg'
  params: {
    nsgName: nsgName
    location: location
  }
}

// -------------------------------------------
// 🧱 Deploy Virtual Network & Subnet
// -------------------------------------------
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

// -------------------------------------------
// 🧱 Deploy APIM Instance
// -------------------------------------------
module apimService './apim/apim-service.bicep' = {
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

// -------------------------------------------
// 🧱 Deploy API Products
// -------------------------------------------
module products 'products/products.bicep' = {
  name: 'deploy-products'
  dependsOn: [
    apimService
  ]
  params: {
    apimName: apimName
  }
}

// -------------------------------------------
// 🧱 Deploy Self-Hosted Gateway (Optional)
// -------------------------------------------
module gateway 'gateways/gateway.bicep' = if (selfHostedGatewayEnabled) {
  name: 'deploy-gateway'
  params: {
    apimName: apimName
    gatewayName: selfHostedGatewayName
  }
}


