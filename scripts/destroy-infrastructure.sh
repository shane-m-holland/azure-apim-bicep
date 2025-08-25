#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: destroy-infrastructure.sh
# Description: Safely destroy Azure API Management infrastructure with confirmation
#              prompts and backup options. Handles API cleanup before infrastructure
#              removal.
# Usage: ./destroy-infrastructure.sh <environment> [--force] [--keep-rg]
# Example: ./destroy-infrastructure.sh dev --force
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
    echo "Usage: $0 <environment> [--force] [--keep-rg] [--purge] [--delete-shared]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to destroy (dev, staging, prod)"
    echo ""
    echo "Options:"
    echo "  --force         Skip confirmation prompts"
    echo "  --keep-rg       Keep the resource group after destroying APIM"
    echo "  --purge         Force hard delete and purge soft-deleted APIM instances"
    echo "  --delete-shared Override protection and delete shared resources (dangerous)"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --force --keep-rg"
    echo "  $0 dev --purge          # Hard delete with immediate name reuse"
    echo "  $0 dev --delete-shared  # Delete shared network resources (dangerous)"
    exit 1
}

confirm_action() {
    local message="$1"
    if [[ "$FORCE" == "true" ]]; then
        warning "Force mode enabled - skipping confirmation"
        return 0
    fi
    
    echo -e "${YELLOW}$message${NC}"
    read -p "Type 'yes' to continue: " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Operation cancelled by user"
        exit 1
    fi
}

purge_soft_deleted_apim() {
    local apim_name="$1"
    local location="$2"
    
    log "Checking for existing soft-deleted APIM instances..."
    
    # Check if the specific APIM instance is soft-deleted
    if az apim deletedservice show --service-name "$apim_name" --location "$location" >/dev/null 2>&1; then
        warning "Found soft-deleted APIM instance: $apim_name in $location"
        
        if [[ "$PURGE" == "true" ]]; then
            warning "⚠️  PURGE MODE: This will PERMANENTLY delete the soft-deleted instance!"
            warning "The instance CANNOT be recovered after purging."
            
            confirm_action "Do you want to permanently purge the soft-deleted APIM instance '$apim_name'?"
            
            log "Purging soft-deleted APIM instance: $apim_name"
            if az apim deletedservice purge --service-name "$apim_name" --location "$location" --no-wait; then
                success "Soft-deleted APIM instance purge initiated"
                
                # Wait for purge to complete
                log "Waiting for purge to complete..."
                while az apim deletedservice show --service-name "$apim_name" --location "$location" >/dev/null 2>&1; do
                    echo -n "."
                    sleep 10
                done
                echo ""
                success "Soft-deleted APIM instance purged successfully"
            else
                error "Failed to purge soft-deleted APIM instance"
                return 1
            fi
        else
            error "Soft-deleted APIM instance '$apim_name' exists!"
            error "This will prevent redeployment with the same name."
            error "Options:"
            error "  1. Wait 48 hours for automatic purge"
            error "  2. Use --purge flag to force permanent deletion"
            error "  3. Choose a different APIM instance name"
            exit 1
        fi
    else
        log "No soft-deleted APIM instance found for: $apim_name"
    fi
}

