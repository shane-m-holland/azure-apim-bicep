# 🚀 Azure API Management (APIM) Bicep Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bicep](https://img.shields.io/badge/Bicep-Azure-blue?logo=azure)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

This GitHub repository contains a **modular, reusable Bicep-based template** for deploying Azure API Management (APIM) environments. It includes core infrastructure setup with optional extensions for APIs, products, and a self-hosted gateway.

---

## 📁 Project Structure

```
.
├── main.bicep                  # Entry point for deployment
├── main.parameters.json        # Deployment parameters
├── apimService.bicep           # Defines the APIM instance
├── apis/
│   └── echo-api.bicep          # Sample Echo API definition
├── products/
│   └── products.bicep          # Starter and Unlimited product definitions
├── gateways/
│   └── gateway.bicep           # Default self-hosted gateway resource
└── diagnostics/
    └── diagnostics.bicep       # Stub for future diagnostics configuration
```

---

## 🚀 How to Deploy

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
az deployment group create   --resource-group my-apim-rg   --template-file main.bicep   --parameters @main.parameters.json
```

---

## ⚙️ Parameters

| Parameter         | Description                                 |
|------------------|---------------------------------------------|
| `subscriptionId` | Azure subscription ID                       |
| `apimName`       | Name of the APIM instance                   |
| `location`       | Azure region (e.g., "East US")              |
| `skuName`        | APIM SKU tier (e.g., Developer, Premium)    |
| `skuCapacity`    | Capacity (e.g., 1)                          |
| `publisherEmail` | Publisher contact email                     |
| `publisherName`  | Name shown in the APIM portal               |
| `vnetResourceId` | Resource ID of the virtual network          |

---

## 📦 Included Resources

| Module         | Description                                |
|----------------|--------------------------------------------|
| `apimService`  | Core APIM instance                         |
| `echoApi`      | Sample Echo API                            |
| `products`     | Starter and Unlimited products             |
| `gateway`      | Self-hosted gateway resource               |
| `diagnostics`  | Placeholder diagnostics module             |

---

## 🧭 Next Steps

- [ ] Add more APIs (e.g., `apis/soap-api.bicep`)
- [ ] Add policy support (e.g., `policies/*.xml`)
- [ ] Add diagnostics/logging modules
- [ ] Secure named values using Azure Key Vault or parameters

---

## 📝 License

This project is licensed under the [MIT License](LICENSE).

---

## 📚 Resources

- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [API Management Documentation](https://learn.microsoft.com/azure/api-management/)

