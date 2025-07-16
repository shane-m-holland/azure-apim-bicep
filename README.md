# 🚀 Azure API Management (APIM) Bicep Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bicep](https://img.shields.io/badge/Bicep-Azure-blue?logo=azure)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

This project deploys a modular and configurable Azure API Management (APIM) environment using Bicep. It includes:

- Virtual Network and NSG
- API Management service
- API deployment from OpenAPI
- Starter and Unlimited Products
- Optional self-hosted Gateway


---

## 📁 Project Structure

```
.
├── main.bicep
├── template.parameters.json         # Template only — do not deploy directly
├── apimService.bicep
├── apis/
│   ├── restaurants-api.bicep
│   └── openapi/
├── products/
│   └── products.bicep
├── gateways/
│   └── gateway.bicep
├── network/
│   ├── nsg.bicep
│   └── vnet.bicep
└── diagnostics/
    └── diagnostics.bicep
```

---

## 🚀 How to Deploy

Use `template.parameters.json` as a **reference only**.  
For each environment (dev/stage/prod), create a copy like `dev.parameters.json`.

### 1. Set Azure Context

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Create Resource Group

```bash
az group create --name my-apim-rg --location "East US"
```

### 3. Deploy Bicep Template

```bash
az deployment group create      \
  --resource-group my-apim-rg   \
  --template-file main.bicep    \
  --parameters @main.parameters.json
```

---

## 🔣 Parameters

| Name                     | Type     | Default               | Description |
|--------------------------|----------|------------------------|-------------|
| `apimName`               | string   | *(required)*           | Name of the APIM instance |
| `location`               | string   | `'eastus'`             | Azure region for deployment |
| `skuName`                | string   | `'Developer'`          | APIM SKU (e.g., Developer, Premium) |
| `skuCapacity`            | int      | `1`                    | Capacity unit of the SKU |
| `publisherEmail`         | string   | *(required)*           | Email used for APIM publisher contact |
| `publisherName`          | string   | *(required)*           | Name of the APIM publisher |
| `nsgName`                | string   | `${apimName}-nsg`      | NSG resource name |
| `vnetName`               | string   | `${apimName}-vnet`     | VNET resource name |
| `vnetCidr`               | string   | `'10.0.0.0/16'`        | VNET address space |
| `subnetName`             | string   | `'default'`            | Subnet name within the VNET |
| `subnetCidr`             | string   | `'10.0.0.0/24'`        | Subnet address prefix |
| `selfHostedGatewayEnabled` | bool   | `false`                | Set to true to deploy a self-hosted gateway |
| `selfHostedGatewayName` | string   | `'default'`            | Name of the self-hosted gateway |
| `productIds`             | array    | `['starter', 'unlimited']` | List of products to link to APIs |
| `gatewayNames`           | array    | `['managed']`          | List of gateways to link to APIs |

---

## 📡 API Configuration

APIs are deployed from OpenAPI specs.  
Each API module (like `restaurants-api.bicep`) can be linked to multiple products and gateways via parameters.

> Place your OpenAPI definitions under `apis/openapi/` as JSON files.

---

## ⚠️ Parameters Template

`template.parameters.json` is a **reference template only**.  
Do not deploy with this file directly.

✅ Instead, create environment-specific parameter files such as:

- `dev.parameters.json`
- `prod.parameters.json`

---

## 📚 Resources

- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [API Management Documentation](https://learn.microsoft.com/azure/api-management/)

---

## 📄 License

This project is licensed under the MIT License.


