#!/bin/bash
set -euo pipefail
# =============================================================================
# Initialize Canary Upstream via APISIX Admin API
# =============================================================================
# This creates an upstream managed exclusively by Admin API (not Ingress Controller).
# Run this ONCE after APISIX is deployed.
# =============================================================================

APISIX_ADMIN="${APISIX_ADMIN_URL:-http://127.0.0.1:9180}"
ADMIN_KEY="${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}"
UPSTREAM_ID="canary-upstream"

echo "Initializing canary upstream via Admin API..."
echo "APISIX Admin: $APISIX_ADMIN"

# Create upstream with stable=100, canary=0
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "${APISIX_ADMIN}/apisix/admin/upstreams/${UPSTREAM_ID}" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d '{
    "name": "canary-upstream",
    "desc": "Managed by Admin API for canary/blue-green switching",
    "type": "roundrobin",
    "nodes": {
      "spring-boot-stable.app:8080": 100,
      "spring-boot-canary.app:8080": 0
    },
    "retries": 3,
    "timeout": {
      "connect": 6,
      "send": 6,
      "read": 6
    },
    "checks": {
      "active": {
        "type": "http",
        "http_path": "/actuator/health",
        "healthy": {
          "interval": 5,
          "successes": 2
        },
        "unhealthy": {
          "interval": 5,
          "http_failures": 3
        }
      }
    }
  }'

echo ""
echo "Upstream '${UPSTREAM_ID}' initialized."
echo "  stable  → spring-boot-stable.app:8080  (weight: 100)"
echo "  canary  → spring-boot-canary.app:8080  (weight: 0)"
echo ""
echo "Verify:"
echo "  curl ${APISIX_ADMIN}/apisix/admin/upstreams/${UPSTREAM_ID} -H 'X-API-KEY: ${ADMIN_KEY}'"
