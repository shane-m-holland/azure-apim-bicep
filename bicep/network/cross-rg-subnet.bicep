// -------------------------------------------
// 🔌 Cross-Resource-Group Subnet Deployment
// -------------------------------------------
// This module handles subnet creation in existing VNets 
// that may be in different resource groups, avoiding 
// Bicep scope mismatch issues.

targetScope = 'resourceGroup'

@description('Resource ID of the existing Virtual Network')
param existingVnetResourceId string

@description('Name of the subnet to create')
param subnetName string

@description('CIDR block for the subnet (e.g., 10.0.0.0/24)')
param subnetCidr string

@description('Resource ID of the Network Security Group to associate with the subnet')
param nsgResourceId string

// -------------------------------------------
// Parse VNet Resource ID Components
// -------------------------------------------
var vnetResourceIdParts = split(existingVnetResourceId, '/')
var targetSubscriptionId = vnetResourceIdParts[2]
var targetResourceGroupName = vnetResourceIdParts[4]
var vnetName = vnetResourceIdParts[8]

// -------------------------------------------
// Deploy Subnet in Target Resource Group
// -------------------------------------------
module subnetDeployment 'subnet-deployment.bicep' = {
  name: 'deploy-subnet-${subnetName}'
  scope: resourceGroup(targetSubscriptionId, targetResourceGroupName)
  params: {
    vnetName: vnetName
    subnetName: subnetName
    subnetCidr: subnetCidr
    nsgResourceId: nsgResourceId
  }
}

// -------------------------------------------
// Outputs
// -------------------------------------------
@description('Resource ID of the created subnet')
output subnetResourceId string = subnetDeployment.outputs.subnetResourceId

@description('Name of the created subnet')
output subnetName string = subnetName