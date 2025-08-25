// -------------------------------------------
// 🔍 Existing Network Resources Lookup and Validation
// -------------------------------------------
// This module handles lookups of existing network resources (NSG, VNet, Subnet)
// and validates they exist with proper configuration for APIM deployment.

@description('Whether to use existing NSG instead of creating new one')
param useExistingNsg bool = false

@description('Name of existing NSG to use (ignored if useExistingNsg is false)')
param existingNsgName string = ''

@description('Resource group containing existing NSG (defaults to current RG if empty)')
param existingNsgResourceGroup string = ''

@description('Full resource ID of existing NSG (takes precedence over name-based lookup)')
param existingNsgResourceId string = ''

@description('Whether to use existing VNet instead of creating new one')
param useExistingVnet bool = false

@description('Name of existing VNet to use (ignored if useExistingVnet is false)')
param existingVnetName string = ''

@description('Resource group containing existing VNet (defaults to current RG if empty)')
param existingVnetResourceGroup string = ''

@description('Full resource ID of existing VNet (takes precedence over name-based lookup)')
param existingVnetResourceId string = ''

@description('Whether to use existing subnet instead of creating new one')
param useExistingSubnet bool = false

@description('Name of existing subnet to use (ignored if useExistingSubnet is false)')
param existingSubnetName string = ''

// -------------------------------------------
// Get current resource group for default lookups
// -------------------------------------------
var currentResourceGroupName = resourceGroup().name

// -------------------------------------------
// Existing NSG Resource Lookup
// -------------------------------------------
resource existingNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = if (useExistingNsg && !empty(existingNsgName)) {
  name: existingNsgName
  scope: resourceGroup(empty(existingNsgResourceGroup) ? currentResourceGroupName : existingNsgResourceGroup)
}

// -------------------------------------------
// Existing VNet Resource Lookup
// -------------------------------------------
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (useExistingVnet && !empty(existingVnetName)) {
  name: existingVnetName
  scope: resourceGroup(empty(existingVnetResourceGroup) ? currentResourceGroupName : existingVnetResourceGroup)
}

// -------------------------------------------
// Existing Subnet Resource Lookup
// -------------------------------------------
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = if (useExistingVnet && useExistingSubnet && !empty(existingSubnetName)) {
  name: existingSubnetName
  parent: existingVnet
}

// -------------------------------------------
// Output resolved resource IDs
// -------------------------------------------

@description('Resolved NSG resource ID - either from existing resource or provided resource ID')
output nsgResourceId string = useExistingNsg 
  ? (!empty(existingNsgResourceId) 
      ? existingNsgResourceId 
      : existingNsg.id)
  : ''

@description('Resolved VNet resource ID - either from existing resource or provided resource ID')
output vnetResourceId string = useExistingVnet 
  ? (!empty(existingVnetResourceId) 
      ? existingVnetResourceId 
      : existingVnet.id)
  : ''

@description('Resolved subnet resource ID - either from existing subnet or constructed from VNet')
output subnetResourceId string = useExistingVnet && useExistingSubnet 
  ? existingSubnet.id
  : ''

@description('VNet properties for validation (empty object if not using existing VNet)')
output vnetProperties object = useExistingVnet && !empty(existingVnetName) 
  ? {
      addressSpace: existingVnet.properties.addressSpace
      location: existingVnet.location
      subnets: existingVnet.properties.subnets
    }
  : {}

@description('NSG properties for validation (empty object if not using existing NSG)')
output nsgProperties object = useExistingNsg && !empty(existingNsgName)
  ? {
      location: existingNsg.location
      securityRules: existingNsg.properties.securityRules
    }
  : {}

@description('Subnet properties for validation (empty object if not using existing subnet)')
output subnetProperties object = useExistingVnet && useExistingSubnet && !empty(existingSubnetName)
  ? {
      addressPrefix: existingSubnet.properties.addressPrefix
      addressPrefixes: existingSubnet.properties.?addressPrefixes ?? []
      networkSecurityGroup: existingSubnet.properties.?networkSecurityGroup ?? {}
    }
  : {}

// -------------------------------------------
// Validation Outputs
// -------------------------------------------

@description('Whether existing resources are being used')
output usingExistingResources bool = useExistingNsg || useExistingVnet

@description('Summary of resource usage strategy')
output resourceStrategy object = {
  nsg: useExistingNsg ? 'existing' : 'create'
  vnet: useExistingVnet ? 'existing' : 'create'
  subnet: useExistingVnet && useExistingSubnet ? 'existing' : 'create'
}