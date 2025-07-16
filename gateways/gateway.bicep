// -------------------------------------------
// 🌉 Self-Hosted Gateway Configuration
// -------------------------------------------

@description('Name of the API Management instance')
param apimName string

@description('Name of the self-hosted gateway to create')
param gatewayName string

// -------------------------------------------
// Create a self-hosted gateway resource
// -------------------------------------------
resource selfHostedGateway 'Microsoft.ApiManagement/service/gateways@2022-08-01' = {
  name: '${apimName}/${gatewayName}'

  properties: {
    description: 'Self-hosted gateway for hybrid deployment scenarios'
    locationData: {
      name: 'OnPremises'
      // You may optionally add city/region data here for visibility
      // city: 'Example City',
      // region: 'Example Region'
    }
  }
}

@description('The resource ID of the deployed self-hosted gateway')
output id string = selfHostedGateway.id
