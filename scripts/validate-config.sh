#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script: validate-config.sh
# Description: Comprehensive validation for APIM configurations, API specs,
#              and environment settings. Provides detailed feedback on issues
#              and suggestions for fixes.
# Usage: ./validate-config.sh [environment] [config-file]
# Example: ./validate-config.sh dev ./api-config.json
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

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

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

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++)) || true
    ((TOTAL_CHECKS++)) || true
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED_CHECKS++)) || true
    ((TOTAL_CHECKS++)) || true
}

warn() {
    echo -e "  ${YELLOW}!${NC} $1"
    ((WARNING_CHECKS++)) || true
    ((TOTAL_CHECKS++)) || true
}

usage() {
    echo "Usage: $0 [environment] [config-file]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to validate (dev, staging, prod) - optional"
    echo "  config-file    API configuration file to validate (JSON/YAML supported)"
    echo "                 Default: auto-discover api-config.yaml or api-config.json"
    echo ""
    echo "Examples:"
    echo "  $0                          # Validate all environments and default config"
    echo "  $0 dev                      # Validate dev environment only"
    echo "  $0 dev ./my-apis.yaml       # Validate dev environment with YAML config"
    echo "  $0 dev ./my-apis.json       # Validate dev environment with JSON config"
    exit 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Validation Functions
# ──────────────────────────────────────────────────────────────────────────────

validate_wsdl_spec() {
    local spec_path="$1"
    
    # Check if xmllint is available for XML validation
    if command -v xmllint &> /dev/null; then
        if xmllint --noout "$spec_path" 2>/dev/null; then
            pass "WSDL file has valid XML syntax"
            
            # Check for WSDL-specific elements
            if grep -q "<definitions.*" "$spec_path" && grep -q "xmlns.*wsdl" "$spec_path" && grep -qE "<(wsdl:|tns:)?(service|binding|portType)[ >]" "$spec_path"; then
                pass "WSDL file contains required WSDL elements"
            else
                warn "File appears to be XML but may not be a valid WSDL (missing WSDL namespace or elements)"
            fi
        else
            fail "WSDL file has invalid XML syntax: $spec_path"
        fi
    else
        # Basic validation without xmllint
        if grep -q "<?xml" "$spec_path" && grep -q "definitions" "$spec_path"; then
            pass "WSDL file appears to have basic XML structure"
            
            # Check for WSDL namespace
            if grep -q "xmlns.*wsdl" "$spec_path"; then
                pass "WSDL file contains WSDL namespace"
            else
                warn "WSDL file may be missing WSDL namespace declaration"
            fi
            
            # Check for WSDL elements
            local wsdl_elements=("service" "binding" "portType" "message" "types")
            local found_elements=0
            for element in "${wsdl_elements[@]}"; do
                if grep -qE "<(wsdl:|tns:)?$element[ >]" "$spec_path"; then
                    ((found_elements++))
                fi
            done
            
            if [[ $found_elements -ge 2 ]]; then
                pass "WSDL file contains $found_elements WSDL elements"
            else
                warn "WSDL file may be incomplete (found only $found_elements WSDL elements)"
            fi
        else
            fail "WSDL file does not appear to be valid XML"
        fi
        
        warn "xmllint not available - WSDL validation is limited. Install libxml2-utils for complete validation."
    fi
}

validate_openapi_spec() {
    local spec_path="$1"
    local is_yaml=false
    
    # Determine if it's YAML or JSON
    case "$spec_path" in
        *.yaml|*.yml) is_yaml=true ;;
    esac
    
    # Check for OpenAPI version indicators
    if [[ "$is_yaml" == "true" ]]; then
        if command -v yq &> /dev/null; then
            local openapi_version=$(yq eval '.openapi // .swagger // empty' "$spec_path" 2>/dev/null)
            if [[ -n "$openapi_version" ]]; then
                pass "OpenAPI spec version: $openapi_version"
                
                # Basic OpenAPI structure validation
                local required_fields=("info" "paths")
                for field in "${required_fields[@]}"; do
                    if yq eval "has(\"$field\")" "$spec_path" 2>/dev/null | grep -q "true"; then
                        pass "OpenAPI spec has required field: $field"
                    else
                        fail "OpenAPI spec missing required field: $field"
                    fi
                done
            else
                warn "No OpenAPI/Swagger version found in YAML spec"
            fi
        fi
    else
        # JSON validation
        local openapi_version=$(jq -r '.openapi // .swagger // empty' "$spec_path" 2>/dev/null)
        if [[ -n "$openapi_version" && "$openapi_version" != "null" ]]; then
            pass "OpenAPI spec version: $openapi_version"
            
            # Basic OpenAPI structure validation
            local required_fields=("info" "paths")
            for field in "${required_fields[@]}"; do
                if jq -e "has(\"$field\")" "$spec_path" >/dev/null 2>&1; then
                    pass "OpenAPI spec has required field: $field"
                else
                    fail "OpenAPI spec missing required field: $field"
                fi
            done
            
            # Check for common OpenAPI fields
            local common_fields=("servers" "components" "security")
            for field in "${common_fields[@]}"; do
                if jq -e "has(\"$field\")" "$spec_path" >/dev/null 2>&1; then
                    pass "OpenAPI spec has optional field: $field"
                fi
            done
        else
            warn "No OpenAPI/Swagger version found in JSON spec"
        fi
    fi
}

