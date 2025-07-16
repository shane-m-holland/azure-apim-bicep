// -------------------------------------------
// 🌐 Network Security Group (NSG) for APIM
// -------------------------------------------

@description('Name of the Network Security Group')
param nsgName string

@description('Location for the NSG')
param location string

// -------------------------------------------
// Create NSG with inbound and outbound rules for APIM
// -------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location

  properties: {
    securityRules: [
      // Allow inbound HTTPS traffic on port 443
      {
        name: 'AllowAnyCustom443Inbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }

      // Allow inbound management traffic on port 3443
      {
        name: 'AllowAnyCustom3443Inbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }

      // Allow all outbound traffic
      {
        name: 'AllowAnyCustomAnyOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

@description('The resource ID of the deployed Network Security Group')
output id string = nsg.id