check_resource_ownership() {
    local config_file="$1"
    
    log "Analyzing resource ownership from configuration..."
    
    # Load network reuse configuration
    USE_EXISTING_NSG="${USE_EXISTING_NSG:-false}"
    USE_EXISTING_VNET="${USE_EXISTING_VNET:-false}"
    USE_EXISTING_SUBNET="${USE_EXISTING_SUBNET:-false}"
    
    # Determine resource ownership
    OWNS_NSG=true
    OWNS_VNET=true
    OWNS_SUBNET=true
    SHARED_RESOURCES=()
    
    if [[ "$USE_EXISTING_NSG" == "true" ]]; then
        OWNS_NSG=false
        SHARED_RESOURCES+=("NSG: ${NSG_NAME:-<not_set>}")
    fi
    
    if [[ "$USE_EXISTING_VNET" == "true" ]]; then
        OWNS_VNET=false
        SHARED_RESOURCES+=("VNet: ${VNET_NAME:-<not_set>}")
    fi
    
    if [[ "$USE_EXISTING_SUBNET" == "true" ]]; then
        OWNS_SUBNET=false
        SHARED_RESOURCES+=("Subnet: ${SUBNET_NAME:-<not_set>}")
    fi
    
    # Report findings
    if [[ ${#SHARED_RESOURCES[@]} -gt 0 ]]; then
        warning "⚠️  SHARED INFRASTRUCTURE DETECTED"
        echo ""
        echo "This deployment uses existing network resources that should be preserved:"
        for resource in "${SHARED_RESOURCES[@]}"; do
            echo "  🔒 $resource (shared - will be preserved)"
        done
        echo ""
        echo "Only the APIM instance and owned resources will be deleted."
        echo ""
        return 0  # Shared resources found
    else
        log "✓ No shared network resources detected - safe to delete entire resource group"
        return 1  # No shared resources
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Argument Processing
# ──────────────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    error "Missing required environment argument"
    usage
fi

ENVIRONMENT="$1"
FORCE=false
KEEP_RG=false
PURGE=false
DELETE_SHARED=false

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --keep-rg)
            KEEP_RG=true
            shift
            ;;
        --purge)
            PURGE=true
            shift
            ;;
        --delete-shared)
            DELETE_SHARED=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────────────
# Configuration Loading
# ──────────────────────────────────────────────────────────────────────────────

CONFIG_FILE="./environments/${ENVIRONMENT}/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
    echo "Available environments:"
    ls -1 ./environments/ 2>/dev/null || echo "No environments configured"
    exit 1
fi

log "Loading environment configuration: $ENVIRONMENT"
source "$CONFIG_FILE"

# Validate required variables
if [[ -z "${RESOURCE_GROUP:-}" || -z "${APIM_NAME:-}" ]]; then
    error "Required variables RESOURCE_GROUP and APIM_NAME must be set in $CONFIG_FILE"
    exit 1
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
# Handle Soft-deleted APIM Instances
# ──────────────────────────────────────────────────────────────────────────────

# Check and handle any existing soft-deleted APIM instances
purge_soft_deleted_apim "$APIM_NAME" "$LOCATION"

# ──────────────────────────────────────────────────────────────────────────────
# Resource Ownership Analysis
# ──────────────────────────────────────────────────────────────────────────────

# Check what resources this deployment owns vs. shares
if check_resource_ownership "$CONFIG_FILE"; then
    HAS_SHARED_RESOURCES=true
    
    if [[ "$DELETE_SHARED" == "true" ]]; then
        warning "🚨 OVERRIDE: --delete-shared flag specified"
        warning "This will delete shared network resources that may be used by other deployments!"
        warning "This could cause outages for other services using these resources!"
        HAS_SHARED_RESOURCES=false  # Override protection
    fi
else
    HAS_SHARED_RESOURCES=false
fi

# ──────────────────────────────────────────────────────────────────────────────
# Pre-destruction Checks
# ──────────────────────────────────────────────────────────────────────────────

log "Checking if resource group exists: $RESOURCE_GROUP"
if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    warning "Resource group '$RESOURCE_GROUP' does not exist"
    exit 0
fi

log "Checking if APIM instance exists: $APIM_NAME"
if ! az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    warning "APIM instance '$APIM_NAME' does not exist in resource group '$RESOURCE_GROUP'"
    if [[ "$KEEP_RG" == "false" ]]; then
        confirm_action "Do you want to delete the resource group anyway?"
        log "Deleting resource group: $RESOURCE_GROUP"
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        success "Resource group deletion initiated"
    fi
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Show Current State
# ──────────────────────────────────────────────────────────────────────────────

log "Current infrastructure state:"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "APIM Instance: $APIM_NAME"

# List APIs in APIM
API_COUNT=$(az apim api list --service-name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query 'length(@)' -o tsv 2>/dev/null || echo "0")
echo "APIs deployed: $API_COUNT"

if [[ "$API_COUNT" -gt 0 ]]; then
    echo ""
    echo "Deployed APIs:"
    az apim api list --service-name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query '[].{Name:displayName, Path:path, ID:name}' -o table 2>/dev/null || echo "Could not list APIs"
fi

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Confirmation and Cleanup
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$API_COUNT" -gt 0 ]]; then
    confirm_action "⚠️  This APIM instance has $API_COUNT APIs deployed. All APIs will be deleted along with the infrastructure. Continue?"
fi

if [[ "$HAS_SHARED_RESOURCES" == "true" ]]; then
    confirm_action "🔒 SHARED INFRASTRUCTURE: Only the APIM instance will be deleted. Shared network resources will be preserved. Continue?"
else
    if [[ "$DELETE_SHARED" == "true" ]]; then
        confirm_action "🚨 DANGER: This will delete shared network resources that may affect other deployments! This action cannot be undone. Continue?"
    else
        confirm_action "🚨 WARNING: This will permanently delete the APIM infrastructure in environment '$ENVIRONMENT'. This action cannot be undone. Continue?"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# API Cleanup (Optional)
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$API_COUNT" -gt 0 ]]; then
    log "Cleaning up APIs before infrastructure deletion..."
    
    # Check if api-config.json exists and use delete-apis.sh
    if [[ -f "./environments/${ENVIRONMENT}/api-config.json" && -f "./scripts/delete-apis.sh" ]]; then
        log "Using delete-apis.sh to clean up APIs..."
        ./scripts/delete-apis.sh "$RESOURCE_GROUP" "$APIM_NAME" || warning "API cleanup script failed, continuing with infrastructure deletion"
    else
        warning "API config or delete script not found, APIs will be deleted with infrastructure"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Infrastructure Destruction
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$HAS_SHARED_RESOURCES" == "true" ]] || [[ "$KEEP_RG" == "true" ]] || [[ "$PURGE" == "true" ]]; then
    # Use selective deletion for shared resources, --keep-rg, or --purge modes
    log "Deleting APIM instance only: $APIM_NAME"
    
    if [[ "$HAS_SHARED_RESOURCES" == "true" ]]; then
        log "Preserving shared network resources"
    elif [[ "$PURGE" == "true" ]]; then
        warning "Using hard delete to prevent soft-delete behavior"
    fi
    
    az apim delete --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --yes --no-wait
    
    if [[ "$HAS_SHARED_RESOURCES" == "true" ]]; then
        success "APIM deletion initiated (preserving shared network resources)"
    else
        success "APIM deletion initiated (keeping resource group)"
    fi
    
    log "Monitoring deletion progress..."
    while az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; do
        echo -n "."
        sleep 30
    done
    echo ""
    success "APIM instance deleted successfully"
    
    # If we have shared resources but aren't keeping the RG, clean up owned resources
    if [[ "$HAS_SHARED_RESOURCES" == "true" && "$KEEP_RG" == "false" ]]; then
        log "Cleaning up owned network resources..."
        
        # Delete created subnet if we created it in existing VNet
        if [[ "$OWNS_SUBNET" == "true" && "$USE_EXISTING_VNET" == "true" ]]; then
            log "Deleting created subnet: $SUBNET_NAME"
            az network vnet subnet delete --name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" || warning "Failed to delete subnet"
        fi
        
        # Delete created VNet if we own it
        if [[ "$OWNS_VNET" == "true" ]]; then
            log "Deleting created VNet: $VNET_NAME"
            az network vnet delete --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" || warning "Failed to delete VNet"
        fi
        
        # Delete created NSG if we own it
        if [[ "$OWNS_NSG" == "true" ]]; then
            log "Deleting created NSG: $NSG_NAME"
            az network nsg delete --name "$NSG_NAME" --resource-group "$RESOURCE_GROUP" || warning "Failed to delete NSG"
        fi
    fi
    
else
    # Full resource group deletion (traditional behavior)
    log "Deleting entire resource group: $RESOURCE_GROUP"
    az group delete --name "$RESOURCE_GROUP" --yes --no-wait
    success "Resource group deletion initiated"
    
    log "Monitoring deletion progress..."
    while az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; do
        echo -n "."
        sleep 30
    done
    echo ""
    success "Resource group deleted successfully"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup Generated Files
# ──────────────────────────────────────────────────────────────────────────────

PARAMS_FILE="./environments/${ENVIRONMENT}/parameters.json"
if [[ -f "$PARAMS_FILE" ]]; then
    log "Cleaning up generated parameters file: $PARAMS_FILE"
    rm -f "$PARAMS_FILE"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "🗑️  Infrastructure destruction completed for environment: $ENVIRONMENT"
echo ""

if [[ "$HAS_SHARED_RESOURCES" == "true" ]]; then
    echo "✅ Shared Infrastructure Mode:"
    echo "   - APIM instance '$APIM_NAME' has been deleted"
    echo "   - Shared network resources were preserved:"
    for resource in "${SHARED_RESOURCES[@]}"; do
        echo "     🔒 $resource"
    done
    if [[ "$KEEP_RG" == "false" ]]; then
        echo "   - Owned network resources were cleaned up"
    fi
elif [[ "$KEEP_RG" == "true" ]] || [[ "$PURGE" == "true" ]]; then
    echo "Note: Resource group '$RESOURCE_GROUP' was preserved"
    if [[ "$PURGE" == "true" ]]; then
        echo "      Hard delete was used to prevent soft-delete behavior"
    fi
else
    echo "Note: All resources in '$RESOURCE_GROUP' have been deleted"
    echo "      APIM instance may be soft-deleted (use --purge to avoid this)"
fi

log "Destruction completed successfully"