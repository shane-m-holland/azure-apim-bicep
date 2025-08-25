// -------------------------------------------
// 🔌 Virtual Network (VNET) and Subnet Deployment
// -------------------------------------------
// Supports two modes:
// 1. Full VNet Creation: Create new VNet with subnet
// 2. Subnet-Only Creation: Add subnet to existing VNet

@description('Name of the Virtual Network to create or modify')
param vnetName string

@description('Resource ID of the Network Security Group to associate with the subnet')
param nsgResourceId string

@description('Azure region in which to deploy the VNET')
param location string

@description('CIDR block for the VNET (e.g., 10.0.0.0/16)')
param vnetCidr string

@description('Name of the subnet within the VNET')
param subnetName string

@description('CIDR block for the subnet (e.g., 10.0.0.0/24)')
param subnetCidr string

@description('Whether to create full VNet (true) or just add subnet to existing VNet (false)')
param createFullVnet bool = true

@description('Resource ID of existing VNet (required when createFullVnet is false)')
param existingVnetResourceId string = ''

// -------------------------------------------
// Create Virtual Network with a single subnet (Full VNet Creation Mode)
// -------------------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (createFullVnet) {
  name: vnetName
  location: location

  properties: {
    // Set address space for the VNET
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }

    // Default encryption settings
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }

    // Disable default private endpoint policies at VNET level
    privateEndpointVNetPolicies: 'Disabled'

    // Define subnet and NSG binding
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefixes: [
            subnetCidr
          ]
          networkSecurityGroup: {
            id: nsgResourceId
          }

          // Disable policies for private endpoint access to allow direct connections
          privateEndpointNetworkPolicies: 'Disabled'

          // Enable policies for private link services (optional for APIM)
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// -------------------------------------------
// Reference to existing VNet (Subnet-Only Creation Mode)
// -------------------------------------------
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (!createFullVnet && !empty(existingVnetResourceId)) {
  name: last(split(existingVnetResourceId, '/'))
  scope: resourceGroup(split(existingVnetResourceId, '/')[2], split(existingVnetResourceId, '/')[4])
}

// -------------------------------------------
// Create new subnet in existing VNet (Subnet-Only Creation Mode)
// -------------------------------------------
resource newSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createFullVnet && !empty(existingVnetResourceId)) {
  name: subnetName
  parent: existingVnet
  properties: {
    addressPrefix: subnetCidr
    networkSecurityGroup: {
      id: nsgResourceId
    }
    // Disable policies for private endpoint access to allow direct connections
    privateEndpointNetworkPolicies: 'Disabled'
    // Enable policies for private link services (optional for APIM)
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

@description('The resource ID of the virtual network')
output id string = createFullVnet ? vnet.id : existingVnetResourceId

@description('The resource ID of the subnet (either created or in existing VNet)')
output subnetId string = createFullVnet 
  ? '${vnet.id}/subnets/${subnetName}'
  : newSubnet.id

@description('Deployment mode used')
output deploymentMode string = createFullVnet ? 'full-vnet' : 'subnet-only'