validate_prerequisites() {
    log "Validating prerequisites..."
    
    # Check if jq is installed
    if command -v jq &> /dev/null; then
        pass "jq is installed"
    else
        fail "jq is not installed - required for JSON processing"
    fi
    
    # Check if yq is installed (for YAML support)
    if command -v yq &> /dev/null; then
        local yq_version=$(yq --version 2>/dev/null | head -n1 || echo "unknown")
        pass "yq is installed ($yq_version)"
    else
        warn "yq is not installed - YAML configuration support will be limited"
        echo "  Install yq with: pip install yq  # or brew install yq"
    fi
    
    # Check if Azure CLI is installed
    if command -v az &> /dev/null; then
        pass "Azure CLI is installed"
        
        # Check Azure CLI version
        local az_version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
        if [[ "$az_version" != "unknown" ]]; then
            pass "Azure CLI version: $az_version"
        else
            warn "Could not determine Azure CLI version"
        fi
        
        # Check if logged in to Azure
        if az account show >/dev/null 2>&1; then
            local current_sub=$(az account show --query name -o tsv)
            pass "Logged in to Azure (Subscription: $current_sub)"
        else
            warn "Not logged in to Azure - run 'az login' before deployment"
        fi
    else
        fail "Azure CLI is not installed"
    fi
    
    # Check if bicep is available
    if az bicep version >/dev/null 2>&1; then
        local bicep_version=$(az bicep version 2>/dev/null | grep -o 'Bicep CLI version [0-9.]*' | cut -d' ' -f4 || echo "unknown")
        pass "Bicep CLI is available (version: $bicep_version)"
    else
        warn "Bicep CLI not found - install with 'az bicep install'"
    fi
}

validate_project_structure() {
    log "Validating project structure..."
    
    # Check for required files
    local required_files=(
        "bicep/main.bicep"
        "bicep/apis/api-template.bicep"
        "bicep/apim/apim-service.bicep"
        "bicep/network/nsg.bicep"
        "bicep/network/vnet.bicep"
        "bicep/products/products.bicep"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            pass "Required file exists: $file"
        else
            fail "Required file missing: $file"
        fi
    done
    
    # Check for required directories
    local required_dirs=("environments" "specs" "scripts")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            pass "Required directory exists: $dir"
        else
            fail "Required directory missing: $dir"
        fi
    done
    
    # Check scripts are executable
    local scripts=("scripts/deploy-infrastructure.sh" "scripts/destroy-infrastructure.sh" "scripts/deploy-apis.sh" "scripts/destroy-apis.sh")
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                pass "Script is executable: $script"
            else
                warn "Script is not executable: $script (run chmod +x $script)"
            fi
        else
            warn "Script not found: $script"
        fi
    done
}

validate_environment_config() {
    local env="$1"
    local config_file="./environments/${env}/config.env"
    
    log "Validating environment: $env"
    
    if [[ ! -f "$config_file" ]]; then
        fail "Environment configuration not found: $config_file"
        return
    fi
    
    pass "Environment configuration exists: $config_file"
    
    # Source the config file safely
    if ! source "$config_file" 2>/dev/null; then
        fail "Failed to source environment configuration"
        return
    fi
    
    # Validate required variables
    local required_vars=(
        "ENVIRONMENT" "RESOURCE_GROUP" "APIM_NAME" "LOCATION"
        "SKU_NAME" "SKU_CAPACITY" "PUBLISHER_EMAIL" "PUBLISHER_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            pass "Required variable set: $var=${!var}"
        else
            fail "Required variable missing or empty: $var"
        fi
    done
    
    # Validate specific values
    if [[ -n "${PUBLISHER_EMAIL:-}" ]]; then
        if [[ "$PUBLISHER_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            pass "Publisher email format is valid"
        else
            fail "Publisher email format is invalid: $PUBLISHER_EMAIL"
        fi
    fi
    
    if [[ -n "${SKU_NAME:-}" ]]; then
        case "$SKU_NAME" in
            "Developer"|"Basic"|"Standard"|"Premium")
                pass "SKU name is valid: $SKU_NAME"
                ;;
            *)
                fail "Invalid SKU name: $SKU_NAME (must be Developer, Basic, Standard, or Premium)"
                ;;
        esac
    fi
    
    if [[ -n "${LOCATION:-}" ]]; then
        # Basic location validation
        if [[ "${#LOCATION}" -gt 3 && "$LOCATION" =~ ^[a-z0-9]+$ ]]; then
            pass "Location format appears valid: $LOCATION"
        else
            warn "Location format may be invalid: $LOCATION"
        fi
    fi
    
    # Check VNET CIDR format
    if [[ -n "${VNET_CIDR:-}" ]]; then
        if [[ "$VNET_CIDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            pass "VNET CIDR format is valid: $VNET_CIDR"
        else
            fail "VNET CIDR format is invalid: $VNET_CIDR"
        fi
    fi
    
    if [[ -n "${SUBNET_CIDR:-}" ]]; then
        if [[ "$SUBNET_CIDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            pass "Subnet CIDR format is valid: $SUBNET_CIDR"
        else
            fail "Subnet CIDR format is invalid: $SUBNET_CIDR"
        fi
    fi
}

validate_api_config() {
    local config_file="$1"
    
    log "Validating API configuration: $config_file"
    
    if [[ ! -f "$config_file" ]]; then
        fail "API configuration file not found: $config_file"
        return
    fi
    
    pass "API configuration file exists"
    
    # Detect configuration format
    local config_format=$(detect_config_format "$config_file")
    local format_display=$(get_config_format_display_name "$config_format")
    
    if ! is_config_format_supported "$config_format"; then
        fail "Unsupported configuration format: $config_format (supported: JSON, YAML)"
        return
    fi
    
    # Validate syntax based on format
    if validate_config_syntax "$config_file"; then
        pass "API configuration has valid $format_display syntax"
    else
        fail "API configuration has invalid $format_display syntax"
        return
    fi
    
    # Check if it's an array
    local is_array
    case "$config_format" in
        "json")
            is_array=$(jq -e 'type == "array"' "$config_file" >/dev/null 2>&1 && echo "true" || echo "false")
            ;;
        "yaml")
            if command -v yq &> /dev/null; then
                is_array=$(yq eval 'type' "$config_file" 2>/dev/null | grep -q "!!seq" && echo "true" || echo "false")
            else
                warn "Cannot validate array type - yq not available"
                is_array="unknown"
            fi
            ;;
    esac
    
    if [[ "$is_array" == "true" ]]; then
        pass "API configuration is a $format_display array"
    elif [[ "$is_array" == "unknown" ]]; then
        warn "Cannot validate if configuration is an array"
    else
        fail "API configuration must be a $format_display array"
        return
    fi
    
    # Get API count
    local api_count
    case "$config_format" in
        "json")
            api_count=$(jq length "$config_file" 2>/dev/null || echo "0")
            ;;
        "yaml")
            if command -v yq &> /dev/null; then
                api_count=$(yq eval 'length' "$config_file" 2>/dev/null || echo "0")
            else
                api_count="unknown"
            fi
            ;;
    esac
    
    if [[ "$api_count" == "unknown" ]]; then
        warn "Cannot determine API count - yq not available"
    elif [[ "$api_count" -gt 0 ]]; then
        pass "Found $api_count APIs in configuration"
    else
        warn "No APIs found in configuration"
        return
    fi
    
    # Validate each API configuration
    local api_index=0
    while read -r api; do
        echo ""
        echo "  Validating API #$((++api_index)):"
        
        # Required fields
        local required_fields=("apiId" "displayName" "path" "specPath")
        for field in "${required_fields[@]}"; do
            local value=$(echo "$api" | jq -r ".$field // empty")
            if [[ -n "$value" && "$value" != "null" ]]; then
                pass "Required field present: $field = $value"
            else
                fail "Required field missing or null: $field"
            fi
        done
        
        # Validate API ID format (should be URL-safe)
        local api_id=$(echo "$api" | jq -r '.apiId // empty')
        if [[ -n "$api_id" ]]; then
            if [[ "$api_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                pass "API ID format is valid: $api_id"
            else
                fail "API ID should only contain letters, numbers, hyphens, and underscores: $api_id"
            fi
        fi
        
        # Validate path format
        local path=$(echo "$api" | jq -r '.path // empty')
        if [[ -n "$path" ]]; then
            if [[ "$path" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
                pass "API path format is valid: $path"
            else
                warn "API path contains special characters: $path"
            fi
        fi
        
        # Check if spec file exists
        local spec_path=$(echo "$api" | jq -r '.specPath // empty')
        if [[ -n "$spec_path" ]]; then
            if [[ -f "$spec_path" ]]; then
                pass "Spec file exists: $spec_path"
                
                # Validate spec file content based on format
                case "$spec_path" in
                    *.json)
                        if jq empty "$spec_path" 2>/dev/null; then
                            pass "Spec file has valid JSON syntax"
                            # Additional OpenAPI validation for JSON files
                            validate_openapi_spec "$spec_path"
                        else
                            fail "Spec file has invalid JSON syntax: $spec_path"
                        fi
                        ;;
                    *.yaml|*.yml)
                        # Basic YAML validation (if yq is available)
                        if command -v yq &> /dev/null; then
                            if yq eval '.' "$spec_path" >/dev/null 2>&1; then
                                pass "Spec file has valid YAML syntax"
                                # Additional OpenAPI validation for YAML files
                                validate_openapi_spec "$spec_path"
                            else
                                fail "Spec file has invalid YAML syntax: $spec_path"
                            fi
                        else
                            warn "yq not available - skipping YAML validation for $spec_path"
                        fi
                        ;;
                    *.wsdl|*.xml)
                        # WSDL/XML validation
                        validate_wsdl_spec "$spec_path"
                        ;;
                    *)
                        warn "Unknown spec file format: $spec_path (supported: .json, .yaml, .yml, .wsdl, .xml)"
                        ;;
                esac
            else
                fail "Spec file not found: $spec_path"
            fi
        fi
        
        # Validate format field matches spec file extension
        local format=$(echo "$api" | jq -r '.format // empty')
        if [[ -n "$format" && -n "$spec_path" ]]; then
            case "$spec_path" in
                *.json)
                    if [[ "$format" == "openapi+json" || "$format" == "openapi" || "$format" == "swagger-json" ]]; then
                        pass "Format '$format' matches JSON spec file"
                    else
                        warn "Format '$format' may not match JSON spec file (recommended: openapi+json)"
                    fi
                    ;;
                *.yaml|*.yml)
                    if [[ "$format" == "openapi" || "$format" == "swagger-yaml" ]]; then
                        pass "Format '$format' matches YAML spec file"
                    else
                        warn "Format '$format' may not match YAML spec file (recommended: openapi)"
                    fi
                    ;;
                *.wsdl|*.xml)
                    if [[ "$format" == "wsdl" || "$format" == "wsdl-link" ]]; then
                        pass "Format '$format' matches WSDL spec file"
                    else
                        warn "Format '$format' may not match WSDL spec file (recommended: wsdl)"
                    fi
                    ;;
            esac
        fi
        
        # Validate array fields
        local array_fields=("protocols" "productIds" "gatewayNames" "tags")
        for field in "${array_fields[@]}"; do
            if echo "$api" | jq -e "has(\"$field\")" >/dev/null; then
                if echo "$api" | jq -e ".$field | type == \"array\"" >/dev/null; then
                    local length=$(echo "$api" | jq ".$field | length")
                    pass "$field is array with $length items"
                else
                    fail "$field must be an array"
                fi
            fi
        done
        
        # Validate boolean fields
        local bool_fields=("subscriptionRequired")
        for field in "${bool_fields[@]}"; do
            if echo "$api" | jq -e "has(\"$field\")" >/dev/null; then
                if echo "$api" | jq -e ".$field | type == \"boolean\"" >/dev/null; then
                    local value=$(echo "$api" | jq ".$field")
                    pass "$field is boolean: $value"
                else
                    fail "$field must be a boolean (true/false)"
                fi
            fi
        done
    done < <(get_config_array_items "$config_file")
}

