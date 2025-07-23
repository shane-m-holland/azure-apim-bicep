#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: sync-apis.sh
# Description: Intelligent API synchronization that only deploys changed APIs
#              by comparing local configuration with deployed state in APIM.
# Usage: ./sync-apis.sh <environment> [config-file] [--force-all]
# Example: ./sync-apis.sh dev ./api-config.json
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
START_TIME=$(date +%s)
DEPLOYED_APIS=()
FAILED_APIS=()
UNCHANGED_APIS=()
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

info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${CYAN}🐛 DEBUG:${NC} $1" >&2
    fi
}

usage() {
    echo "Usage: $0 <environment> [config-file] [--force-all] [--debug]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment (dev, staging, prod) to load config from"
    echo "  config-file    API configuration file (default: ./api-config.json)"
    echo "  --force-all    Deploy all APIs regardless of changes"
    echo "  --debug        Enable debug mode with verbose Azure CLI output"
    echo ""
    echo "Examples:"
    echo "  $0 dev                          # Sync APIs for dev environment"
    echo "  $0 prod ./my-apis.json          # Sync with custom config"
    echo "  $0 staging --force-all          # Force deploy all APIs"
    echo "  $0 dev --debug                  # Debug mode with detailed output"
    exit 1
}

cleanup() {
    log "Cleaning up temporary files..."
    for temp_file in "${TEMP_FILES[@]}"; do
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
}

trap cleanup EXIT

