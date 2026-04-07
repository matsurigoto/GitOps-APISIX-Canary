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

    # Validate that the sed replacements actually occurred
    if ! grep -A2 'serviceName: spring-boot-stable' "$ROUTE_YAML" | head -3 | grep -q "weight: ${STABLE_WEIGHT}"; then
      echo "⚠️  Warning: stable weight update may not have applied correctly."
    fi
    if ! grep -A2 'serviceName: spring-boot-canary' "$ROUTE_YAML" | head -3 | grep -q "weight: ${CANARY_WEIGHT}"; then
      echo "⚠️  Warning: canary weight update may not have applied correctly."
    fi

    # Commit and push if there are changes
    if command -v git &>/dev/null && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
      git -C "$REPO_ROOT" config user.name  "${GIT_USER_NAME:-github-actions[bot]}"
      git -C "$REPO_ROOT" config user.email "${GIT_USER_EMAIL:-github-actions[bot]@users.noreply.github.com}"
      git -C "$REPO_ROOT" add "$ROUTE_YAML"
      if ! git -C "$REPO_ROOT" diff --staged --quiet; then
        git -C "$REPO_ROOT" commit -m "chore: bluegreen switch to ${ACTIVE} (stable=${STABLE_WEIGHT} canary=${CANARY_WEIGHT})"
        git -C "$REPO_ROOT" push && echo "✅ GitOps manifest committed and pushed." || echo "⚠️  git push failed (non-fatal)."
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
    ANNOTATION_TEXT="Blue-Green switch to ${ACTIVE} (stable=${STABLE_WEIGHT} canary=${CANARY_WEIGHT})"
    curl -s -o /dev/null -w "Grafana annotation: HTTP %{http_code}\n" \
      "${GRAFANA_URL}/api/annotations" \
      -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
      -H "Content-Type: application/json" \
      -X POST \
      -d "{
        \"text\": \"${ANNOTATION_TEXT}\",
        \"tags\": [\"bluegreen\", \"weight-switch\"]
      }" 2>/dev/null || echo "⚠️  Grafana annotation skipped (not reachable)."
  fi
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
