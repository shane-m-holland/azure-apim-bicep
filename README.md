# 🚀 Azure API Management (APIM) Deployment Automation

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bicep](https://img.shields.io/badge/Bicep-Azure-blue?logo=azure)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

This project provides a comprehensive shell script-driven Azure API Management (APIM) deployment solution using Bicep Infrastructure as Code. Features include:

- **🎯 Unified CLI Interface**: Single entry point (`apim.sh`) for all operations
- **📝 YAML Configuration Support**: Modern YAML configs with comments + full JSON backward compatibility
- **🔒 Security-First Configuration**: No secrets or environment-specific data committed to repository
- **🌍 Environment-Based Deployment**: Separate configurations for dev/staging/prod environments  
- **🧠 Intelligent API Synchronization**: Deploy only changed APIs for faster updates
- **✅ Comprehensive Validation**: Pre-deployment validation of all configurations and templates
- **🎛️ Interactive Setup**: Guided environment configuration from examples
- **🏗️ Infrastructure as Code**: Complete APIM infrastructure using Bicep templates
- **🛠️ Advanced Debugging**: Verbose and debug modes for troubleshooting
- **🔄 Flexible Deployment Options**: Dry-run, parallel, and force modes
- **♻️ Lifecycle Management**: Complete infrastructure and API lifecycle support
- **🌐 Multi-Format API Support**: OpenAPI/Swagger (JSON/YAML) and WSDL/SOAP specifications

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
├── apim.sh                          # 🆕 Unified CLI entry point (recommended)
├── bicep/                           # Infrastructure as Code
│   ├── main.bicep                   # Main deployment entry point
│   ├── apim/                        # APIM service templates
│   ├── apis/                        # API deployment templates
│   ├── network/                     # Network infrastructure
│   ├── products/                    # API product definitions
│   ├── gateways/                    # Self-hosted gateway config
│   └── diagnostics/                 # Monitoring and logging
├── scripts/                         # Deployment automation
│   ├── lib/                         # 🆕 Shared utility libraries
│   │   └── config-utils.sh          # Configuration parsing (JSON/YAML)
│   ├── setup-environment.sh         # Interactive environment setup
│   ├── validate-config.sh           # Configuration validation (YAML/JSON support)
│   ├── deploy-infrastructure.sh     # Infrastructure deployment
│   ├── deploy-apis.sh               # API deployment (YAML/JSON support)
│   ├── sync-apis.sh                 # Intelligent API synchronization (YAML/JSON)
│   ├── destroy-apis.sh              # API cleanup (YAML/JSON support)
│   └── destroy-infrastructure.sh    # Infrastructure cleanup with purge options
├── environments/                    # Environment configs (created locally)
├── examples/                        # Configuration templates
│   ├── config.env.example           # Environment configuration template
│   ├── api-config.yaml.example      # 🆕 YAML API configuration template (recommended)
│   └── api-config.json.example      # JSON API configuration template (legacy)
└── specs/                           # OpenAPI/WSDL/SOAP specifications
```

---

## 🚀 Quick Start

### Prerequisites
- **Azure CLI**: Required for all Azure operations
- **jq**: Required for JSON processing in scripts
- **yq**: Required for YAML processing (install with `pip install yq` or `brew install yq`)
- **Bicep CLI**: Install with `az bicep install`
- **Azure Login**: Run `az login` before deployment
- **Environment Variables**: Set `AZURE_SUBSCRIPTION_ID` for your target subscription

### Required Azure Permissions

The service principal or user account performing the deployment must have the following minimum permissions:

#### Custom Role Definition (Least Privilege)

For production environments, create a custom role with minimal permissions:

```json
{
    "properties": {
        "roleName": "APIM Deployment Role",
        "description": "Minimal permissions for APIM API deployment via Bicep",
        "assignableScopes": [
            "/subscriptions/<subscription-id>"
        ],
        "permissions": [
            {
                "actions": [
                    "Microsoft.ApiManagement/service/read",
                    "Microsoft.ApiManagement/service/write", 
                    "Microsoft.ApiManagement/service/apis/*",
                    "Microsoft.ApiManagement/service/products/*",
                    "Microsoft.ApiManagement/service/tags/*",
                    "Microsoft.ApiManagement/service/gateways/*",
                    "Microsoft.ApiManagement/service/diagnostics/*",
                    "Microsoft.ApiManagement/service/operationresults/read",
                    "Microsoft.ApiManagement/service/tenant/*",

                    "Microsoft.Resources/deployments/read",
                    "Microsoft.Resources/deployments/write",
                    "Microsoft.Resources/deployments/validate/action",
                    "Microsoft.Resources/deployments/operations/read",
                    "Microsoft.Resources/deployments/operationstatuses/read",
                    
                    "Microsoft.Resources/subscriptions/resourceGroups/read",
                    "Microsoft.Resources/subscriptions/resourceGroups/write",
                    "Microsoft.Resources/subscriptions/resourceGroups/delete",

                    "Microsoft.Authorization/roleDefinitions/read",
                    "Microsoft.Authorization/roleAssignments/read",

                    "Microsoft.Insights/alertRules/read",
                    "Microsoft.ResourceHealth/availabilityStatuses/read",
                    
                    "Microsoft.Resources/tags/read",
                    "Microsoft.Resources/tags/write",
                    "Microsoft.Resources/tags/delete",
                    
                    "Microsoft.Network/register/action",
                    "Microsoft.Network/unregister/action",

                    "Microsoft.Network/virtualNetworks/read",
                    "Microsoft.Network/virtualNetworks/write",
                    "Microsoft.Network/virtualNetworks/delete",
                    "Microsoft.Network/virtualNetworks/join/action",

                    "Microsoft.Network/virtualNetworks/subnets/read",
                    "Microsoft.Network/virtualNetworks/subnets/write",
                    "Microsoft.Network/virtualNetworks/subnets/delete",
                    "Microsoft.Network/virtualNetworks/subnets/join/action",
                    "Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action",

                    "Microsoft.Network/networkSecurityGroups/read",
                    "Microsoft.Network/networkSecurityGroups/write",
                    "Microsoft.Network/networkSecurityGroups/delete",
                    "Microsoft.Network/networkSecurityGroups/join/action",
                    "Microsoft.Network/networkSecurityGroups/securityRules/read",
                    "Microsoft.Network/networkSecurityGroups/securityRules/write",
                    "Microsoft.Network/networkSecurityGroups/securityRules/delete",

                    "Microsoft.Network/locations/operations/read",
                    "Microsoft.Network/locations/operationResults/read",
                    "Microsoft.Network/operations/read"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
```

### Initial Setup
```bash
# Clone the repository
git clone <this-repo>
cd azure-apim-bicep

# Make shell scripts executable (required on Unix/Linux/macOS)
chmod +x apim.sh scripts/*.sh
```

### ⚠️ Important: V2 SKU Requirements

If using **V2 SKUs** (BasicV2, StandardV2, PremiumV2), be aware of the following:

**Automatic Subnet Delegation** - When creating new subnets, the templates automatically handle delegation to `Microsoft.Web/serverFarms` (required for V2 SKUs).

**Manual Delegation Required** - If using an **existing subnet** with V2 SKUs, you must manually delegate the subnet before deployment:

```bash
az network vnet subnet update \
  --resource-group <vnet-resource-group> \
  --vnet-name <vnet-name> \
  --name <subnet-name> \
  --delegations Microsoft.Web/serverFarms
```

For detailed information, see [docs/V2-SKU-SUBNET-DELEGATION.md](docs/V2-SKU-SUBNET-DELEGATION.md)

### Using the Unified CLI (Recommended)

The project now includes a unified CLI interface (`apim.sh`) that provides a single entry point for all operations:

```bash
# Interactive environment setup
./apim.sh setup dev

# Validate configuration (supports both YAML and JSON)
./apim.sh validate dev

# Deploy infrastructure (30-45 minutes first time)
./apim.sh deploy infrastructure dev

# Deploy APIs (supports YAML/JSON configuration auto-discovery)
./apim.sh deploy apis dev

# Smart synchronization (only deploy changed APIs)
./apim.sh sync dev

# Get help
./apim.sh help
```

### Manual Script Usage (Advanced)

You can also use the scripts directly for more control:

```bash
# 1. Setup environment configuration
mkdir -p environments/dev
cp examples/config.env.example environments/dev/config.env

# Choose your preferred configuration format:
# YAML (recommended - supports comments)
cp examples/api-config.yaml.example environments/dev/api-config.yaml
# OR JSON (legacy support)
cp examples/api-config.json.example environments/dev/api-config.json

# 2. Edit configurations with your values
vim environments/dev/config.env
vim environments/dev/api-config.yaml  # or api-config.json

# 3. Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# 4. Validate configuration
./scripts/validate-config.sh dev

# 5. Deploy infrastructure
./scripts/deploy-infrastructure.sh dev

# 6. Deploy APIs
./scripts/deploy-apis.sh dev

# 7. For updates, use smart sync
./scripts/sync-apis.sh dev
```

## 📜 Script Reference

All scripts follow a consistent environment-based pattern and include comprehensive error handling, logging, and safety features. They support both YAML and JSON configuration formats with automatic format detection.

### 🎯 Unified CLI (apim.sh)
**Single entry point for all operations (Recommended)**

```bash
./apim.sh <command> <environment> [options...]
```

**Available Commands:**
- **`setup`**: Interactive environment configuration setup
- **`validate`**: Comprehensive configuration validation  
- **`deploy infrastructure`**: Deploy APIM infrastructure
- **`deploy apis`**: Deploy APIs from configuration
- **`sync`**: Intelligent API synchronization with change detection
- **`destroy apis`**: Safe API deletion with confirmation
- **`destroy infrastructure`**: Infrastructure cleanup
- **`help`**: Show detailed help information

**Common Examples:**
```bash
./apim.sh setup dev                    # Interactive setup
./apim.sh validate dev                 # Validate configurations
./apim.sh deploy infrastructure dev    # Deploy APIM (30-45 min)
./apim.sh deploy apis dev --parallel   # Deploy APIs in parallel
./apim.sh sync dev                     # Smart sync (changed APIs only)
./apim.sh help                         # Show all available options
```

### 🛠️ Individual Scripts
**Direct script access for advanced usage**

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
- **Features**: YAML/JSON validation, Bicep compilation, API spec validation (OpenAPI/WSDL)
- **Supports**: Auto-detection of YAML/JSON configuration formats
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

- **Purpose**: Deploy all APIs from YAML/JSON configuration
- **Features**: Environment variable substitution, YAML/JSON auto-detection, resource validation, error reporting
- **Supports**: OpenAPI (JSON/YAML) and WSDL/SOAP specifications
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

- **Purpose**: Deploy only changed APIs for faster updates (supports YAML/JSON)
- **Features**: Change detection, intelligent comparison, YAML/JSON auto-detection, comprehensive debugging
- **Supports**: OpenAPI (JSON/YAML) and WSDL/SOAP specifications
- **Options**:
  - `--force-all`: Deploy all APIs regardless of changes
  - `--debug`: Enable detailed debugging output with raw Azure CLI responses
- **Example**: `./scripts/sync-apis.sh dev --debug`

### 🗑️ destroy-apis.sh
**Safe API deletion with confirmation and preview**

```bash
./scripts/destroy-apis.sh <environment> [config-file] [--dry-run] [--force] [--verbose]
```

- **Purpose**: Delete APIs with safety checks and confirmation (supports YAML/JSON)
- **Features**: Existence checking, confirmation prompts, YAML/JSON auto-detection, detailed summary
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

## 🔄 Network Resource Reuse Scenarios

The deployment supports flexible network resource usage to enable cost optimization and integration with existing infrastructure. You can mix and match new and existing network resources based on your requirements.

### Configuration Overview

Network resource reuse is configured through environment variables in your `environments/{env}/config.env` file:

```bash
# Network Security Group (NSG) Strategy
USE_EXISTING_NSG=false                     # true/false - Reuse existing NSG
EXISTING_NSG_RESOURCE_GROUP=               # Resource group containing existing NSG
EXISTING_NSG_RESOURCE_ID=                  # Full resource ID of existing NSG

# Virtual Network (VNet) Strategy  
USE_EXISTING_VNET=false                    # true/false - Reuse existing VNet
EXISTING_VNET_RESOURCE_GROUP=              # Resource group containing existing VNet
EXISTING_VNET_RESOURCE_ID=                 # Full resource ID of existing VNet

# Subnet Strategy (when using existing VNet)
USE_EXISTING_SUBNET=false                  # true/false - Reuse existing subnet
CREATE_NEW_SUBNET_IN_EXISTING_VNET=true    # true/false - Create new subnet in existing VNet
```

### Supported Deployment Scenarios

#### 1. Full New Infrastructure (Default Behavior)
**Configuration:**
```bash
USE_EXISTING_NSG=false
USE_EXISTING_VNET=false
# All network resources created fresh
```
**Use Cases:**
- New APIM deployments in isolated environments
- Development/testing environments
- Complete infrastructure ownership

#### 2. Shared Network Security Group
**Configuration:**
```bash
USE_EXISTING_NSG=true
EXISTING_NSG_RESOURCE_ID=/subscriptions/.../providers/Microsoft.Network/networkSecurityGroups/shared-nsg
USE_EXISTING_VNET=false
```
**Use Cases:**
- Standardized security rules across multiple APIM instances
- Centralized network security management
- Compliance with enterprise security policies

#### 3. Reuse VNet + Create New Subnet
**Configuration:**
```bash
USE_EXISTING_VNET=true
EXISTING_VNET_RESOURCE_ID=/subscriptions/.../providers/Microsoft.Network/virtualNetworks/enterprise-vnet
USE_EXISTING_SUBNET=false
CREATE_NEW_SUBNET_IN_EXISTING_VNET=true
SUBNET_NAME=apim-dev-subnet
SUBNET_CIDR=10.100.5.0/24
```
**Use Cases:**
- Integration with existing enterprise network infrastructure
- Shared VNet with isolated APIM subnets
- Multi-environment deployments in same VNet

#### 4. Full Network Infrastructure Reuse
**Configuration:**
```bash
USE_EXISTING_NSG=true
USE_EXISTING_VNET=true
USE_EXISTING_SUBNET=true
EXISTING_NSG_RESOURCE_ID=/subscriptions/.../networkSecurityGroups/enterprise-nsg
EXISTING_VNET_RESOURCE_ID=/subscriptions/.../virtualNetworks/enterprise-vnet
EXISTING_SUBNET_NAME=apim-shared-subnet
```
**Use Cases:**
- Maximum cost optimization through resource sharing
- Standardized network configuration across environments
- Integration with pre-existing network architecture

#### 5. Cross-Resource Group Scenarios
**Configuration:**
```bash
USE_EXISTING_NSG=true
EXISTING_NSG_RESOURCE_GROUP=network-rg
NSG_NAME=shared-apim-nsg
USE_EXISTING_VNET=true
EXISTING_VNET_RESOURCE_GROUP=network-rg
VNET_NAME=enterprise-vnet
```
**Use Cases:**
- Centralized network resources managed by network team
- Different resource groups for network vs. application resources
- Enterprise governance models

### Validation and Prerequisites

#### Pre-deployment Validation
The validation script checks:
```bash
./apim.sh validate dev
```
- Existing resources exist and are accessible
- Resource ID formats are correct
- Configuration consistency (e.g., can't use existing subnet with new VNet)
- Azure CLI permissions to access cross-resource group resources

#### Required Permissions
When using existing resources, ensure your deployment identity has:
- **Reader** access on existing NSG/VNet/Subnet resources
- **Network Contributor** if creating new subnets in existing VNets
- **Contributor** on target resource group for APIM deployment

### Best Practices

#### Cost Optimization
- **Shared NSG**: Reuse NSGs across multiple APIM instances in same region
- **Shared VNet**: Use existing enterprise VNets to avoid VNet peering costs
- **Dedicated Subnets**: Create dedicated subnets per APIM for isolation

#### Security Considerations
- **NSG Rules**: Existing NSGs must include required APIM rules (management endpoint port 3443)
- **Subnet Size**: Ensure existing subnets have sufficient IP addresses for APIM scaling
- **Network Isolation**: Use dedicated subnets even in shared VNets for security isolation

#### Troubleshooting
```bash
# Validate existing resources are accessible
az network nsg show --ids "/subscriptions/.../networkSecurityGroups/my-nsg"
az network vnet show --ids "/subscriptions/.../virtualNetworks/my-vnet"

# Check subnet availability in existing VNet
az network vnet subnet list --vnet-name my-vnet --resource-group network-rg

# Validate NSG rules for APIM requirements
az network nsg rule list --nsg-name my-nsg --resource-group network-rg \
  --query "[?destinationPortRange=='3443']"
```

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
| **Network Resource Reuse Parameters** | | | |
| `useExistingNsg`         | bool     | `false`                | Use existing NSG instead of creating new |
| `existingNsgName`        | string   | `''`                   | Name of existing NSG to use |
| `existingNsgResourceGroup` | string | `''`                   | Resource group containing existing NSG |
| `existingNsgResourceId`  | string   | `''`                   | Full resource ID of existing NSG |
| `useExistingVnet`        | bool     | `false`                | Use existing VNet instead of creating new |
| `existingVnetName`       | string   | `''`                   | Name of existing VNet to use |
| `existingVnetResourceGroup` | string | `''`                   | Resource group containing existing VNet |
| `existingVnetResourceId` | string   | `''`                   | Full resource ID of existing VNet |
| `useExistingSubnet`      | bool     | `false`                | Use existing subnet instead of creating new |
| `existingSubnetName`     | string   | `''`                   | Name of existing subnet to use |
| `createNewSubnetInExistingVnet` | bool | `true`            | Create new subnet in existing VNet |
| `productIds`             | array    | `['starter', 'unlimited']` | List of products to link to APIs |
| `gatewayNames`           | array    | `['managed']`          | List of gateways to link to APIs |

---

## 📡 API Configuration

APIs are deployed from OpenAPI/WSDL specifications with support for both YAML and JSON configuration formats, plus environment variable substitution.

### Configuration Format Support

The project supports **both YAML and JSON** configuration formats with automatic discovery:

- **YAML (Recommended)**: `api-config.yaml` - Supports comments, better readability, cleaner syntax
- **JSON (Legacy)**: `api-config.json` - Traditional format, still fully supported
- **Auto-discovery**: Scripts prefer YAML, fallback to JSON if YAML not found

### Configuration Structure Examples

**YAML Configuration (Recommended):**
```yaml
# YAML supports comments for better documentation
- apiId: my-api                    # Unique identifier for the API
  displayName: My API              # Human-readable name
  path: myapi                      # URL path segment
  specPath: ./specs/my-api.json    # Path to OpenAPI/WSDL specification
  format: openapi+json             # Specification format
  serviceUrl: ${BACKEND_URL}       # Backend service URL (with env vars)
  protocols:                       # Supported protocols
    - https
  subscriptionRequired: false      # Whether subscription key is required
  productIds:                      # APIM products to associate with
    - unlimited
  gatewayNames:                    # Gateways where API should be available
    - managed
  tags:                           # Tags for categorization
    - business
    - v1
  apiDescription: Description of my API
  apiType: http                   # API type (http, soap, websocket, graphql)
```

**JSON Configuration (Legacy):**
```json
[
  {
    "apiId": "my-api",
    "displayName": "My API",
    "path": "myapi",
    "specPath": "./specs/my-api.json",
    "format": "openapi+json",
    "serviceUrl": "${BACKEND_URL}",
    "protocols": ["https"],
    "subscriptionRequired": false,
    "productIds": ["unlimited"],
    "gatewayNames": ["managed"],
    "tags": ["business", "v1"],
    "apiDescription": "Description of my API",
    "apiType": "http"
  }
]
```

### Multi-Format API Specification Support

The project supports multiple API specification formats:

#### OpenAPI/REST APIs
- **JSON**: `.json` files (OpenAPI/Swagger specifications)
- **YAML**: `.yaml`, `.yml` files (OpenAPI specifications)
- **Formats**: `openapi+json`, `openapi`, `swagger-json`, `swagger-yaml`

#### WSDL/SOAP APIs
- **XML**: `.wsdl`, `.xml` files (SOAP web service descriptions)
- **Formats**: `wsdl`, `wsdl-link`
- **Validation**: Full XML validation, WSDL element checking, namespace validation

### Configuration Properties Reference

#### Required Properties
- **`apiId`**: Unique identifier (alphanumeric, hyphens, underscores only)
- **`displayName`**: Human-readable name for the API
- **`path`**: URL path segment (will be prefixed with APIM gateway URL) 
- **`specPath`**: Path to API specification file (OpenAPI JSON/YAML or WSDL/XML)

#### Optional Properties
- **`format`**: Specification format (default: `openapi+json`)
  - OpenAPI: `openapi+json`, `openapi`, `swagger-json`, `swagger-yaml`
  - WSDL: `wsdl`, `wsdl-link`
- **`serviceUrl`**: Backend service URL (supports environment variables)
- **`protocols`**: Array of supported protocols (default: `["https"]`)
- **`subscriptionRequired`**: Whether subscription key is required (default: `false`)
- **`productIds`**: Array of product IDs to associate with API (default: `["unlimited"]`)
- **`gatewayNames`**: Array of gateway names (default: `["managed"]`)  
- **`tags`**: Array of tags for categorization and discovery
- **`apiDescription`**: Detailed description of the API
- **`apiType`**: Type of API - `http`, `soap`, `websocket`, `graphql` (default: `http`)
- **`policies`**: Advanced APIM policies (inbound, outbound, backend, on-error)

#### Advanced Policy Configuration
```yaml
- apiId: secure-api
  displayName: Secure API
  # ... other properties ...
  policies:
    inbound:                         # Policies applied to incoming requests
      - type: rate-limit             # Rate limiting policy
        calls: 1000                  # Maximum calls per renewal period
        renewal-period: 3600         # Period in seconds (1 hour)
      - type: ip-filter              # IP address filtering
        action: allow                # Allow or deny
        addresses:                   # List of allowed IP ranges
          - 10.0.0.0/8
          - 172.16.0.0/12
      - type: validate-jwt           # JWT token validation
        header-name: Authorization
        failed-validation-httpcode: 401
        require-expiration-time: true
        require-signed-tokens: true
```

### Environment Variable Substitution

Use `${VARIABLE_NAME}` syntax in any string value for environment-specific configuration:

**YAML Example:**
```yaml
- apiId: users-api
  serviceUrl: ${USERS_API_URL}           # From environment config
  apiDescription: API for ${ENVIRONMENT} environment
```

**JSON Example:**
```json
{
  "serviceUrl": "${API_BACKEND_URL}",
  "apiDescription": "API for ${ENVIRONMENT} environment"
}
```

Variables are substituted during deployment from your `environments/{env}/config.env` file.

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

#### YAML/JSON Configuration Issues
```bash
# Problem: "yq is not installed - YAML configuration support will be limited"
# Solution: Install yq for full YAML support
pip install yq  # or brew install yq

# Problem: YAML syntax errors
# Solution: Use verbose validation to see detailed YAML parsing errors
./scripts/validate-config.sh dev --verbose

# Problem: Configuration not found
# Solution: Scripts auto-discover config format (YAML preferred, JSON fallback)
# Ensure you have either api-config.yaml OR api-config.json in your environment folder
ls environments/dev/api-config.*
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


