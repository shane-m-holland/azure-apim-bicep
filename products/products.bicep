param apimName string

resource starterProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: '${apimName}/starter'
  properties: {
    displayName: 'Starter'
    description: 'Limited usage product for testing'
    terms: 'Limited to 5 calls/minute.'
    subscriptionRequired: true
    approvalRequired: false
    subscriptionsLimit: 1
    state: 'published'
  }
}

resource unlimitedProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: '${apimName}/unlimited'
  properties: {
    displayName: 'Unlimited'
    description: 'Unlimited usage for internal teams'
    terms: 'Internal use only.'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}
