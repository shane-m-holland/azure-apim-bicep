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
    echo "Usage: $0 <environment> [--force] [--keep-rg] [--purge]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to destroy (dev, staging, prod)"
    echo ""
    echo "Options:"
    echo "  --force       Skip confirmation prompts"
    echo "  --keep-rg     Keep the resource group after destroying APIM"
    echo "  --purge       Force hard delete and purge soft-deleted APIM instances"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --force --keep-rg"
    echo "  $0 dev --purge          # Hard delete with immediate name reuse"
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

confirm_action "🚨 WARNING: This will permanently delete the APIM infrastructure in environment '$ENVIRONMENT'. This action cannot be undone. Continue?"

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

if [[ "$KEEP_RG" == "true" ]] || [[ "$PURGE" == "true" ]]; then
    # Use direct APIM deletion for --keep-rg or --purge (avoids soft-delete)
    log "Deleting APIM instance: $APIM_NAME"
    if [[ "$PURGE" == "true" ]]; then
        warning "Using hard delete to prevent soft-delete behavior"
    fi
    az apim delete --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --yes --no-wait
    success "APIM deletion initiated (keeping resource group)"
    
    log "Monitoring deletion progress..."
    while az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; do
        echo -n "."
        sleep 30
    done
    echo ""
    success "APIM instance deleted successfully"
    
else
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
if [[ "$KEEP_RG" == "true" ]] || [[ "$PURGE" == "true" ]]; then
    echo "Note: Resource group '$RESOURCE_GROUP' was preserved"
    if [[ "$PURGE" == "true" ]]; then
        echo "      Hard delete was used to prevent soft-delete behavior"
    fi
else
    echo "Note: All resources in '$RESOURCE_GROUP' have been deleted"
    echo "      APIM instance may be soft-deleted (use --purge to avoid this)"
fi

log "Destruction completed successfully"