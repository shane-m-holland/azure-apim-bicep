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
// 🔄 Network Resource Reuse Strategy
// -------------------------------------------

@description('Whether to use existing NSG instead of creating new one')
param useExistingNsg bool = false

@description('Name of existing NSG to use')
param existingNsgName string = ''

@description('Resource group containing existing NSG')
param existingNsgResourceGroup string = ''

@description('Full resource ID of existing NSG')
param existingNsgResourceId string = ''

@description('Whether to use existing VNet instead of creating new one')
param useExistingVnet bool = false

@description('Name of existing VNet to use')
param existingVnetName string = ''

@description('Resource group containing existing VNet')
param existingVnetResourceGroup string = ''

@description('Full resource ID of existing VNet')
param existingVnetResourceId string = ''

@description('Whether to use existing subnet instead of creating new one')
param useExistingSubnet bool = false

@description('Name of existing subnet to use')
param existingSubnetName string = ''

@description('Whether to create new subnet in existing VNet')
param createNewSubnetInExistingVnet bool = true

// -------------------------------------------
// 🚦 Gateway Config
// -------------------------------------------

@description('Whether to deploy a self-hosted gateway')
param selfHostedGatewayEnabled bool = false

@description('Name of the self-hosted gateway')
param selfHostedGatewayName string = 'default'


// -------------------------------------------
// 🔍 Lookup Existing Network Resources
// -------------------------------------------
module existingResources 'network/existing-resources.bicep' = {
  name: 'lookup-existing-resources'
  params: {
    useExistingNsg: useExistingNsg
    existingNsgName: existingNsgName
    existingNsgResourceGroup: existingNsgResourceGroup
    existingNsgResourceId: existingNsgResourceId
    useExistingVnet: useExistingVnet
    existingVnetName: existingVnetName
    existingVnetResourceGroup: existingVnetResourceGroup
    existingVnetResourceId: existingVnetResourceId
    useExistingSubnet: useExistingSubnet
    existingSubnetName: existingSubnetName
  }
}

// -------------------------------------------
// 🧱 Deploy Network Security Group (Conditional)
// -------------------------------------------
module nsg 'network/nsg.bicep' = if (!useExistingNsg) {
  name: 'deploy-nsg'
  params: {
    nsgName: nsgName
    location: location
  }
}

// -------------------------------------------
// 🧱 Deploy Virtual Network & Subnet (Conditional)
// -------------------------------------------
module vnet 'network/vnet.bicep' = if (!useExistingVnet) {
  name: 'deploy-vnet'
  params: {
    vnetName: vnetName
    location: location
    nsgResourceId: useExistingNsg ? existingResources.outputs.nsgResourceId : nsg.outputs.id
    vnetCidr: vnetCidr
    subnetName: subnetName
    subnetCidr: subnetCidr
    apimSkuName: skuName
  }
}

// -------------------------------------------
// 🧱 Deploy New Subnet in Existing VNet (Conditional)
// -------------------------------------------
module newSubnetInExistingVnet 'network/cross-rg-subnet.bicep' = if (useExistingVnet && !useExistingSubnet && createNewSubnetInExistingVnet) {
  name: 'deploy-new-subnet'
  params: {
    existingVnetResourceId: existingResources.outputs.vnetResourceId
    subnetName: subnetName
    subnetCidr: subnetCidr
    nsgResourceId: useExistingNsg ? existingResources.outputs.nsgResourceId : nsg.outputs.id
    apimSkuName: skuName
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
    vnetResourceId: useExistingVnet 
      ? existingResources.outputs.vnetResourceId
      : vnet.outputs.id
    subnetName: useExistingSubnet ? existingSubnetName : subnetName
  }
  dependsOn: [
    // Ensure network resources are ready before APIM deployment
    existingResources
  ]
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


