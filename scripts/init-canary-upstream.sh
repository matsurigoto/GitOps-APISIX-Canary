#!/bin/bash
set -euo pipefail
# =============================================================================
# Initialize Canary Upstream via APISIX Admin API
# =============================================================================
# This creates an upstream managed exclusively by Admin API (not Ingress Controller).
# Run this ONCE after APISIX is deployed.
# =============================================================================

APISIX_ADMIN="${APISIX_ADMIN_URL:-http://127.0.0.1:9180}"
ADMIN_KEY="${APISIX_ADMIN_KEY:-gitops-canary-admin-key-2026}"
UPSTREAM_ID="canary-upstream"
# Ingress Controller managed upstream for canary pods (used in traffic-split)
# ID is derived from the ApisixRoute CRD: app_spring-boot-canary_8080
CANARY_UPSTREAM_ID="${CANARY_UPSTREAM_ID:-1b646cab}"

echo "Initializing canary upstream via Admin API..."
echo "APISIX Admin: $APISIX_ADMIN"

# Create upstream with stable=100, canary=1
# NOTE: Canary weight must be >= 1 (not 0) for OPA plugin to route traffic to it
# The OPA plugin will override weight-based routing based on x-canary header
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
      "spring-boot-canary.app:8080": 1
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
echo "  canary  → spring-boot-canary.app:8080  (weight: 1)"
echo ""
echo "NOTE: Although weight ratio is 100:1, OPA plugin will override this"
echo "      and route based on x-canary header (header-based routing)."

# =============================================================================
# Create Admin API route for /api/* pointing to canary-upstream
# Priority 100 ensures this route wins over CRD-managed route (default: 0).
# This is required so that APISIX uses DNS-based node labels
# (spring-boot-stable.app:8080 / spring-boot-canary.app:8080) in metrics,
# which allows the Grafana "Canary Traffic Split" dashboard to work correctly.
# =============================================================================
ROUTE_ID="canary-api-route"
OPA_HOST="${OPA_HOST:-http://opa.opa-system:8181}"

echo ""
echo "Creating Admin API route '${ROUTE_ID}' for /api/* → ${UPSTREAM_ID} ..."

ROUTE_PAYLOAD=$(cat <<EOF
{
  "name": "canary-api-route",
  "desc": "Admin API managed route — uses canary-upstream with DNS node names for Grafana metrics",
  "uri": "/api/*",
  "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"],
  "upstream_id": "${UPSTREAM_ID}",
  "priority": 100,
  "plugins": {
    "prometheus": {
      "prefer_name": true
    },
    "opentelemetry": {
      "sampler": {
        "name": "always_on"
      }
    },
    "opa": {
      "host": "${OPA_HOST}",
      "policy": "apisix/canary",
      "with_route": true,
      "with_service": false,
      "with_consumer": false
    },
    "traffic-split": {
      "rules": [
        {
          "match": [{"vars": [["http_x_canary", "==", "true"]]}],
          "weighted_upstreams": [
            {"upstream_id": "${CANARY_UPSTREAM_ID}", "weight": 100}
          ]
        }
      ]
    }
  }
}
EOF
)

curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "${APISIX_ADMIN}/apisix/admin/routes/${ROUTE_ID}" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d "${ROUTE_PAYLOAD}"

echo ""
echo "Route '${ROUTE_ID}' created (priority=100 → overrides CRD route priority=0)."

# =============================================================================
# Create dedicated canary-header-route for x-canary: true requests
# Priority 200 ensures it wins over canary-api-route (priority=100).
# This route produces a distinct route="canary-header-route" label in
# Prometheus metrics, enabling the Grafana Canary Traffic Split dashboard
# to separately track header-based canary traffic.
# =============================================================================
HEADER_ROUTE_ID="canary-header-route"

echo ""
echo "Creating Admin API route '${HEADER_ROUTE_ID}' for x-canary:true → ${CANARY_UPSTREAM_ID} ..."

HEADER_ROUTE_PAYLOAD=$(cat <<EOF
{
  "name": "canary-header-route",
  "desc": "Header-based canary route — x-canary:true → canary pods. Produces distinct route label for Grafana.",
  "uri": "/api/*",
  "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"],
  "vars": [["http_x_canary", "==", "true"]],
  "upstream_id": "${CANARY_UPSTREAM_ID}",
  "priority": 200,
  "plugins": {
    "prometheus": {
      "prefer_name": true
    },
    "opentelemetry": {
      "sampler": {
        "name": "always_on"
      }
    },
    "opa": {
      "host": "${OPA_HOST}",
      "policy": "apisix/canary",
      "with_route": true,
      "with_service": false,
      "with_consumer": false
    }
  }
}
EOF
)

curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "${APISIX_ADMIN}/apisix/admin/routes/${HEADER_ROUTE_ID}" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d "${HEADER_ROUTE_PAYLOAD}"

echo ""
echo "Route '${HEADER_ROUTE_ID}' created (priority=200, x-canary:true → upstream ${CANARY_UPSTREAM_ID})."
echo ""
echo "Verify:"
echo "  curl ${APISIX_ADMIN}/apisix/admin/upstreams/${UPSTREAM_ID}      -H 'X-API-KEY: ${ADMIN_KEY}'"
echo "  curl ${APISIX_ADMIN}/apisix/admin/routes/${ROUTE_ID}            -H 'X-API-KEY: ${ADMIN_KEY}'"
echo "  curl ${APISIX_ADMIN}/apisix/admin/routes/${HEADER_ROUTE_ID}     -H 'X-API-KEY: ${ADMIN_KEY}'"
echo ""
echo "Grafana 'Canary Traffic Split' dashboard queries:"
echo "  route=\"canary-api-route\"    →  weighted stable/canary traffic"
echo "  route=\"canary-header-route\" →  x-canary:true header traffic"
