#!/bin/bash
set -euo pipefail
# =============================================================================
# Canary Traffic Switch — via APISIX Admin API
# =============================================================================
# Usage:
#   ./canary-switch.sh --stable 90 --canary 10
#   ./canary-switch.sh --stable 50 --canary 50
#   ./canary-switch.sh --stable 0  --canary 100    # full canary
#   ./canary-switch.sh --stable 100 --canary 0     # rollback
#
# Prerequisites:
#   - Port-forward APISIX admin: kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix
#   - Or set APISIX_ADMIN_URL environment variable
# =============================================================================

APISIX_ADMIN="${APISIX_ADMIN_URL:-http://127.0.0.1:9180}"
ADMIN_KEY="${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}"
UPSTREAM_ID="canary-upstream"

# Parse arguments
STABLE_WEIGHT=100
CANARY_WEIGHT=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --stable)  STABLE_WEIGHT="$2"; shift 2 ;;
    --canary)  CANARY_WEIGHT="$2"; shift 2 ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "═══════════════════════════════════════════════════════"
echo "  Canary Traffic Switch"
echo "═══════════════════════════════════════════════════════"
echo "  Stable weight : ${STABLE_WEIGHT}"
echo "  Canary weight : ${CANARY_WEIGHT}"
echo "═══════════════════════════════════════════════════════"
echo ""

# PATCH upstream nodes
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
BODY=$(echo "$RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
  echo "✅ Traffic switch successful!"
  echo ""
  echo "Current distribution:"
  TOTAL=$((STABLE_WEIGHT + CANARY_WEIGHT))
  if [[ $TOTAL -gt 0 ]]; then
    STABLE_PCT=$((STABLE_WEIGHT * 100 / TOTAL))
    CANARY_PCT=$((CANARY_WEIGHT * 100 / TOTAL))
    echo "  stable : ${STABLE_PCT}% (weight ${STABLE_WEIGHT})"
    echo "  canary : ${CANARY_PCT}% (weight ${CANARY_WEIGHT})"
  fi

  # ── Layer 1: Update GitOps manifest and commit ──────────────────────────
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  ROUTE_YAML="${REPO_ROOT}/gitops/apisix/apisix-route.yaml"

  if [[ -f "$ROUTE_YAML" ]]; then
    echo ""
    echo "Updating GitOps manifest: ${ROUTE_YAML}"
    # Update only the api-route section (not actuator-route)
    sed -i -E '/name: api-route/,/name: actuator-route/{/serviceName: spring-boot-stable/{n;n;s/weight: [0-9]+/weight: '"${STABLE_WEIGHT}"'/;}}' "$ROUTE_YAML"
    sed -i -E '/name: api-route/,/name: actuator-route/{/serviceName: spring-boot-canary/{n;n;s/weight: [0-9]+/weight: '"${CANARY_WEIGHT}"'/;}}' "$ROUTE_YAML"

    # Commit and push if there are changes
    if command -v git &>/dev/null && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
      cd "$REPO_ROOT"
      git config user.name  "${GIT_USER_NAME:-github-actions[bot]}"
      git config user.email "${GIT_USER_EMAIL:-github-actions[bot]@users.noreply.github.com}"
      git add "$ROUTE_YAML"
      if ! git diff --staged --quiet; then
        git commit -m "chore: canary weight stable=${STABLE_WEIGHT} canary=${CANARY_WEIGHT}"
        git push && echo "✅ GitOps manifest committed and pushed." || echo "⚠️  git push failed (non-fatal)."
      else
        echo "ℹ️  No changes to commit (weights already match)."
      fi
    fi
  fi

  # ── Layer 2: Grafana annotation (optional) ──────────────────────────────
  GRAFANA_URL="${GRAFANA_URL:-}"
  GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"
  if [[ -n "$GRAFANA_URL" && -n "$GRAFANA_API_KEY" ]]; then
    echo ""
    echo "Creating Grafana annotation..."
    ANNOTATION_TEXT="Canary switch: stable=${STABLE_WEIGHT} canary=${CANARY_WEIGHT}"
    curl -s -o /dev/null -w "Grafana annotation: HTTP %{http_code}\n" \
      "${GRAFANA_URL}/api/annotations" \
      -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
      -H "Content-Type: application/json" \
      -X POST \
      -d "{
        \"text\": \"${ANNOTATION_TEXT}\",
        \"tags\": [\"canary\", \"weight-switch\"]
      }" 2>/dev/null || echo "⚠️  Grafana annotation skipped (not reachable)."
  fi
else
  echo "❌ Failed! HTTP ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi
