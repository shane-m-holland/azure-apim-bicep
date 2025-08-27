#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: setup-environment.sh
# Description: Interactive setup script for creating new APIM environments.
#              Guides users through configuration and validates inputs.
# Usage: ./setup-environment.sh [environment-name]
# Example: ./setup-environment.sh staging
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

prompt() {
    echo -e "${YELLOW}❓${NC} $1"
}

header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
}

usage() {
    echo "Usage: $0 [environment-name]"
    echo ""
    echo "Arguments:"
    echo "  environment-name    Name of environment to create (dev, staging, prod, etc.)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Interactive mode - will prompt for environment name"
    echo "  $0 staging          # Create staging environment"
    echo "  $0 test             # Create test environment"
    exit 1
}

read_input() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local validation_pattern="${3:-}"
    local value=""
    
    # Check if running in interactive terminal
    if [[ ! -t 0 ]]; then
        error "This script requires an interactive terminal"
        return 1
    fi
    
    while true; do
        if [[ -n "$default_value" ]]; then
            printf "%s [%s]: " "$prompt_text" "$default_value" >&2
        else
            printf "%s: " "$prompt_text" >&2
        fi
        
        read -r value
        
        # Use default if no input provided
        if [[ -z "$value" && -n "$default_value" ]]; then
            value="$default_value"
        fi
        
        # Validate input if pattern provided
        if [[ -n "$validation_pattern" ]]; then
            if [[ ! $value =~ $validation_pattern ]]; then
                error "Invalid input format. Please try again."
                continue
            fi
        fi
        
        # Check if value is not empty
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        else
            error "This field is required. Please provide a value."
        fi
    done
}

validate_environment_name() {
    local env="$1"
    
    # Check format
    if [[ ! $env =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
        error "Environment name must contain only lowercase letters, numbers, and hyphens"
        error "Must start and end with alphanumeric characters"
        return 1
    fi
    
    # Check length
    if [[ ${#env} -gt 20 ]]; then
        error "Environment name must be 20 characters or less"
        return 1
    fi
    
    return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Setup Logic
# ──────────────────────────────────────────────────────────────────────────────

ENVIRONMENT="${1:-}"

header "🚀 APIM Environment Setup"

info "This script will help you create a new APIM environment configuration."
info "You'll be prompted for various settings that will be used for deployment."

# Get environment name
if [[ -z "$ENVIRONMENT" ]]; then
    echo ""
    prompt "What would you like to name this environment?"
    info "Examples: dev, staging, prod, test, qa"
    
    while true; do
        ENVIRONMENT=$(read_input "Environment name" "" "^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$")
        if validate_environment_name "$ENVIRONMENT"; then
            break
        fi
    done
else
    if ! validate_environment_name "$ENVIRONMENT"; then
        exit 1
    fi
fi

ENV_DIR="./environments/$ENVIRONMENT"
CONFIG_FILE="$ENV_DIR/config.env"

# Check if environment already exists
if [[ -d "$ENV_DIR" ]]; then
    warning "Environment '$ENVIRONMENT' already exists at $ENV_DIR"
    echo -n "Do you want to overwrite it? (y/N): "
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log "Setup cancelled"
        exit 0
    fi
fi

# Create environment directory
mkdir -p "$ENV_DIR"
success "Created environment directory: $ENV_DIR"

header "📋 Basic Configuration"

info "Let's configure the basic settings for your APIM environment."

# Get basic configuration
RESOURCE_GROUP=$(read_input "Resource Group name" "apim-${ENVIRONMENT}-rg")
APIM_NAME=$(read_input "APIM instance name" "apim-${ENVIRONMENT}-instance")

# Suggest location based on common choices
echo ""
info "Common Azure locations: eastus, westus2, northeurope, westeurope, eastasia"
LOCATION=$(read_input "Azure region" "eastus")

header "🏗️  APIM Configuration"

# SKU Configuration with recommendations
echo ""
info "APIM SKU Options:"
echo ""
info "Classic SKUs:"
echo "  - Developer: For development/testing (low cost, single unit, no SLA)"
echo "  - Basic: Entry level for production (99.95% SLA, no VNet support)"
echo "  - Standard: Standard production tier (99.95% SLA, multi-region, no VNet support)"
echo "  - Premium: Enterprise tier (99.99% SLA, VNet support, multi-region)"
echo ""
info "v2 SKUs (Recommended for new deployments):"
echo "  - BasicV2: Entry level for production (99.95% SLA, VNet support)"
echo "  - StandardV2: Standard production tier (99.95% SLA, VNet support, multi-region)"  
echo "  - PremiumV2: Enterprise tier (99.99% SLA, VNet support, multi-region, enhanced features)"
echo ""
info "💡 VNet Integration: v2 SKUs support VNet integration out of the box, classic SKUs require Premium tier"

case "$ENVIRONMENT" in
    dev|development|test|testing)
        DEFAULT_SKU="Developer"
        ;;
    staging|stage|qa)
        DEFAULT_SKU="BasicV2"
        ;;
    prod|production)
        DEFAULT_SKU="StandardV2"
        ;;
    *)
        DEFAULT_SKU="Developer"
        ;;
esac

SKU_NAME=$(read_input "APIM SKU" "$DEFAULT_SKU" "^(Developer|Basic|Standard|Premium|BasicV2|StandardV2|PremiumV2)$")

# Capacity based on SKU
case "$SKU_NAME" in
    "Developer")
        DEFAULT_CAPACITY=1
        info "Developer SKU supports only 1 capacity unit"
        ;;
    "Basic"|"Standard"|"BasicV2")
        DEFAULT_CAPACITY=1
        if [[ "$SKU_NAME" == "BasicV2" ]]; then
            info "BasicV2 SKU supports 1-2 capacity units"
        fi
        ;;
    "StandardV2")
        DEFAULT_CAPACITY=1
        info "StandardV2 SKU supports 1-10 capacity units"
        ;;
    "Premium"|"PremiumV2")
        DEFAULT_CAPACITY=1
        if [[ "$SKU_NAME" == "Premium" ]]; then
            info "Premium SKU supports 1-12 capacity units"
        else
            info "PremiumV2 SKU supports 1-12 capacity units with enhanced performance"
        fi
        ;;
esac

SKU_CAPACITY=$(read_input "APIM capacity" "$DEFAULT_CAPACITY" "^[0-9]+$")

# VNet integration guidance based on selected SKU
echo ""
case "$SKU_NAME" in
    "Developer"|"Basic"|"Standard")
        if [[ "$USE_EXISTING_VNET" == "true" ]] || [[ -n "$VNET_NAME" && "$VNET_NAME" != "none" ]]; then
            warn "⚠️  VNet Integration Notice:"
            echo "   Selected SKU ($SKU_NAME) does not support VNet integration."
            echo "   Consider using BasicV2/StandardV2 for VNet integration, or Premium for classic SKU."
        fi
        ;;
    "BasicV2"|"StandardV2"|"Premium"|"PremiumV2")
        if [[ "$USE_EXISTING_VNET" == "true" ]] || [[ -n "$VNET_NAME" && "$VNET_NAME" != "none" ]]; then
            success "✅ VNet Integration: Selected SKU ($SKU_NAME) supports VNet integration"
        fi
        ;;
esac

header "👤 Publisher Information"

info "This information will be displayed in the developer portal and used for notifications."

PUBLISHER_NAME=$(read_input "Publisher/Organization name" "Your Company")
PUBLISHER_EMAIL=$(read_input "Publisher email" "" "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

header "🌐 Network Configuration"

info "Configuring virtual network settings for your APIM deployment."

NSG_NAME=$(read_input "Network Security Group name" "${APIM_NAME}-nsg")
VNET_NAME=$(read_input "Virtual Network name" "${APIM_NAME}-vnet")

# Suggest different CIDR blocks per environment to avoid conflicts
case "$ENVIRONMENT" in
    dev|development)
        DEFAULT_VNET_CIDR="10.1.0.0/16"
        DEFAULT_SUBNET_CIDR="10.1.0.0/24"
        ;;
    staging|stage)
        DEFAULT_VNET_CIDR="10.2.0.0/16"
        DEFAULT_SUBNET_CIDR="10.2.0.0/24"
        ;;
    prod|production)
        DEFAULT_VNET_CIDR="10.3.0.0/16"
        DEFAULT_SUBNET_CIDR="10.3.0.0/24"
        ;;
    *)
        DEFAULT_VNET_CIDR="10.0.0.0/16"
        DEFAULT_SUBNET_CIDR="10.0.0.0/24"
        ;;
esac

VNET_CIDR=$(read_input "VNET CIDR block" "$DEFAULT_VNET_CIDR" "^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$")
SUBNET_NAME=$(read_input "Subnet name" "apim-subnet")
SUBNET_CIDR=$(read_input "Subnet CIDR block" "$DEFAULT_SUBNET_CIDR" "^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$")

header "🔄 Network Resource Reuse Strategy"

info "You can reuse existing network resources to save costs and integrate with existing infrastructure."
info "This is useful for enterprise environments with shared network resources or multiple APIM instances."

# Initialize network reuse variables
USE_EXISTING_NSG="false"
EXISTING_NSG_RESOURCE_GROUP=""
EXISTING_NSG_RESOURCE_ID=""
USE_EXISTING_VNET="false"
EXISTING_VNET_RESOURCE_GROUP=""
EXISTING_VNET_RESOURCE_ID=""
USE_EXISTING_SUBNET="false"
CREATE_NEW_SUBNET_IN_EXISTING_VNET="true"

echo ""
echo -n "Do you want to reuse an existing Network Security Group (NSG)? (y/N): "
read -r nsg_reuse
if [[ $nsg_reuse =~ ^[Yy]$ ]]; then
    USE_EXISTING_NSG="true"
    info "You can specify the existing NSG by name or by full resource ID."
    
    echo -n "Do you have the full resource ID of the NSG? (y/N): "
    read -r has_nsg_id
    if [[ $has_nsg_id =~ ^[Yy]$ ]]; then
        EXISTING_NSG_RESOURCE_ID=$(read_input "NSG Resource ID" "" "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/networkSecurityGroups/[^/]+$")
    else
        info "Current NSG name: $NSG_NAME"
        echo -n "Use current NSG name or specify different name? (current/different): "
        read -r nsg_choice
        if [[ $nsg_choice == "different" ]]; then
            NSG_NAME=$(read_input "Existing NSG name")
        fi
        
        echo -n "Is the NSG in a different resource group? (y/N): "
        read -r different_nsg_rg
        if [[ $different_nsg_rg =~ ^[Yy]$ ]]; then
            EXISTING_NSG_RESOURCE_GROUP=$(read_input "NSG Resource Group")
        fi
    fi
    success "Will reuse existing NSG: ${EXISTING_NSG_RESOURCE_ID:-$NSG_NAME}"
fi

echo ""
echo -n "Do you want to reuse an existing Virtual Network (VNet)? (y/N): "
read -r vnet_reuse
if [[ $vnet_reuse =~ ^[Yy]$ ]]; then
    USE_EXISTING_VNET="true"
    info "You can specify the existing VNet by name or by full resource ID."
    
    echo -n "Do you have the full resource ID of the VNet? (y/N): "
    read -r has_vnet_id
    if [[ $has_vnet_id =~ ^[Yy]$ ]]; then
        EXISTING_VNET_RESOURCE_ID=$(read_input "VNet Resource ID" "" "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$")
    else
        info "Current VNet name: $VNET_NAME"
        echo -n "Use current VNet name or specify different name? (current/different): "
        read -r vnet_choice
        if [[ $vnet_choice == "different" ]]; then
            VNET_NAME=$(read_input "Existing VNet name")
        fi
        
        echo -n "Is the VNet in a different resource group? (y/N): "
        read -r different_vnet_rg
        if [[ $different_vnet_rg =~ ^[Yy]$ ]]; then
            EXISTING_VNET_RESOURCE_GROUP=$(read_input "VNet Resource Group")
        fi
    fi
    
    success "Will reuse existing VNet: ${EXISTING_VNET_RESOURCE_ID:-$VNET_NAME}"
    
    # Subnet configuration when using existing VNet
    echo ""
    info "Since you're using an existing VNet, choose your subnet strategy:"
    echo "  1. Use existing subnet in the VNet"
    echo "  2. Create new subnet in the existing VNet"
    
    echo -n "Do you want to use an existing subnet? (y/N): "
    read -r subnet_reuse
    if [[ $subnet_reuse =~ ^[Yy]$ ]]; then
        USE_EXISTING_SUBNET="true"
        CREATE_NEW_SUBNET_IN_EXISTING_VNET="false"
        
        info "Current subnet name: $SUBNET_NAME"
        echo -n "Use current subnet name or specify different name? (current/different): "
        read -r subnet_choice
        if [[ $subnet_choice == "different" ]]; then
            SUBNET_NAME=$(read_input "Existing subnet name")
        fi
        success "Will reuse existing subnet: $SUBNET_NAME"
    else
        USE_EXISTING_SUBNET="false"
        CREATE_NEW_SUBNET_IN_EXISTING_VNET="true"
        info "Current subnet configuration: $SUBNET_NAME ($SUBNET_CIDR)"
        echo -n "Keep current subnet configuration? (Y/n): "
        read -r keep_subnet
        if [[ $keep_subnet =~ ^[Nn]$ ]]; then
            SUBNET_NAME=$(read_input "New subnet name" "apim-subnet")
            SUBNET_CIDR=$(read_input "New subnet CIDR block" "$DEFAULT_SUBNET_CIDR" "^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$")
        fi
        success "Will create new subnet: $SUBNET_NAME ($SUBNET_CIDR) in existing VNet"
    fi
else
    success "Will create new VNet with subnet"
fi

# Validate configuration consistency
if [[ "$USE_EXISTING_VNET" == "false" && "$USE_EXISTING_SUBNET" == "true" ]]; then
    error "Configuration error: Cannot use existing subnet when creating new VNet"
    error "Please restart the setup and choose consistent options"
    exit 1
fi

echo ""
if [[ "$USE_EXISTING_NSG" == "true" || "$USE_EXISTING_VNET" == "true" ]]; then
    info "Network Resource Reuse Summary:"
    [[ "$USE_EXISTING_NSG" == "true" ]] && echo "  ✓ NSG: Reusing existing (${EXISTING_NSG_RESOURCE_ID:-$NSG_NAME})"
    [[ "$USE_EXISTING_NSG" == "false" ]] && echo "  → NSG: Creating new ($NSG_NAME)"
    [[ "$USE_EXISTING_VNET" == "true" ]] && echo "  ✓ VNet: Reusing existing (${EXISTING_VNET_RESOURCE_ID:-$VNET_NAME})"
    [[ "$USE_EXISTING_VNET" == "false" ]] && echo "  → VNet: Creating new ($VNET_NAME)"
    if [[ "$USE_EXISTING_VNET" == "true" ]]; then
        [[ "$USE_EXISTING_SUBNET" == "true" ]] && echo "  ✓ Subnet: Reusing existing ($SUBNET_NAME)"
        [[ "$USE_EXISTING_SUBNET" == "false" ]] && echo "  → Subnet: Creating new ($SUBNET_NAME)"
    else
        echo "  → Subnet: Creating new ($SUBNET_NAME)"
    fi
else
    info "Will create all new network resources (default behavior)"
fi

header "🚪 Gateway Configuration"

info "Self-hosted gateways allow you to deploy APIM gateways in on-premises or other cloud environments."

if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "production" ]]; then
    DEFAULT_GATEWAY_ENABLED="true"
else
    DEFAULT_GATEWAY_ENABLED="false"
fi

echo -n "Enable self-hosted gateway? (y/N): "
read -r gateway_confirm
if [[ $gateway_confirm =~ ^[Yy]$ ]]; then
    SELF_HOSTED_GATEWAY_ENABLED="true"
    SELF_HOSTED_GATEWAY_NAME=$(read_input "Self-hosted gateway name" "${ENVIRONMENT}-gateway")
else
    SELF_HOSTED_GATEWAY_ENABLED="false"
    SELF_HOSTED_GATEWAY_NAME="default"
fi


header "🎛️  Feature Flags"

info "Configure optional features for this environment."

# Default feature flags based on environment
case "$ENVIRONMENT" in
    prod|production)
        DEFAULT_DIAGNOSTICS="true"
        DEFAULT_MONITORING="true"
        DEFAULT_AUTO_SCALE="true"
        ;;
    staging|stage)
        DEFAULT_DIAGNOSTICS="true"
        DEFAULT_MONITORING="true"
        DEFAULT_AUTO_SCALE="false"
        ;;
    *)
        DEFAULT_DIAGNOSTICS="true"
        DEFAULT_MONITORING="false"
        DEFAULT_AUTO_SCALE="false"
        ;;
esac

echo -n "Enable diagnostics? (Y/n): "
read -r diag_confirm
if [[ $diag_confirm =~ ^[Nn]$ ]]; then
    ENABLE_DIAGNOSTICS="false"
