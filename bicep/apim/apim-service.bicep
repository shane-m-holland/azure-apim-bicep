// -------------------------------------------
// 🛠 API Management Service Deployment
// -------------------------------------------

@description('Name of the API Management instance')
param apimName string

@description('Azure region for deployment (e.g., eastus)')
param location string

@description('SKU name for APIM (e.g., Developer, Premium)')
param skuName string

@description('Capacity units for the SKU')
param skuCapacity int

@description('Email address for APIM publisher contact')
param publisherEmail string

@description('Display name for the APIM publisher')
param publisherName string

@description('Resource ID of the Virtual Network (not the subnet)')
param vnetResourceId string

@description('Name of the subnet within the VNET to connect APIM to')
param subnetName string

// Determine if VNet integration is supported for this SKU
// Classic SKUs (Developer, Basic, Standard) do not support VNet integration
// Only Premium, BasicV2, StandardV2, and PremiumV2 support VNet integration
var supportsVnetIntegration = contains(['Premium', 'BasicV2', 'StandardV2', 'PremiumV2'], skuName)

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apimName
  location: location

  sku: {
    name: skuName
    capacity: skuCapacity
  }

  properties: {
    // Publisher contact details
    publisherEmail: publisherEmail
    publisherName: publisherName

    // Notification sender for system emails
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'

    // Use default Azure hostname with built-in certificate
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${apimName}.azure-api.net'
        negotiateClientCertificate: false
        defaultSslBinding: true
        certificateSource: 'BuiltIn'
      }
    ]

    // Attach APIM to a subnet in the VNET (only if SKU supports it)
    virtualNetworkConfiguration: supportsVnetIntegration ? {
      subnetResourceId: '${vnetResourceId}/subnets/${subnetName}'
    } : null

    // Harden security by disabling legacy protocols and ciphers
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'False'
    }

    // Indicates VNET integration using external mode (only if SKU supports it)
    virtualNetworkType: supportsVnetIntegration ? 'External' : 'None'

    // Ensures the gateway is enabled to handle traffic
    disableGateway: false

    // Not supported in VNET External mode
    natGatewayState: supportsVnetIntegration ? 'Unsupported' : 'Disabled'

    // No specific API version constraint applied
    apiVersionConstraint: {}

    // Allow public access to the service
    publicNetworkAccess: 'Enabled'

    // Use the modern developer portal only
    legacyPortalStatus: 'Disabled'
    developerPortalStatus: 'Enabled'

    // Default release channel for platform updates
    releaseChannel: 'Default'
  }
}

@description('The resource ID of the deployed APIM instance')
output apimResourceId string = apim.id
