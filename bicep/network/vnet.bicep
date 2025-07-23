// -------------------------------------------
// 🔌 Virtual Network (VNET) and Subnet Deployment
// -------------------------------------------

@description('Name of the Virtual Network to create')
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

// -------------------------------------------
// Create Virtual Network with a single subnet
// -------------------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
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

@description('The resource ID of the deployed virtual network')
output id string = vnet.id