else
    ENABLE_DIAGNOSTICS="true"
fi

echo -n "Enable monitoring? (y/N): "
read -r mon_confirm
if [[ $mon_confirm =~ ^[Yy]$ ]]; then
    ENABLE_MONITORING="true"
else
    ENABLE_MONITORING="false"
fi

echo -n "Enable auto-scaling? (y/N): "
read -r scale_confirm
if [[ $scale_confirm =~ ^[Yy]$ ]]; then
    AUTO_SCALE_ENABLED="true"
else
    AUTO_SCALE_ENABLED="false"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Generate Configuration File
# ──────────────────────────────────────────────────────────────────────────────

header "📝 Generating Configuration"

log "Creating configuration file: $CONFIG_FILE"

cat > "$CONFIG_FILE" << EOF
# $ENVIRONMENT Environment Configuration
# Generated on $(date)
ENVIRONMENT="$ENVIRONMENT"
RESOURCE_GROUP="$RESOURCE_GROUP"

# APIM Configuration
APIM_NAME="$APIM_NAME"
LOCATION="$LOCATION"
SKU_NAME="$SKU_NAME"
SKU_CAPACITY=$SKU_CAPACITY
PUBLISHER_EMAIL="$PUBLISHER_EMAIL"
PUBLISHER_NAME="$PUBLISHER_NAME"

# Network Configuration
NSG_NAME="$NSG_NAME"
VNET_NAME="$VNET_NAME"
VNET_CIDR="$VNET_CIDR"
SUBNET_NAME="$SUBNET_NAME"
SUBNET_CIDR="$SUBNET_CIDR"

# Network Resource Reuse Strategy
USE_EXISTING_NSG=$USE_EXISTING_NSG
EXISTING_NSG_RESOURCE_GROUP="$EXISTING_NSG_RESOURCE_GROUP"
EXISTING_NSG_RESOURCE_ID="$EXISTING_NSG_RESOURCE_ID"
USE_EXISTING_VNET=$USE_EXISTING_VNET
EXISTING_VNET_RESOURCE_GROUP="$EXISTING_VNET_RESOURCE_GROUP"
EXISTING_VNET_RESOURCE_ID="$EXISTING_VNET_RESOURCE_ID"
USE_EXISTING_SUBNET=$USE_EXISTING_SUBNET
CREATE_NEW_SUBNET_IN_EXISTING_VNET=$CREATE_NEW_SUBNET_IN_EXISTING_VNET

# Gateway Configuration
SELF_HOSTED_GATEWAY_ENABLED=$SELF_HOSTED_GATEWAY_ENABLED
SELF_HOSTED_GATEWAY_NAME="$SELF_HOSTED_GATEWAY_NAME"

# Feature Flags
ENABLE_DIAGNOSTICS=$ENABLE_DIAGNOSTICS
ENABLE_MONITORING=$ENABLE_MONITORING
AUTO_SCALE_ENABLED=$AUTO_SCALE_ENABLED
EOF

success "Configuration file created successfully!"

# ──────────────────────────────────────────────────────────────────────────────
# Summary and Next Steps
# ──────────────────────────────────────────────────────────────────────────────

header "🎉 Setup Complete"

echo "Environment '$ENVIRONMENT' has been configured successfully!"
echo ""
echo "📁 Configuration saved to: $CONFIG_FILE"
echo ""
echo "📋 Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  APIM Instance: $APIM_NAME"
echo "  Location: $LOCATION"
echo "  SKU: $SKU_NAME (Capacity: $SKU_CAPACITY)"
echo "  Publisher: $PUBLISHER_NAME <$PUBLISHER_EMAIL>"
echo ""

info "Next steps:"
echo "  1. Review the configuration in $CONFIG_FILE"
echo "  2. Ensure you're logged in to Azure:"
echo "     az login"
echo "  3. Validate the configuration:"
echo "     ./scripts/validate-config.sh $ENVIRONMENT"
echo "  4. Deploy the infrastructure:"
echo "     ./scripts/deploy-infrastructure.sh $ENVIRONMENT"
echo "  5. Deploy APIs:"
echo "     ./scripts/deploy-apis.sh $ENVIRONMENT"
echo ""

warning "Remember to:"
echo "  - Ensure you're logged in to Azure (az login)"
echo "  - Review and customize the API backend URLs as needed"

success "Environment setup completed! 🚀"