substitute_env_vars() {
    local content="$1"
    while [[ $content =~ \\$\\{([^}]+)\\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${!var_name:-}"
        if [[ -z "$var_value" ]]; then
            warning "Environment variable '$var_name' is not set, leaving placeholder"
        else
            content="${content//\\$\\{$var_name\\}/$var_value}"
        fi
    done
    echo "$content"
}

get_deployed_apis() {
    local rg="$1"
    local apim_name="$2"
    
    log "Retrieving currently deployed APIs..." >&2
    debug "Azure CLI command: az apim api list --resource-group \"$rg\" --service-name \"$apim_name\""
    
    # Capture both stdout and stderr
    local output
    local error_output
    local exit_code
    
    if [[ "$DEBUG" == "true" ]]; then
        # In debug mode, show all output
        output=$(az apim api list \
            --resource-group "$rg" \
            --service-name "$apim_name" \
            --query '[].{name:name, displayName:displayName, path:path, serviceUrl:serviceUrl}' \
            -o json 2>&1)
        exit_code=$?
    else
        # Capture stderr separately for better error reporting
        exec 3>&1 4>&2
        error_output=$(az apim api list \
            --resource-group "$rg" \
            --service-name "$apim_name" \
            --query '[].{name:name, displayName:displayName, path:path, serviceUrl:serviceUrl}' \
            -o json 2>&1 1>&3)
        exit_code=$?
        output=$(az apim api list \
            --resource-group "$rg" \
            --service-name "$apim_name" \
            --query '[].{name:name, displayName:displayName, path:path, serviceUrl:serviceUrl}' \
            -o json 2>/dev/null)
        exec 3>&- 4>&-
    fi
    
    debug "Azure CLI exit code: $exit_code"
    debug "Raw output length: ${#output} characters"
    debug "Raw output (first 200 chars): ${output:0:200}"
    
    if [[ $exit_code -ne 0 ]]; then
        error "Azure CLI command failed with exit code $exit_code"
        if [[ -n "$error_output" ]]; then
            error "Azure CLI error: $error_output"
        fi
        if [[ -n "$output" ]]; then
            error "Azure CLI output: $output"
        fi
        echo "[]"
        return 1
    fi
    
    # Check if output is empty
    if [[ -z "$output" ]]; then
        warning "Azure CLI returned empty output"
        echo "[]"
        return 0
    fi
    
    # Validate the output is valid JSON
    if echo "$output" | jq empty 2>/dev/null; then
        debug "JSON validation passed"
        echo "$output"
    else
        error "Azure CLI returned invalid JSON"
        error "Raw output: $output"
        # Try to show what jq thinks is wrong
        local jq_error
        jq_error=$(echo "$output" | jq empty 2>&1 || true)
        error "jq validation error: $jq_error"
        echo "[]"
        return 1
    fi
}

get_api_revision() {
    local rg="$1"
    local apim_name="$2"
    local api_id="$3"
    
    # Get API revision (which changes when API is updated)
    az apim api show \
        --resource-group "$rg" \
        --service-name "$apim_name" \
        --api-id "$api_id" \
        --query 'apiRevision' \
        -o tsv 2>/dev/null || echo "0"
}

calculate_api_hash() {
    local api="$1"
    local spec_path="$2"
    
    # Create a hash based on API configuration and spec content
    local config_hash=$(echo "$api" | jq -S . | md5sum | cut -d' ' -f1)
    local spec_hash=""
    
    if [[ -f "$spec_path" ]]; then
        spec_hash=$(md5sum "$spec_path" | cut -d' ' -f1)
    fi
    
    echo "${config_hash}-${spec_hash}"
}

api_needs_update() {
    local rg="$1"
    local apim_name="$2"
    local api="$3"
    local force_all="$4"
    
    local api_id=$(echo "$api" | jq -r '.apiId')
    local spec_path=$(echo "$api" | jq -r '.specPath')
    
    # If force_all is true, always update
    if [[ "$force_all" == "true" ]]; then
        return 0
    fi
    
    # Check if API exists
    if ! az apim api show --resource-group "$rg" --service-name "$apim_name" --api-id "$api_id" >/dev/null 2>&1; then
        log "API '$api_id' does not exist - needs deployment"
        return 0
    fi
    
    # Get deployed API properties
    local deployed_api
    deployed_api=$(az apim api show \
        --resource-group "$rg" \
        --service-name "$apim_name" \
        --api-id "$api_id" \
        --query '{displayName:displayName, path:path, serviceUrl:serviceUrl}' \
        -o json 2>/dev/null)
    
    # Validate the response is valid JSON
    if ! echo "$deployed_api" | jq empty 2>/dev/null; then
        log "API '$api_id' properties could not be retrieved - needs deployment"
        return 0
    fi
    
    # Compare key properties
    local local_display_name=$(echo "$api" | jq -r '.displayName')
    local local_path=$(echo "$api" | jq -r '.path')
    local local_service_url=$(echo "$api" | jq -r '.serviceUrl // empty')
    local_service_url=$(substitute_env_vars "$local_service_url")
    
    local deployed_display_name=$(echo "$deployed_api" | jq -r '.displayName // empty')
    local deployed_path=$(echo "$deployed_api" | jq -r '.path // empty')
    local deployed_service_url=$(echo "$deployed_api" | jq -r '.serviceUrl // empty')
    
    # Check for differences
    if [[ "$local_display_name" != "$deployed_display_name" ]]; then
        log "API '$api_id' display name changed: '$deployed_display_name' → '$local_display_name'"
        return 0
    fi
    
    if [[ "$local_path" != "$deployed_path" ]]; then
        log "API '$api_id' path changed: '$deployed_path' → '$local_path'"
        return 0
    fi
    
    if [[ "$local_service_url" != "$deployed_service_url" ]]; then
        log "API '$api_id' service URL changed: '$deployed_service_url' → '$local_service_url'"
        return 0
    fi
    
    # Check if spec file has been modified (simple timestamp check)
    if [[ -f "$spec_path" ]]; then
        local spec_modified=$(stat -c %Y "$spec_path" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local hours_since_modified=$(( (current_time - spec_modified) / 3600 ))
        
        # If spec was modified in the last 24 hours, consider it changed
        if [[ $hours_since_modified -lt 24 ]]; then
            log "API '$api_id' spec file recently modified (${hours_since_modified}h ago)"
            return 0
        fi
    fi
    
    log "API '$api_id' appears unchanged - skipping"
    return 1
}

deploy_api() {
    local api="$1"
    local rg="$2"
    local apim_name="$3"
    local template_file="$4"
    
    local api_id=$(echo "$api" | jq -r '.apiId')
    local spec_path=$(echo "$api" | jq -r '.specPath')
    
    log "Deploying API: $api_id"
    
    # Validate spec file exists
    if [[ ! -f "$spec_path" ]]; then
        error "Spec file not found for API $api_id: $spec_path"
        FAILED_APIS+=("$api_id")
        return 1
    fi
    
    # Build dynamic parameter string
    local params="apimName=\"$apim_name\" apiId=\"$api_id\""
    for key in $(echo "$api" | jq -r 'keys[]'); do
        if [[ "$key" == "specPath" || "$key" == "apiId" ]]; then continue; fi
        local val=$(echo "$api" | jq -c --arg k "$key" '.[$k]')
        
        if echo "$val" | jq -e 'type == "string"' > /dev/null; then
            val=$(echo "$val" | jq -r '.')
            val=$(substitute_env_vars "$val")
            params="$params $key=\"$val\""
        else
            params="$params $key='$val'"
        fi
    done
    
    # Generate temporary Bicep file
    local temp_bicep="./temp-sync-${api_id}-$$.bicep"
    TEMP_FILES+=("$temp_bicep")
    
    sed "s|__SPEC_PATH__|$spec_path|g" "$template_file" > "$temp_bicep"
    
    # Deploy the API
    local deployment_name="sync-${api_id}-$(date +%Y%m%d-%H%M%S)"
    
    # Temporarily disable exit-on-error to capture deployment failures
    set +e
    
    local deployment_output
    deployment_output=$(eval az deployment group create \
        --resource-group "\"$rg\"" \
        --template-file "\"$temp_bicep\"" \
        --name "$deployment_name" \
        --parameters $params \
        --only-show-errors 2>&1)
    local deployment_exit_code=$?
    
    # Re-enable exit-on-error
    set -e
    
    if [[ $deployment_exit_code -eq 0 ]]; then
        success "API deployed: $api_id"
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
# Argument Processing
# ──────────────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    error "Missing required environment argument"
    usage
fi

ENVIRONMENT="$1"
CONFIG_FILE="./environments/${ENVIRONMENT}/api-config.json"
FORCE_ALL=false
DEBUG=false
TEMPLATE_FILE="./bicep/apis/api-template.bicep"

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --force-all)
            FORCE_ALL=true
            shift
            ;;
        --debug)
            DEBUG=true
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

RG="$RESOURCE_GROUP"
APIM_NAME="$APIM_NAME"

# ──────────────────────────────────────────────────────────────────────────────
# Validation
# ──────────────────────────────────────────────────────────────────────────────

log "Validating configuration and dependencies..."

# Check required files
for file in "$CONFIG_FILE" "$TEMPLATE_FILE"; do
    if [[ ! -f "$file" ]]; then
        error "Required file not found: $file"
        exit 1
    fi
done

# Validate JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    error "Invalid JSON in configuration file: $CONFIG_FILE"
    exit 1
fi

# Check Azure authentication
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
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Process Configuration
# ──────────────────────────────────────────────────────────────────────────────

CONFIG_CONTENT=$(cat "$CONFIG_FILE")
SUBSTITUTED_CONFIG=$(substitute_env_vars "$CONFIG_CONTENT")

API_COUNT=$(echo "$SUBSTITUTED_CONFIG" | jq length)
if [[ "$API_COUNT" -eq 0 ]]; then
    warning "No APIs found in configuration file"
    exit 0
fi

log "Found $API_COUNT APIs in configuration"

if [[ "$FORCE_ALL" == "true" ]]; then
    warning "Force mode enabled - all APIs will be deployed"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Analyze Changes and Deploy
# ──────────────────────────────────────────────────────────────────────────────

log "Starting intelligent API synchronization for environment: $ENVIRONMENT"

# Get currently deployed APIs for reference
DEPLOYED_API_LIST=$(get_deployed_apis "$RG" "$APIM_NAME")
debug "Deployed API list: $DEPLOYED_API_LIST"

# Safely calculate deployed API count
if [[ -n "$DEPLOYED_API_LIST" ]] && echo "$DEPLOYED_API_LIST" | jq empty 2>/dev/null; then
    DEPLOYED_COUNT=$(echo "$DEPLOYED_API_LIST" | jq length)
    log "Found $DEPLOYED_COUNT APIs currently deployed"
else
    error "Failed to retrieve or parse deployed APIs list"
    if [[ "$DEBUG" == "true" ]]; then
        debug "Raw DEPLOYED_API_LIST: $DEPLOYED_API_LIST"
    fi
    DEPLOYED_COUNT=0
    log "Assuming 0 APIs currently deployed due to retrieval failure"
fi

# Process each API in configuration using process substitution to avoid subshell
while read -r api; do
    api_id=$(echo "$api" | jq -r '.apiId')
    
    if api_needs_update "$RG" "$APIM_NAME" "$api" "$FORCE_ALL"; then
        deploy_api "$api" "$RG" "$APIM_NAME" "$TEMPLATE_FILE"
    else
        UNCHANGED_APIS+=("$api_id")
    fi
done < <(echo "$SUBSTITUTED_CONFIG" | jq -c '.[]')

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "📊 Synchronization Summary:"
echo "═══════════════════════════════════════════"
echo "  Environment: $ENVIRONMENT"
echo "  Total APIs in config: $API_COUNT"
echo "  Deployed/Updated: ${#DEPLOYED_APIS[@]}"
echo "  Unchanged: ${#UNCHANGED_APIS[@]}"
echo "  Failed: ${#FAILED_APIS[@]}"
echo "  Duration: ${DURATION}s"

if [[ ${#DEPLOYED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "✅ Deployed/Updated APIs:"
    printf '  - %s\n' "${DEPLOYED_APIS[@]}"
fi

if [[ ${#UNCHANGED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "😴 Unchanged APIs (skipped):"
    printf '  - %s\n' "${UNCHANGED_APIS[@]}"
fi

if [[ ${#FAILED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Failed API deployments:"
    printf '  - %s\n' "${FAILED_APIS[@]}"
    echo ""
    error "Some API deployments failed"
    exit 1
fi

if [[ ${#DEPLOYED_APIS[@]} -eq 0 ]]; then
    success "All APIs are up to date! No changes needed. ✨"
else
    success "API synchronization completed successfully in ${DURATION}s"
fi

log "Synchronization completed for environment: $ENVIRONMENT"