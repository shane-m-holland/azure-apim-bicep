// -------------------------------------------
// 📦 API Management Product Definitions
// -------------------------------------------

@description('Name of the API Management instance')
param apimName string

// -------------------------------------------
// Starter Product: Low-limit usage, great for testing
// -------------------------------------------
resource starterProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: '${apimName}/starter'
  properties: {
    displayName: 'Starter'
    description: 'Limited usage product for testing'
    terms: 'Limited to 5 calls/minute.'
    subscriptionRequired: true       // Requires subscription to access APIs
    approvalRequired: false          // Auto-approve subscriptions
    subscriptionsLimit: 1           // Only one subscription allowed per user
    state: 'published'              // Makes the product publicly visible
  }
}

// -------------------------------------------
// Unlimited Product: Internal high-capacity access
// -------------------------------------------
resource unlimitedProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: '${apimName}/unlimited'
  properties: {
    displayName: 'Unlimited'
    description: 'Unlimited usage for internal teams'
    terms: 'Internal use only.'
    subscriptionRequired: true       // Still requires a subscription
    approvalRequired: false          // No manual approval needed
    state: 'published'               // Visible in the developer portal
  }
}
