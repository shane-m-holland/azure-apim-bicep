param apimName string

resource gateway 'Microsoft.ApiManagement/service/gateways@2024-06-01-preview' = {
  name: '${apimName}/default'
  properties: {
    description: 'Default self-hosted gateway'
  }
}