validate_bicep_templates() {
    log "Validating Bicep templates..."
    
    local templates=("bicep/main.bicep" "bicep/apis/api-template.bicep")
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            echo ""
            echo "  Validating template: $template"
            
            # Special handling for api-template.bicep
            if [[ "$template" == "bicep/apis/api-template.bicep" ]]; then
                # Find a valid spec file from API config for testing
                local test_spec_path=""
                if [[ -f "$CONFIG_FILE" ]]; then
                    test_spec_path=$(jq -r '.[0].specPath // empty' "$CONFIG_FILE" 2>/dev/null)
                fi
                
                if [[ -n "$test_spec_path" && -f "$test_spec_path" ]]; then
                    # Create temporary template in bicep directory with adjusted relative path
                    local temp_template="bicep/apis/api-template-test-$$.bicep"
                    # Convert ./specs/file.json to ../../specs/file.json for bicep/apis/ directory
                    local relative_spec_path="${test_spec_path#./}"  # Remove leading ./
                    relative_spec_path="../../$relative_spec_path"
                    sed "s#__SPEC_PATH__#$relative_spec_path#g" "$template" > "$temp_template"
                    
                    # Validate the temporary template
                    if az bicep build --file "$temp_template" --stdout >/dev/null 2>&1; then
                        pass "Template compiles successfully (with test spec)"
                    else
                        fail "Template compilation failed - check syntax"
                    fi
                    
                    # Clean up
                    rm -f "$temp_template"
                else
                    # Just check for placeholder presence if no spec available
                    if grep -q "__SPEC_PATH__" "$template"; then
                        pass "Template placeholder found (compilation skipped - no test spec available)"
                    else
                        fail "Template placeholder (__SPEC_PATH__) not found"
                    fi
                fi
            else
                # Normal Bicep syntax validation for other templates
                if az bicep build --file "$template" --stdout >/dev/null 2>&1; then
                    pass "Template compiles successfully"
                else
                    fail "Template compilation failed - check syntax"
                fi
            fi
            
            # Check for required parameters in main template
            if [[ "$template" == "bicep/main.bicep" ]]; then
                local required_params=("apimName" "publisherEmail" "publisherName")
                for param in "${required_params[@]}"; do
                    if grep -q "param $param" "$template"; then
                        pass "Required parameter defined: $param"
                    else
                        fail "Required parameter missing: $param"
                    fi
                done
            fi
            
            # Check for placeholder in API template
            if [[ "$template" == "bicep/apis/api-template.bicep" ]]; then
                if grep -q "__SPEC_PATH__" "$template"; then
                    pass "Spec path placeholder found"
                else
                    fail "Spec path placeholder (__SPEC_PATH__) not found"
                fi
            fi
        else
            fail "Template file not found: $template"
        fi
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Validation Logic
# ──────────────────────────────────────────────────────────────────────────────

ENVIRONMENT="${1:-}"
# If config file is provided as argument, use it directly; otherwise find config file
if [[ -n "${2:-}" ]]; then
    CONFIG_FILE="$2"
else
    # Auto-discover config file (prefer YAML, fallback to JSON)
    CONFIG_FILE=$(find_config_file "./environments/${ENVIRONMENT:-dev}/api-config" "api-config" 2>/dev/null || echo "./environments/${ENVIRONMENT:-dev}/api-config.json")
fi

echo "🔍 APIM Configuration Validation"
echo "═══════════════════════════════════════════"
echo ""

# Run prerequisite checks
validate_prerequisites
echo ""

# Validate project structure
validate_project_structure
echo ""

# Validate Bicep templates
validate_bicep_templates
echo ""

# Validate environment configurations
if [[ -n "$ENVIRONMENT" ]]; then
    validate_environment_config "$ENVIRONMENT"
else
    # Validate all environments
    if [[ -d "environments" ]]; then
        for env_dir in environments/*/; do
            if [[ -d "$env_dir" ]]; then
                local env_name=$(basename "$env_dir")
                validate_environment_config "$env_name"
                echo ""
            fi
        done
    fi
fi

# Validate API configuration
validate_api_config "$CONFIG_FILE"

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo ""
echo "📊 Validation Summary"
echo "═══════════════════════════════════════════"
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo ""
    success "Validation completed successfully! ✨"
    echo ""
    echo "Your configuration is ready for deployment."
    if [[ -n "$ENVIRONMENT" ]]; then
        echo "Run: ./scripts/deploy-infrastructure.sh $ENVIRONMENT"
        echo "Then: ./scripts/deploy-apis.sh $ENVIRONMENT"
    fi
    exit 0
else
    echo ""
    error "Validation failed with $FAILED_CHECKS errors"
    echo ""
    echo "Please fix the errors above before proceeding with deployment."
    exit 1
fi