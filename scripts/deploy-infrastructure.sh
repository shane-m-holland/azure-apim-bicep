#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: deploy-infrastructure.sh
# Description: Deploy Azure API Management infrastructure using environment-specific
#              configuration files. Generates parameters.json dynamically and
#              handles resource group creation.
# Usage: ./deploy-infrastructure.sh <environment> [--dry-run]
# Example: ./deploy-infrastructure.sh dev
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ──────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ──────────────────────────────────────────────────────────────────────────────

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}❌ ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

usage() {
    echo "Usage: $0 <environment> [--dry-run]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to deploy (dev, staging, prod)"
    echo "  --dry-run     Generate parameters and validate without deploying"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --dry-run"
    exit 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Argument Processing
# ──────────────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    error "Missing required environment argument"
    usage
fi

ENVIRONMENT="$1"
DRY_RUN=false

if [[ $# -gt 1 && "$2" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ──────────────────────────────────────────────────────────────────────────────
# Configuration Loading
# ──────────────────────────────────────────────────────────────────────────────

CONFIG_FILE="./environments/${ENVIRONMENT}/config.env"
PARAMS_FILE="./environments/${ENVIRONMENT}/parameters.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
    echo "Available environments:"
    ls -1 ./environments/ 2>/dev/null || echo "No environments configured"
    exit 1
fi

log "Loading environment configuration: $ENVIRONMENT"
source "$CONFIG_FILE"

# Validate required variables
REQUIRED_VARS=(
    "RESOURCE_GROUP" "APIM_NAME" "LOCATION" "SKU_NAME" "SKU_CAPACITY"
    "PUBLISHER_EMAIL" "PUBLISHER_NAME"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        error "Required variable $var is not set in $CONFIG_FILE"
        exit 1
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# Generate Parameters File
# ──────────────────────────────────────────────────────────────────────────────

log "Generating parameters file: $PARAMS_FILE"

mkdir -p "$(dirname "$PARAMS_FILE")"

cat > "$PARAMS_FILE" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "apimName": {
      "value": "$APIM_NAME"
    },
    "location": {
      "value": "$LOCATION"
    },
    "skuName": {
      "value": "$SKU_NAME"
    },
    "skuCapacity": {
      "value": $SKU_CAPACITY
    },
    "publisherEmail": {
      "value": "$PUBLISHER_EMAIL"
    },
    "publisherName": {
      "value": "$PUBLISHER_NAME"
    },
    "nsgName": {
      "value": "${NSG_NAME:-${APIM_NAME}-nsg}"
    },
    "vnetName": {
      "value": "${VNET_NAME:-${APIM_NAME}-vnet}"
    },
    "vnetCidr": {
      "value": "${VNET_CIDR:-10.0.0.0/16}"
    },
    "subnetName": {
      "value": "${SUBNET_NAME:-default}"
    },
    "subnetCidr": {
      "value": "${SUBNET_CIDR:-10.0.0.0/24}"
    },
    "selfHostedGatewayEnabled": {
      "value": ${SELF_HOSTED_GATEWAY_ENABLED:-false}
    },
    "selfHostedGatewayName": {
      "value": "${SELF_HOSTED_GATEWAY_NAME:-default}"
    }
  }
}
EOF

success "Generated parameters file"

# ──────────────────────────────────────────────────────────────────────────────
# Dry Run Mode
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN MODE - No resources will be created"
    echo ""
    echo "Configuration Summary:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  APIM Name: $APIM_NAME"
    echo "  Location: $LOCATION"
    echo "  SKU: $SKU_NAME (Capacity: $SKU_CAPACITY)"
    echo "  Publisher: $PUBLISHER_NAME <$PUBLISHER_EMAIL>"
    echo ""
    echo "Generated parameters file: $PARAMS_FILE"
    
    # Validate Bicep template
    log "Validating Bicep template..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file bicep/main.bicep \
        --parameters "@$PARAMS_FILE" \
        --no-prompt \
        2>/dev/null && success "Template validation passed" || error "Template validation failed"
    
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Azure Authentication Check
# ──────────────────────────────────────────────────────────────────────────────

log "Checking Azure authentication..."
if ! az account show >/dev/null 2>&1; then
    error "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi

CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv)
if [[ -n "${SUBSCRIPTION_ID:-}" && "$CURRENT_SUBSCRIPTION" != "$SUBSCRIPTION_ID" ]]; then
    log "Switching subscription from $CURRENT_SUBSCRIPTION to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
else
    log "Using current subscription: $CURRENT_SUBSCRIPTION"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Resource Group Management
# ──────────────────────────────────────────────────────────────────────────────

log "Checking resource group: $RESOURCE_GROUP"
if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    success "Resource group created"
else
    log "Resource group already exists"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Infrastructure Deployment
# ──────────────────────────────────────────────────────────────────────────────

log "Starting APIM infrastructure deployment..."
log "This may take 30-45 minutes for initial deployment..."

DEPLOYMENT_NAME="apim-infrastructure-$(date +%Y%m%d-%H%M%S)"

# Start deployment
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file bicep/main.bicep \
    --parameters "@$PARAMS_FILE" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

# Check deployment status
if [[ $? -eq 0 ]]; then
    success "APIM infrastructure deployment completed successfully"
    
    # Get APIM details
    APIM_GATEWAY_URL=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query gatewayUrl -o tsv)
    APIM_PORTAL_URL=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query developerPortalUrl -o tsv)
    
    echo ""
    echo "📋 Deployment Summary:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  APIM Instance: $APIM_NAME"
    echo "  Gateway URL: $APIM_GATEWAY_URL"
    echo "  Developer Portal: $APIM_PORTAL_URL"
    echo "  Deployment Name: $DEPLOYMENT_NAME"
    
else
    error "APIM infrastructure deployment failed"
    echo "Check deployment logs with:"
    echo "az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP"
    exit 1
fi

log "Infrastructure deployment completed for environment: $ENVIRONMENT"