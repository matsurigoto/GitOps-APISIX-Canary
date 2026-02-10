#!/bin/bash
set -euo pipefail
# =============================================================================
# Upload OPA Bundle to Azure Blob Storage
# =============================================================================
# Usage: ./upload-opa-bundle.sh
#
# Prerequisites:
#   - OPA CLI installed: https://www.openpolicyagent.org/docs/latest/#running-opa
#   - Azure CLI logged in: az login
#   - STORAGE_ACCOUNT env var set
# =============================================================================

STORAGE_ACCOUNT="${STORAGE_ACCOUNT:?Error: STORAGE_ACCOUNT env var is required}"
BLOB_CONTAINER="${BLOB_CONTAINER:-opa-bundles}"
BUNDLE_FILE="bundle.tar.gz"
POLICY_DIR="opa/policy"

# Navigate to repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

echo "Building OPA bundle from ${POLICY_DIR}..."
opa build -b "${POLICY_DIR}" -o "${BUNDLE_FILE}"
echo "Bundle contents:"
tar tzf "${BUNDLE_FILE}"
echo ""

echo "Uploading to Azure Blob Storage..."
az storage blob upload \
  --account-name "${STORAGE_ACCOUNT}" \
  --container-name "${BLOB_CONTAINER}" \
  --file "${BUNDLE_FILE}" \
  --name "${BUNDLE_FILE}" \
  --overwrite \
  --auth-mode login

echo ""
echo "✅ Bundle uploaded to: https://${STORAGE_ACCOUNT}.blob.core.windows.net/${BLOB_CONTAINER}/${BUNDLE_FILE}"

# Cleanup
rm -f "${BUNDLE_FILE}"
