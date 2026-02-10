#!/bin/bash
set -euo pipefail
# =============================================================================
# Blue-Green Deployment Switch — via APISIX Admin API
# =============================================================================
# Usage:
#   ./bluegreen-switch.sh --active blue
#   ./bluegreen-switch.sh --active green
#
# This performs an instant 100:0 or 0:100 weight switch.
# For blue-green, "blue" maps to stable and "green" maps to canary.
# =============================================================================

APISIX_ADMIN="${APISIX_ADMIN_URL:-http://127.0.0.1:9180}"
ADMIN_KEY="${APISIX_ADMIN_KEY:-gitops-canary-admin-key-2026}"
UPSTREAM_ID="canary-upstream"
ACTIVE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --active)  ACTIVE="$2"; shift 2 ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ACTIVE" ]]; then
  echo "Usage: $0 --active blue|green"
  exit 1
fi

case "$ACTIVE" in
  blue)
    STABLE_WEIGHT=100
    CANARY_WEIGHT=0
    ;;
  green)
    STABLE_WEIGHT=0
    CANARY_WEIGHT=100
    ;;
  *)
    echo "Invalid value: --active must be 'blue' or 'green'"
    exit 1
    ;;
esac

echo "═══════════════════════════════════════════════════════"
echo "  Blue-Green Switch → Active: ${ACTIVE}"
echo "═══════════════════════════════════════════════════════"
echo "  blue  (stable) : weight ${STABLE_WEIGHT}"
echo "  green (canary)  : weight ${CANARY_WEIGHT}"
echo "═══════════════════════════════════════════════════════"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${APISIX_ADMIN}/apisix/admin/upstreams/${UPSTREAM_ID}" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -X PATCH \
  -d "{
    \"nodes\": {
      \"spring-boot-stable.app:8080\": ${STABLE_WEIGHT},
      \"spring-boot-canary.app:8080\": ${CANARY_WEIGHT}
    }
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
  echo "✅ Blue-Green switch successful! Active environment: ${ACTIVE}"
else
  echo "❌ Failed! HTTP ${HTTP_CODE}"
  echo "$RESPONSE"
  exit 1
fi

# Also update OPA blue-green data if OPA is used for routing
echo ""
echo "Updating OPA active version data..."
OPA_URL="${OPA_URL:-http://127.0.0.1:8181}"
curl -s -o /dev/null -w "OPA update: HTTP %{http_code}\n" \
  "${OPA_URL}/v1/data/config/active_version" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d "{\"active_version\": \"${ACTIVE}\"}" 2>/dev/null || echo "(OPA update skipped — not reachable)"
