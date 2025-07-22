#!/bin/bash
# ------------------------------------------------------------------------------
# 📦 Script: deploy-apis.sh
#
# 🧩 Description:
#   Deploys one or more APIs to Azure API Management (APIM) using a shared Bicep
#   template. The script reads a configuration JSON file that defines all APIs
#   to deploy and dynamically injects parameters and spec file paths into a
#   temporary Bicep file for each deployment.
#
# 🛠️  Features:
#   - Reads from `api-config.json` (or a custom config file)
#   - Injects OpenAPI/WSDL `specPath` as a compile-time constant
#   - Supports any number of Bicep parameters (strings, arrays, bools, etc.)
#   - Handles spacing, quoting, and special characters properly
#   - Deletes temporary Bicep files after deployment
#
# 📌 Usage:
#   ./deploy-apis.sh <resource-group> <apim-name> [config-file] [template-file]
#
#   Example:
#   ./deploy-apis.sh my-rg my-apim ./api-config.json ./apis/api-template.bicep
# ------------------------------------------------------------------------------

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Input Arguments
# ──────────────────────────────────────────────────────────────────────────────
RG="$1"                       # Azure Resource Group name
APIM_NAME="$2"                # Azure API Management instance name
CONFIG_FILE="${3:-./api-config.json}"            # Optional: Path to API config
TEMPLATE_FILE="${4:-./apis/api-template.bicep}"  # Optional: Path to base Bicep

# ──────────────────────────────────────────────────────────────────────────────
# Validate Required Parameters
# ──────────────────────────────────────────────────────────────────────────────
if [[ -z "$RG" || -z "$APIM_NAME" ]]; then
  echo "❌ Usage: $0 <resource-group> <apim-name> [config-file] [template-file]"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Process each API config entry (safe for strings with spaces, arrays, etc.)
# ──────────────────────────────────────────────────────────────────────────────
jq -c '.[]' "$CONFIG_FILE" | while read -r api; do
  # Extract core identifiers
  API_ID=$(echo "$api" | jq -r '.apiId')
  SPEC_PATH=$(echo "$api" | jq -r '.specPath')

  echo "🔧 Preparing API: $API_ID"

  # Build dynamic parameter string (excluding inline specPath/apiId)
  PARAMS="apimName=\"$APIM_NAME\" apiId=\"$API_ID\""
  for key in $(echo "$api" | jq -r 'keys[]'); do
  if [[ "$key" == "specPath" || "$key" == "apiId" ]]; then continue; fi
    val=$(echo "$api" | jq -c --arg k "$key" '.[$k]')

  # Detect if value is a string literal (not an object or array)
  if echo "$val" | jq -e 'type == "string"' > /dev/null; then
    val=$(echo "$val" | jq -r '.')  # Unquote for CLI usage
    PARAMS="$PARAMS $key=\"$val\""
  else
    PARAMS="$PARAMS $key='$val'"  # Preserve JSON for arrays/objects
  fi
done

  # ────────────────────────────────────────────────────────────────────────────
  # Generate a temporary Bicep file with the SPEC_PATH injected
  # Bicep requires loadTextContent paths to be known at compile-time
  # ────────────────────────────────────────────────────────────────────────────
  TEMP_BICEP="./temp-api-${API_ID}.bicep"
  sed "s|__SPEC_PATH__|$SPEC_PATH|g" "$TEMPLATE_FILE" > "$TEMP_BICEP"

  # ────────────────────────────────────────────────────────────────────────────
  # Deploy the API using Azure CLI and the generated Bicep template
  # ────────────────────────────────────────────────────────────────────────────
  echo "🚀 Deploying API: $API_ID..."
  eval az deployment group create \
    --resource-group "\"$RG\"" \
    --template-file "\"$TEMP_BICEP\"" \
    --parameters $PARAMS

  # Clean up the temporary file
  echo "🧹 Cleaning up $TEMP_BICEP"
  rm "$TEMP_BICEP"
done

# ──────────────────────────────────────────────────────────────────────────────
# Completion message
# ──────────────────────────────────────────────────────────────────────────────
echo "✅ All APIs deployed successfully."