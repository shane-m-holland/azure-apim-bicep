#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script: delete-apis.sh
# Description: Deletes all APIs listed in a configuration JSON file from an
#              Azure API Management (APIM) instance.
# Usage: ./delete-apis.sh <resource-group> <apim-name> [config-file]
# ─────────────────────────────────────────────────────────────────────────────

set -e  # Exit immediately if a command exits with a non-zero status

# ──────────────
# Input arguments
# ──────────────
RG="$1"                                 # Azure Resource Group name
APIM_NAME="$2"                          # Azure APIM instance name
CONFIG_FILE="${3:-./api-config.json}"   # Optional: path to API config JSON

# ──────────────
# Argument check
# ──────────────
if [[ -z "$RG" || -z "$APIM_NAME" ]]; then
  echo "Usage: $0 <resource-group> <apim-name> [config-file]"
  exit 1
fi

# ──────────────
# Loop through each API configuration entry (one JSON object per line)
# ──────────────
jq -c '.[]' "$CONFIG_FILE" | while read -r api; do
  API_ID=$(echo "$api" | jq -r '.apiId')  # Extract the API identifier

  echo "Deleting API: $API_ID..."

  az apim api delete \
    --resource-group "$RG" \
    --service-name "$APIM_NAME" \
    --api-id "$API_ID" \
    --yes  # Skip confirmation prompt
done

# ──────────────
# Done
# ──────────────
echo "🗑️ All APIs deleted."