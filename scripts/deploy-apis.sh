#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: deploy-apis.sh
# Description: Enhanced API deployment script with environment variable support,
#              validation, parallel deployment, and comprehensive error handling.
# Usage: ./deploy-apis.sh <environment> [config-file] [--dry-run] [--parallel]
# Example: ./deploy-apis.sh dev ./api-config.json --parallel
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Source configuration utilities
source "$(dirname "${BASH_SOURCE[0]}")/lib/config-utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
START_TIME=$(date +%s)
DEPLOYED_APIS=()
FAILED_APIS=()
TEMP_FILES=()

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
    echo "Usage: $0 <environment> [config-file] [--dry-run] [--parallel] [--verbose]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment (dev, staging, prod) to load config from"
    echo "  config-file    API configuration file (JSON/YAML supported)"
    echo "                 Default: auto-discover api-config.yaml or api-config.json"
    echo "  --dry-run      Validate configuration without deploying"
    echo "  --parallel     Deploy APIs in parallel (faster but less detailed output)"
    echo "  --verbose      Show detailed deployment output and debugging information"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod ./my-apis.yaml --parallel"
    echo "  $0 staging --dry-run --verbose"
    exit 1
}

cleanup() {
    log "Cleaning up temporary files..."
    if [[ ${#TEMP_FILES[@]} -eq 0 ]]; then
        log "No temporary files to clean up"
    else
        log "Found ${#TEMP_FILES[@]} temporary files to clean up"
        for temp_file in "${TEMP_FILES[@]}"; do
            if [[ -f "$temp_file" ]]; then
                log "Removing temporary file: $temp_file"
                rm -f "$temp_file"
            else
                log "Temporary file already removed: $temp_file"
            fi
        done
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

substitute_env_vars() {
    local content="$1"
    # Replace ${VAR_NAME} with environment variable values
    while [[ $content =~ \$\{([^}]+)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${!var_name:-}"
        if [[ -z "$var_value" ]]; then
            warning "Environment variable '$var_name' is not set, leaving placeholder"
        else
            content="${content//\$\{$var_name\}/$var_value}"
        fi
    done
    echo "$content"
}

# ──────────────────────────────────────────────────────────────────────────────
# Argument Processing
# ──────────────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    error "Missing required environment argument"
    usage
fi

ENVIRONMENT="$1"
# Auto-discover config file (prefer YAML, fallback to JSON)
CONFIG_FILE=$(find_config_file "./environments/${ENVIRONMENT}/api-config" "api-config" 2>/dev/null || echo "./environments/${ENVIRONMENT}/api-config.json")
DRY_RUN=false
PARALLEL=false
VERBOSE=false
TEMPLATE_FILE="./bicep/apis/api-template.bicep"

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            if [[ "$1" != --* ]]; then
                CONFIG_FILE="$1"
            else
                error "Unknown option: $1"
                usage
            fi
            shift
            ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────────────
# Load Environment Configuration
# ──────────────────────────────────────────────────────────────────────────────

ENV_CONFIG_FILE="./environments/${ENVIRONMENT}/config.env"

if [[ ! -f "$ENV_CONFIG_FILE" ]]; then
    error "Environment configuration file not found: $ENV_CONFIG_FILE"
    echo "Available environments:"
    ls -1 ./environments/ 2>/dev/null || echo "No environments configured"
    exit 1
fi

log "Loading environment configuration: $ENVIRONMENT"
source "$ENV_CONFIG_FILE"

# Validate required variables from environment
REQUIRED_VARS=("RESOURCE_GROUP" "APIM_NAME")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        error "Required variable $var is not set in $ENV_CONFIG_FILE"
        exit 1
    fi
done

RG="$RESOURCE_GROUP"
APIM_NAME="$APIM_NAME"

# Detect if this is a V2 SKU (V2 SKUs don't support gateway associations)
IS_V2_SKU=false
if [[ -n "${SKU_NAME:-}" && "$SKU_NAME" =~ V2$ ]]; then
    IS_V2_SKU=true
    log "Detected V2 SKU ($SKU_NAME) - gateway associations will be skipped"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Validate Files and Dependencies
# ──────────────────────────────────────────────────────────────────────────────

log "Validating configuration and dependencies..."

# Check if API config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "API configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    error "Bicep template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Validate configuration syntax (JSON/YAML)
if ! validate_config_syntax "$CONFIG_FILE"; then
    config_format=$(detect_config_format "$CONFIG_FILE")
    format_display=$(get_config_format_display_name "$config_format")
    error "Invalid $format_display syntax in configuration file: $CONFIG_FILE"
    exit 1
fi

# Check configuration processing dependencies
if ! check_config_dependencies; then
    error "Missing required dependencies for configuration processing"
    exit 1
fi

# Check Azure CLI authentication
log "Checking Azure authentication..."
if ! az account show >/dev/null 2>&1; then
    error "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi

# Set subscription if specified
CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv)
if [[ -n "${SUBSCRIPTION_ID:-}" && "$CURRENT_SUBSCRIPTION" != "$SUBSCRIPTION_ID" ]]; then
    log "Switching subscription from $CURRENT_SUBSCRIPTION to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
else
    log "Using current subscription: $CURRENT_SUBSCRIPTION"
fi

# Verify APIM instance exists
log "Verifying APIM instance exists: $APIM_NAME"
if ! az apim show --name "$APIM_NAME" --resource-group "$RG" >/dev/null 2>&1; then
    error "APIM instance '$APIM_NAME' not found in resource group '$RG'"
    echo "Run './scripts/deploy-infrastructure.sh $ENVIRONMENT' first to create the APIM instance"
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Process Configuration and Prepare for Deployment
# ──────────────────────────────────────────────────────────────────────────────

# Read and substitute environment variables in configuration
CONFIG_CONTENT=$(get_config_content "$CONFIG_FILE")
CONFIG_FORMAT=$(detect_config_format "$CONFIG_FILE")
SUBSTITUTED_CONFIG=$(substitute_env_vars_in_config "$CONFIG_CONTENT" "$CONFIG_FORMAT")

# Validate API count  
case "$CONFIG_FORMAT" in
    "json")
        API_COUNT=$(echo "$SUBSTITUTED_CONFIG" | jq length)
        ;;
    "yaml")
        # Convert YAML to JSON for consistent processing, then get length
        API_COUNT=$(echo "$SUBSTITUTED_CONFIG" | jq length)
        ;;
    *)
        error "Unsupported configuration format: $CONFIG_FORMAT"
        exit 1
        ;;
esac
if [[ "$API_COUNT" -eq 0 ]]; then
    warning "No APIs found in configuration file"
    exit 0
fi

log "Found $API_COUNT APIs to deploy"

# ──────────────────────────────────────────────────────────────────────────────
# Dry Run Mode
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN MODE - No APIs will be deployed"
    echo ""
    echo "Configuration Summary:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Resource Group: $RG"
    echo "  APIM Instance: $APIM_NAME"
    echo "  APIs to deploy: $API_COUNT"
    echo ""
    
    echo "APIs configuration:"
    echo "$SUBSTITUTED_CONFIG" | jq -r '.[] | "  - \(.apiId): \(.displayName) (\(.path))"'
    echo ""
    
    # Validate each API configuration
    log "Validating API configurations..."
    while read -r api; do
        API_ID=$(echo "$api" | jq -r '.apiId')
        SPEC_PATH=$(echo "$api" | jq -r '.specPath')
        
        echo -n "  Validating $API_ID... "
        
        # Check if spec file exists
        if [[ ! -f "$SPEC_PATH" ]]; then
            echo -e "${RED}FAIL${NC} - Spec file not found: $SPEC_PATH"
            continue
        fi
        
        # Validate spec file is valid JSON/YAML
        if [[ "$SPEC_PATH" == *.json ]]; then
            if ! jq empty "$SPEC_PATH" 2>/dev/null; then
                echo -e "${RED}FAIL${NC} - Invalid JSON in spec file"
                continue
            fi
        fi
        
        echo -e "${GREEN}PASS${NC}"
    done < <(echo "$SUBSTITUTED_CONFIG" | jq -c '.[]')  # SUBSTITUTED_CONFIG is JSON format after processing
    
    success "Dry run validation completed"
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# API Deployment Function
# ──────────────────────────────────────────────────────────────────────────────

deploy_api() {
    local api="$1"
    local api_id=$(echo "$api" | jq -r '.apiId')
    local spec_path=$(echo "$api" | jq -r '.specPath')
    
    log "Deploying API: $api_id"
    
    # Validate spec file exists
    if [[ ! -f "$spec_path" ]]; then
        error "Spec file not found for API $api_id: $spec_path"
        FAILED_APIS+=("$api_id")
        return 1
    fi
    
    # Validate product associations if specified
    local product_ids=$(echo "$api" | jq -r '.productIds[]?' 2>/dev/null || echo "")
    if [[ -n "$product_ids" ]]; then
        for product_id in $product_ids; do
            if ! az apim product show --service-name "$APIM_NAME" --resource-group "$RG" --product-id "$product_id" >/dev/null 2>&1; then
                warning "Product '$product_id' does not exist in APIM instance '$APIM_NAME'. API association may fail."
            fi
        done
    fi
    
    # Validate gateway associations if specified
    local gateway_names=$(echo "$api" | jq -r '.gatewayNames[]?' 2>/dev/null || echo "")
    if [[ -n "$gateway_names" ]]; then
        for gateway_name in $gateway_names; do
            # Note: 'managed' is a special built-in gateway, others need to be validated
            if [[ "$gateway_name" != "managed" ]]; then
                if ! az apim gateway show --service-name "$APIM_NAME" --resource-group "$RG" --gateway-id "$gateway_name" >/dev/null 2>&1; then
                    warning "Gateway '$gateway_name' does not exist in APIM instance '$APIM_NAME'. API association may fail."
                fi
            fi
        done
    fi
    
    # Build dynamic parameter string
    local params="apimName=\"$APIM_NAME\" apiId=\"$api_id\""
    for key in $(echo "$api" | jq -r 'keys[]'); do
        if [[ "$key" == "specPath" || "$key" == "apiId" ]]; then continue; fi

        # Skip gatewayNames for V2 SKUs - override with empty array
        if [[ "$key" == "gatewayNames" && "$IS_V2_SKU" == "true" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                log "Overriding gatewayNames to empty array for V2 SKU"
            fi
            params="$params $key='[]'"
            continue
        fi

        local val=$(echo "$api" | jq -c --arg k "$key" '.[$k]')

        # Detect if value is a string literal
        if echo "$val" | jq -e 'type == "string"' > /dev/null; then
            val=$(echo "$val" | jq -r '.')
            # Apply environment variable substitution to string values
            val=$(substitute_env_vars "$val")
            params="$params $key=\"$val\""
        else
            params="$params $key='$val'"
        fi
    done

    # If gatewayNames wasn't in the config and this is V2, explicitly set to empty array
    if [[ "$IS_V2_SKU" == "true" ]] && ! echo "$api" | jq -e 'has("gatewayNames")' > /dev/null; then
        if [[ "$VERBOSE" == "true" ]]; then
            log "Adding empty gatewayNames array for V2 SKU (not specified in config)"
        fi
        params="$params gatewayNames='[]'"
    fi
    
    # Generate temporary Bicep file
    local temp_bicep="./temp-api-${api_id}-$$.bicep"
    TEMP_FILES+=("$temp_bicep")
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "Creating temporary Bicep file: $temp_bicep"
        log "Total temp files tracked: ${#TEMP_FILES[@]}"
    fi
    
    sed "s|__SPEC_PATH__|$spec_path|g" "$TEMPLATE_FILE" > "$temp_bicep"
    
    # Deploy the API
    local deployment_name="api-${api_id}-$(date +%Y%m%d-%H%M%S)"
    
    # Capture deployment output for better error reporting
    local deployment_output
    local deployment_exit_code
    
    # Temporarily disable exit-on-error to capture deployment failures
    set +e
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "Deployment command: az deployment group create --resource-group \"$RG\" --template-file \"$temp_bicep\" --name \"$deployment_name\" --parameters $params"
        deployment_output=$(eval az deployment group create \
            --resource-group "\"$RG\"" \
            --template-file "\"$temp_bicep\"" \
            --name "$deployment_name" \
            --parameters $params \
            --verbose 2>&1)
        deployment_exit_code=$?
    else
        deployment_output=$(eval az deployment group create \
            --resource-group "\"$RG\"" \
            --template-file "\"$temp_bicep\"" \
            --name "$deployment_name" \
            --parameters $params \
            --only-show-errors 2>&1)
        deployment_exit_code=$?
    fi
    
    # Re-enable exit-on-error
    set -e
    
    if [[ $deployment_exit_code -eq 0 ]]; then
        success "API deployed: $api_id"
        if [[ "$VERBOSE" == "true" && -n "$deployment_output" ]]; then
            echo "Deployment details:" >&2
            echo "$deployment_output" >&2
            echo "" >&2
        fi
        DEPLOYED_APIS+=("$api_id")
        return 0
    else
        error "Failed to deploy API: $api_id"
        if [[ -n "$deployment_output" ]]; then
            echo "Deployment error details:" >&2
            echo "$deployment_output" >&2
            echo "" >&2
        fi
        FAILED_APIS+=("$api_id")
        return 1
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Deploy APIs
# ──────────────────────────────────────────────────────────────────────────────

log "Starting API deployment in environment: $ENVIRONMENT"

if [[ "$PARALLEL" == "true" ]]; then
    log "Deploying APIs in parallel..."
    
    # Deploy APIs in parallel using background jobs
    while read -r api; do
        deploy_api "$api" &
    done < <(echo "$SUBSTITUTED_CONFIG" | jq -c '.[]')  # SUBSTITUTED_CONFIG is JSON format after processing
    
    # Wait for all background jobs to complete
    wait
    
else
    log "Deploying APIs sequentially..."
    
    # Deploy APIs sequentially using process substitution to avoid subshell
    while read -r api; do
        deploy_api "$api"
    done < <(echo "$SUBSTITUTED_CONFIG" | jq -c '.[]')  # SUBSTITUTED_CONFIG is JSON format after processing
fi

# ──────────────────────────────────────────────────────────────────────────────
# Deployment Summary
# ──────────────────────────────────────────────────────────────────────────────

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "📋 Deployment Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Total APIs: $API_COUNT"
echo "  Deployed: ${#DEPLOYED_APIS[@]}"
echo "  Failed: ${#FAILED_APIS[@]}"
echo "  Duration: ${DURATION}s"

if [[ ${#DEPLOYED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "✅ Successfully deployed APIs:"
    printf '  - %s\n' "${DEPLOYED_APIS[@]}"
fi

if [[ ${#FAILED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Failed API deployments:"
    printf '  - %s\n' "${FAILED_APIS[@]}"
    echo ""
    error "Some API deployments failed"
    exit 1
fi

success "All APIs deployed successfully in ${DURATION}s"