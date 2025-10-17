# APIM V2 SKU Subnet Delegation Requirements

## Overview

Azure API Management V2 SKUs (BasicV2, StandardV2, PremiumV2) require **subnet delegation** to `Microsoft.Web/serverFarms` for VNet integration. This is different from classic SKUs which use traditional VNet integration.

## Automatic Delegation

The Bicep templates in this repository automatically handle subnet delegation for V2 SKUs when:

1. **Creating a new VNet and subnet** - The [vnet.bicep](../bicep/network/vnet.bicep) module automatically adds delegation for V2 SKUs
2. **Creating a new subnet in an existing VNet** - The [cross-rg-subnet.bicep](../bicep/network/cross-rg-subnet.bicep) module automatically adds delegation for V2 SKUs

## Manual Delegation Required

If you are **using an existing subnet** (`USE_EXISTING_SUBNET=true`), you must manually delegate the subnet before deployment.

### Option 1: Azure Portal

1. Navigate to your Virtual Network in the Azure Portal
2. Select **Subnets** from the left menu
3. Click on the subnet you want to use for APIM
4. Under **Subnet delegation**, select **Microsoft.Web/serverFarms**
5. Click **Save**

### Option 2: Azure CLI

```bash
# Set your variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="your-vnet-resource-group"
VNET_NAME="your-vnet-name"
SUBNET_NAME="your-subnet-name"

# Add subnet delegation
az network vnet subnet update \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --delegations Microsoft.Web/serverFarms
```

### Option 3: PowerShell

```powershell
# Set your variables
$subscriptionId = "your-subscription-id"
$resourceGroup = "your-vnet-resource-group"
$vnetName = "your-vnet-name"
$subnetName = "your-subnet-name"

# Set context
Set-AzContext -SubscriptionId $subscriptionId

# Get the subnet
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $vnetName
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName

# Add delegation
$delegation = New-AzDelegation -Name "apim-delegation" -ServiceName "Microsoft.Web/serverFarms"
$subnet.Delegations.Add($delegation)

# Update the subnet
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName `
  -AddressPrefix $subnet.AddressPrefix `
  -Delegation $delegation | Set-AzVirtualNetwork
```

## Deployment Error Reference

If you see this error during deployment:

```
{
  "code": "VirtualNetworkSubnetHasIncorrectDelegation",
  "message": "API Management service V2 outbound Virtual Network integration with SubnetId ...
              requires subnet to be delegated to Microsoft.Web/serverFarms.
              Please refer to https://aka.ms/apim-vnet-outbound for more details."
}
```

This means:
- You are deploying a V2 SKU (BasicV2, StandardV2, or PremiumV2)
- You are using an existing subnet
- The subnet is not delegated to `Microsoft.Web/serverFarms`

**Solution**: Manually delegate the subnet using one of the methods above, then retry the deployment.

## SKU-Specific Behavior

| SKU | VNet Support | Delegation Required |
|-----|-------------|-------------------|
| Developer | ❌ No | N/A |
| Basic | ❌ No | N/A |
| Standard | ❌ No | N/A |
| Premium | ✅ Yes | ❌ No (Classic VNet Integration) |
| BasicV2 | ✅ Yes | ✅ Yes (Microsoft.Web/serverFarms) |
| StandardV2 | ✅ Yes | ✅ Yes (Microsoft.Web/serverFarms) |
| PremiumV2 | ✅ Yes | ✅ Yes (Microsoft.Web/serverFarms) |

## Validation

To verify subnet delegation, use:

```bash
az network vnet subnet show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query delegations
```

Expected output for V2 SKUs:
```json
[
  {
    "name": "apim-delegation",
    "serviceName": "Microsoft.Web/serverFarms",
    ...
  }
]
```

## Additional Resources

- [Azure APIM VNet Integration Documentation](https://aka.ms/apim-vnet-outbound)
- [Azure Subnet Delegation Overview](https://docs.microsoft.com/azure/virtual-network/subnet-delegation-overview)
