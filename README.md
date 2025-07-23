# 🚀 Azure API Management (APIM) Deployment Automation

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bicep](https://img.shields.io/badge/Bicep-Azure-blue?logo=azure)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

This project provides a comprehensive shell script-driven Azure API Management (APIM) deployment solution using Bicep Infrastructure as Code. Features include:

- **🔒 Security-First Configuration**: No secrets or environment-specific data committed to repository
- **🌍 Environment-Based Deployment**: Separate configurations for dev/staging/prod environments  
- **🧠 Intelligent API Synchronization**: Deploy only changed APIs for faster updates
- **✅ Comprehensive Validation**: Pre-deployment validation of all configurations and templates
- **🎛️ Interactive Setup**: Guided environment configuration from examples
- **🏗️ Infrastructure as Code**: Complete APIM infrastructure using Bicep templates
- **🛠️ Advanced Debugging**: Verbose and debug modes for troubleshooting
- **🔄 Flexible Deployment Options**: Dry-run, parallel, and force modes
- **♻️ Lifecycle Management**: Complete infrastructure and API lifecycle support

## 🏗️ Architecture Components

- Virtual Network and Network Security Group
- Azure API Management service with configurable SKUs
- API deployment from OpenAPI/WSDL specifications
- API Products and gateway configuration
- Optional self-hosted Gateway support
- Monitoring and diagnostics setup

---

## 📁 Project Structure

```
.
├── README.md                        # Project documentation
├── bicep/                           # Infrastructure as Code
│   ├── main.bicep                   # Main deployment entry point
│   ├── apim/                        # APIM service templates
│   ├── apis/                        # API deployment templates
│   ├── network/                     # Network infrastructure
│   ├── products/                    # API product definitions
│   ├── gateways/                    # Self-hosted gateway config
│   └── diagnostics/                 # Monitoring and logging
├── scripts/                         # Deployment automation
│   ├── setup-environment.sh         # Interactive environment setup
│   ├── validate-config.sh           # Configuration validation
│   ├── deploy-infrastructure.sh     # Infrastructure deployment
│   ├── deploy-apis.sh               # API deployment with parallel/verbose modes
│   ├── sync-apis.sh                 # Intelligent API synchronization with debugging
│   ├── destroy-apis.sh              # API cleanup with safety checks
│   └── destroy-infrastructure.sh    # Infrastructure cleanup with purge options
├── environments/                    # Environment configs (created locally)
├── examples/                        # Configuration templates
│   ├── config.env.example           # Environment configuration template
│   └── api-config.json.example      # API configuration template
└── specs/                           # OpenAPI/WSDL specifications
```

---

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and configured
- jq installed for JSON processing  
- Bicep CLI installed: `az bicep install`

### Initial Setup
```bash
# Clone the repository
git clone <this-repo>
cd azure-apim-bicep

# Make shell scripts executable (required on Unix/Linux/macOS)
chmod +x scripts/*.sh
```

### 1. First Time Setup

```bash
# Clone and setup
git clone <this-repo>
cd azure-apim-bicep

# Create your environment configuration from examples
mkdir -p environments/dev
cp examples/config.env.example environments/dev/config.env
cp examples/api-config.json.example environments/dev/api-config.json

# Edit the configuration files with your values
vim environments/dev/config.env
vim environments/dev/api-config.json
```

### 2. Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Validate Configuration

```bash
./scripts/validate-config.sh dev
```

### 4. Deploy Infrastructure

```bash
# Deploy APIM infrastructure (takes 30-45 minutes)
./scripts/deploy-infrastructure.sh dev

# Deploy APIs
./scripts/deploy-apis.sh dev
```

### 5. Subsequent Updates

```bash
# For faster API updates, use sync (deploys only changed APIs)
./scripts/sync-apis.sh dev
```

## 📜 Script Reference

All scripts follow a consistent environment-based pattern and include comprehensive error handling, logging, and safety features.

### 🎛️ setup-environment.sh
**Interactive environment configuration setup**

```bash
./scripts/setup-environment.sh [environment-name]
```

- **Purpose**: Guides you through creating environment configurations
- **Features**: Interactive prompts, validation, configuration templates
- **Example**: `./scripts/setup-environment.sh dev`

### ✅ validate-config.sh  
**Comprehensive configuration and template validation**

```bash
./scripts/validate-config.sh <environment> [config-file] [--verbose]
```

- **Purpose**: Validates all configurations before deployment
- **Features**: JSON validation, Bicep compilation, API spec validation
- **Options**:
  - `--verbose`: Show detailed validation output
- **Example**: `./scripts/validate-config.sh dev --verbose`

### 🏗️ deploy-infrastructure.sh
**Deploy APIM infrastructure using Bicep templates**

```bash
./scripts/deploy-infrastructure.sh <environment> [--dry-run]
```

- **Purpose**: Deploy complete APIM infrastructure (30-45 minutes)
- **Features**: Parameter generation, pre-flight checks, deployment monitoring
- **Options**:
  - `--dry-run`: Validate and generate parameters without deploying
- **Example**: `./scripts/deploy-infrastructure.sh dev --dry-run`

### 🚀 deploy-apis.sh
**Deploy APIs with enhanced error handling and parallel support**

```bash
./scripts/deploy-apis.sh <environment> [config-file] [--dry-run] [--parallel] [--verbose]
```

- **Purpose**: Deploy all APIs from configuration
- **Features**: Environment variable substitution, resource validation, error reporting
- **Options**:
  - `--dry-run`: Validate configuration without deploying
  - `--parallel`: Deploy APIs in parallel for faster execution
  - `--verbose`: Show detailed deployment output and debugging
- **Example**: `./scripts/deploy-apis.sh dev --parallel --verbose`

### 🧠 sync-apis.sh
**Intelligent API synchronization with change detection**

```bash
./scripts/sync-apis.sh <environment> [config-file] [--force-all] [--debug]
```

- **Purpose**: Deploy only changed APIs for faster updates
- **Features**: Change detection, intelligent comparison, comprehensive debugging
- **Options**:
  - `--force-all`: Deploy all APIs regardless of changes
  - `--debug`: Enable detailed debugging output with raw Azure CLI responses
- **Example**: `./scripts/sync-apis.sh dev --debug`

### 🗑️ destroy-apis.sh
**Safe API deletion with confirmation and preview**

```bash
./scripts/destroy-apis.sh <environment> [config-file] [--dry-run] [--force] [--verbose]
```

- **Purpose**: Delete APIs with safety checks and confirmation
- **Features**: Existence checking, confirmation prompts, detailed summary
- **Options**:
  - `--dry-run`: Preview what would be deleted without deleting
  - `--force`: Skip confirmation prompts
  - `--verbose`: Show detailed deletion progress
- **Example**: `./scripts/destroy-apis.sh dev --dry-run`

### 💥 destroy-infrastructure.sh
**Infrastructure cleanup with soft-delete handling**

```bash
./scripts/destroy-infrastructure.sh <environment> [--force] [--keep-rg] [--purge]
```

- **Purpose**: Safely destroy APIM infrastructure with cleanup options
- **Features**: API cleanup, confirmation prompts, soft-delete handling
- **Options**:
  - `--force`: Skip confirmation prompts
  - `--keep-rg`: Keep resource group after destroying APIM
  - `--purge`: Force hard delete and purge soft-deleted APIM instances
- **Example**: `./scripts/destroy-infrastructure.sh dev --purge`

---

## 🔄 Advanced: Multi-Subscription Deployments

The scripts support automatic subscription switching for scenarios where you manage multiple Azure subscriptions:

### When to Use Subscription ID Override

1. **Multi-tenant environments**: Different environments in different Azure subscriptions
2. **Team collaboration**: Ensure deployments target the correct subscription regardless of current Azure CLI context
3. **CI/CD pipelines**: Explicitly specify target subscription for automated deployments

### How to Configure

In your `environments/{env}/config.env`, uncomment and set:

```bash
SUBSCRIPTION_ID=your-target-subscription-id
```

### What Happens

- If `SUBSCRIPTION_ID` is set and differs from current context, scripts automatically switch subscriptions
- If not set, scripts use your current Azure CLI context (from `az account set`)
- All scripts log which subscription they're using for transparency

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

APIs are deployed from OpenAPI/WSDL specifications with support for environment variable substitution.

### Configuration Structure

Each API in `api-config.json` supports the following parameters:

```json
{
  "apiId": "my-api",
  "displayName": "My API",
  "apiDescription": "Description of my API",
  "path": "myapi",
  "format": "openapi+json",
  "specPath": "./specs/my-api.openapi.json",
  "serviceUrl": "${BACKEND_URL}",
  "protocols": ["https"],
  "subscriptionRequired": false,
  "productIds": ["unlimited"],
  "gatewayNames": ["managed"],
  "tags": ["business", "v1"]
}
```

### Required Parameters
- `apiId`: Unique identifier for the API
- `displayName`: Human-readable name
- `path`: URL path segment
- `specPath`: Path to OpenAPI/WSDL specification file

### Optional Parameters
- `apiDescription`: API description (defaults to empty)
- `format`: Specification format (`openapi+json`, `openapi`, `wsdl`)
- `serviceUrl`: Backend service URL (supports environment variables)
- `protocols`: Supported protocols (`["https"]`, `["http", "https"]`)
- `subscriptionRequired`: Whether API requires subscription (default: `false`)
- `productIds`: Array of product IDs to associate with
- `gatewayNames`: Array of gateway names to associate with
- `tags`: Array of tags for categorization

### Environment Variable Substitution

Use `${VARIABLE_NAME}` syntax in any string value for environment-specific configuration:

```json
{
  "serviceUrl": "${API_BACKEND_URL}",
  "apiDescription": "API for ${ENVIRONMENT} environment"
}
```

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Authentication Issues
```bash
# Problem: "Not logged in to Azure"
az login
az account set --subscription "your-subscription-id"
```

#### APIM Management Endpoint Connectivity
```bash
# Problem: "Failed to connect to management endpoint at *.management.azure-api.net:3443"
# Solution: This is typically a network security group (NSG) issue
# The NSG must allow inbound traffic on port 3443 from the ApiManagement service tag

# Check NSG rules:
az network nsg rule list --resource-group your-rg --nsg-name your-nsg --query "[?destinationPortRange=='3443']"
```

#### APIM Soft-Delete Issues
```bash
# Problem: "APIM instance already exists" after deletion
# Solution: APIM instances are soft-deleted by default
./scripts/destroy-infrastructure.sh dev --purge  # Force permanent deletion
```

#### JSON Parse Errors in sync-apis.sh
```bash
# Problem: "parse error: Invalid numeric literal"
# Solution: Use debug mode to see raw Azure CLI output
./scripts/sync-apis.sh dev --debug
```

#### API Deployment Failures
```bash
# Problem: Silent deployment failures
# Solution: Use verbose mode to see detailed error messages
./scripts/deploy-apis.sh dev --verbose
```

#### Configuration Validation Errors
```bash
# Problem: Bicep template compilation fails
# Solution: Validate configuration and templates
./scripts/validate-config.sh dev --verbose
```

### Debug Workflows

#### Full Debug Deployment
```bash
# 1. Validate everything first
./scripts/validate-config.sh dev --verbose

# 2. Deploy infrastructure with dry-run
./scripts/deploy-infrastructure.sh dev --dry-run

# 3. Deploy infrastructure
./scripts/deploy-infrastructure.sh dev

# 4. Deploy APIs with verbose output
./scripts/deploy-apis.sh dev --verbose

# 5. For subsequent updates, use sync with debug
./scripts/sync-apis.sh dev --debug
```

#### Recovery from Failed Deployment
```bash
# 1. Check what's currently deployed
./scripts/sync-apis.sh dev --debug

# 2. Clean up failed APIs if needed
./scripts/destroy-apis.sh dev --dry-run  # Preview first
./scripts/destroy-apis.sh dev --force    # Then delete

# 3. Redeploy with verbose output
./scripts/deploy-apis.sh dev --verbose
```

### Getting Help

If you encounter issues not covered here:

1. **Enable Debug Mode**: Use `--debug`, `--verbose`, or `--dry-run` flags
2. **Check Logs**: All scripts provide detailed timestamped logging  
3. **Validate Configuration**: Run `validate-config.sh` to catch issues early
4. **Test Connectivity**: Ensure Azure CLI can access your APIM instance

---

## 📚 Resources

- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [APIM Network Configuration](https://learn.microsoft.com/azure/api-management/api-management-using-with-vnet)
- [NSG Service Tags](https://learn.microsoft.com/azure/virtual-network/service-tags-overview)

---

## 📄 License

This project is licensed under the MIT License.


