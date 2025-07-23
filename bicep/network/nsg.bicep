// -------------------------------------------
// 🌐 Network Security Group (NSG) for APIM External VNet Mode
// Based on Microsoft's recommended NSG rules for Azure API Management
// Reference: https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet
// -------------------------------------------

@description('Name of the Network Security Group')
param nsgName string

@description('Location for the NSG')
param location string

// -------------------------------------------
// Create NSG with Microsoft-recommended rules for APIM External VNet
// -------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location

  properties: {
    securityRules: [
      // INBOUND RULES
      // ==========================================
      
      // Client communication to API Management (Internet access)
      {
        name: 'AllowClientCommunication'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
          description: 'Client communication to API Management'
        }
      }

      // Management endpoint for Azure portal and PowerShell (CRITICAL FIX)
      {
        name: 'AllowManagementEndpoint'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
          description: 'Management endpoint for Azure portal and PowerShell'
        }
      }

      // Azure Infrastructure Load Balancer health probes
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6390'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
          description: 'Azure Infrastructure Load Balancer health probes'
        }
      }

      // OUTBOUND RULES
      // ==========================================

      // Dependency on Azure Storage (certificates, policies, etc.)
      {
        name: 'AllowStorageOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
          description: 'Dependency on Azure Storage for certificates and policies'
        }
      }

      // Access to Azure Key Vault (for certificates and secrets)
      {
        name: 'AllowKeyVaultOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
          description: 'Access to Azure Key Vault for certificates and secrets'
        }
      }

      // Access to Azure SQL (for API Management database operations)
      {
        name: 'AllowSQLOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'SQL'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
          description: 'Access to Azure SQL for API Management operations'
        }
      }

      // Publish diagnostics logs and metrics to Azure Monitor
      {
        name: 'AllowMonitorOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['1886', '443']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
          description: 'Publish diagnostics logs and metrics to Azure Monitor'
        }
      }

      // Internet access for certificate validation and external dependencies
      {
        name: 'AllowInternetOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
          description: 'Internet access for certificate validation and external dependencies'
        }
      }
    ]
  }
}

@description('The resource ID of the deployed Network Security Group')
output id string = nsg.id