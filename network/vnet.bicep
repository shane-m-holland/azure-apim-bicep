@description('Name of the Virtual Network')
param vnetName string

@description('Resource ID of the Network Security Group')
param nsgResourceId string

@description('Location for the VNET')
param location string

@description('IP address range for VNET addresses')
param vnetCidr string

@description('Name of the subnet for the VNET')
param subnetName string

@description('IP address range for the VNET subnet')
param subnetCidr string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    privateEndpointVNetPolicies: 'Disabled'
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
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

output id string = vnet.id
