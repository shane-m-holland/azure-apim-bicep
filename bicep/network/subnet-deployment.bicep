// -------------------------------------------
// 🔌 Subnet Deployment Module
// -------------------------------------------
// This module creates a subnet in an existing VNet
// within the same resource group scope.

targetScope = 'resourceGroup'

@description('Name of the existing Virtual Network')
param vnetName string

@description('Name of the subnet to create')
param subnetName string

@description('CIDR block for the subnet (e.g., 10.0.0.0/24)')
param subnetCidr string

@description('Resource ID of the Network Security Group to associate with the subnet')
param nsgResourceId string

@description('APIM SKU name (used to determine if subnet delegation is needed)')
param apimSkuName string

// Determine if this is a V2 SKU that requires subnet delegation
var isV2Sku = contains(['BasicV2', 'StandardV2', 'PremiumV2'], apimSkuName)

// -------------------------------------------
// Reference existing VNet in current scope
// -------------------------------------------
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

// -------------------------------------------
// Create subnet in existing VNet
// -------------------------------------------
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: subnetName
  parent: existingVnet
  properties: {
    addressPrefix: subnetCidr
    networkSecurityGroup: {
      id: nsgResourceId
    }
    // V2 SKUs require subnet delegation to Microsoft.Web/serverFarms
    delegations: isV2Sku ? [
      {
        name: 'apim-delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ] : []
    // Disable policies for private endpoint access to allow direct connections
    privateEndpointNetworkPolicies: 'Disabled'
    // Enable policies for private link services (optional for APIM)
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// -------------------------------------------
// Outputs
// -------------------------------------------
@description('Resource ID of the created subnet')
output subnetResourceId string = subnet.id

@description('Name of the created subnet')
output subnetName string = subnet.name