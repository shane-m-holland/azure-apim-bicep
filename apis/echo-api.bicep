param apimName string

resource echoApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: '${apimName}/echo-api'
  properties: {
    displayName: 'Echo API'
    path: 'echo'
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    isCurrent: true
    apiRevision: '1'
    value: 'https://echoapi.cloudapp.net/api'
    format: 'swagger-link-json'
  }
}
