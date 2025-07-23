#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: destroy-apis.sh
# Description: Delete APIs from Azure API Management instance using environment-based
#              configuration. Provides safety checks, confirmation prompts, and
#              comprehensive error handling.
# Usage: ./destroy-apis.sh <environment> [config-file] [--dry-run] [--force] [--verbose]
# Example: ./destroy-apis.sh dev --dry-run
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
START_TIME=$(date +%s)
DELETED_APIS=()
FAILED_APIS=()
SKIPPED_APIS=()

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

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔍 VERBOSE:${NC} $1" >&2
    fi
}

usage() {
    echo "Usage: $0 <environment> [config-file] [--dry-run] [--force] [--verbose]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to load config from (dev, staging, prod)"
    echo "  config-file    API configuration file (default: ./environments/\$ENV/api-config.json)"
    echo ""
    echo "Options:"
    echo "  --dry-run      Show what would be deleted without actually deleting"
    echo "  --force        Skip confirmation prompts"
    echo "  --verbose      Show detailed output and progress"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Delete APIs in dev environment"
    echo "  $0 prod --dry-run         # Preview what would be deleted in prod"
    echo "  $0 staging --force        # Delete APIs without confirmation"
    echo "  $0 dev --verbose          # Show detailed deletion progress"
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

check_api_exists() {
    local rg="$1"
    local apim_name="$2"
    local api_id="$3"
    
    verbose "Checking if API $api_id exists..."
    
    if az apim api show --resource-group "$rg" --service-name "$apim_name" --api-id "$api_id" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

delete_api() {
    local rg="$1"
    local apim_name="$2"
    local api="$3"
    
    local api_id=$(echo "$api" | jq -r '.apiId')
    local display_name=$(echo "$api" | jq -r '.displayName // .apiId')
    
    verbose "Processing API: $api_id ($display_name)"
    
    # Check if API exists
    if ! check_api_exists "$rg" "$apim_name" "$api_id"; then
        warning "API '$api_id' does not exist - skipping"
        SKIPPED_APIS+=("$api_id")
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would delete API: $api_id ($display_name)"
        return 0
    fi
    
    log "Deleting API: $api_id ($display_name)"
    
    # Temporarily disable exit-on-error to capture deletion failures
    set +e
    
    local delete_output
    delete_output=$(az apim api delete \
        --resource-group "$rg" \
        --service-name "$apim_name" \
        --api-id "$api_id" \
        --yes 2>&1)
    local delete_exit_code=$?
    
    # Re-enable exit-on-error
    set -e
    
    if [[ $delete_exit_code -eq 0 ]]; then
        success "API deleted: $api_id"
        DELETED_APIS+=("$api_id")
        return 0
    else
        error "Failed to delete API: $api_id"
        if [[ -n "$delete_output" ]]; then
            error "Deletion error details: $delete_output"
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
DRY_RUN=false
FORCE=false
VERBOSE=false

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
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

# Validate required variables
REQUIRED_VARS=("RESOURCE_GROUP" "APIM_NAME")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        error "Required variable $var is not set in $ENV_CONFIG_FILE"
        exit 1
    fi
done

RG="$RESOURCE_GROUP"
APIM_NAME="$APIM_NAME"

# ──────────────────────────────────────────────────────────────────────────────
# Validation
# ──────────────────────────────────────────────────────────────────────────────

log "Validating configuration and dependencies..."

# Check if API config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "API configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Validate JSON syntax
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    error "Invalid JSON in configuration file: $CONFIG_FILE"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    error "jq is required but not installed. Please install jq first."
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

# ──────────────────────────────────────────────────────────────────────────────
# Show Summary and Confirmation
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "📋 API Deletion Summary:"
echo "═══════════════════════════════════════════"
echo "  Environment: $ENVIRONMENT"
echo "  Resource Group: $RG"
echo "  APIM Instance: $APIM_NAME"
echo "  APIs to process: $API_COUNT"
echo "  Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "DELETE")"
echo ""

# Show API list
echo "APIs to be processed:"
while read -r api; do
    api_id=$(echo "$api" | jq -r '.apiId')
    display_name=$(echo "$api" | jq -r '.displayName // .apiId')
    path=$(echo "$api" | jq -r '.path // "N/A"')
    
    if check_api_exists "$RG" "$APIM_NAME" "$api_id"; then
        echo "  ✅ $api_id ($display_name) - Path: /$path"
    else
        echo "  ❌ $api_id ($display_name) - NOT FOUND"
    fi
done < <(echo "$SUBSTITUTED_CONFIG" | jq -c '.[]')

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Confirmation
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN MODE - No APIs will be deleted"
else
    confirm_action "⚠️  WARNING: This will permanently delete the APIs listed above from '$APIM_NAME'. This action cannot be undone. Continue?"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Delete APIs
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
    log "Starting API deletion preview for environment: $ENVIRONMENT"
else
    log "Starting API deletion for environment: $ENVIRONMENT"
fi

# Process each API using process substitution to avoid subshell issues
while read -r api; do
    delete_api "$RG" "$APIM_NAME" "$api"
done < <(echo "$SUBSTITUTED_CONFIG" | jq -c '.[]')

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "📊 Deletion Summary:"
echo "═══════════════════════════════════════════"
echo "  Environment: $ENVIRONMENT"
echo "  Total APIs processed: $API_COUNT"
echo "  Deleted: ${#DELETED_APIS[@]}"
echo "  Skipped (not found): ${#SKIPPED_APIS[@]}"
echo "  Failed: ${#FAILED_APIS[@]}"
echo "  Duration: ${DURATION}s"

if [[ ${#DELETED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "✅ Successfully deleted APIs:"
    printf '  - %s\n' "${DELETED_APIS[@]}"
fi

if [[ ${#SKIPPED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "⏭️  Skipped APIs (not found):"
    printf '  - %s\n' "${SKIPPED_APIS[@]}"
fi

if [[ ${#FAILED_APIS[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Failed API deletions:"
    printf '  - %s\n' "${FAILED_APIS[@]}"
    echo ""
    error "Some API deletions failed"
    exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
    success "Dry run completed successfully in ${DURATION}s"
else
    if [[ ${#DELETED_APIS[@]} -eq 0 && ${#SKIPPED_APIS[@]} -eq $API_COUNT ]]; then
        success "No APIs were found to delete - all APIs already removed"
    else
        success "API deletion completed successfully in ${DURATION}s"
    fi
fi

log "API deletion process completed for environment: $ENVIRONMENT"