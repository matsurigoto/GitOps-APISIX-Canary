# ============================================================================
# OPA Policy: Blue-Green Routing Decision
# ============================================================================
# This policy is used by APISIX OPA plugin for blue-green deployment.
# It reads `data.config.active_version` (set via OPA Data API) to determine
# which version (blue or green) should receive ALL traffic.
#
# To switch versions, call OPA Data API:
#   PUT /v1/data/config/active_version
#   Content-Type: application/json
#   {"active_version": "green"}
# ============================================================================
package apisix.bluegreen

import rego.v1

default allow := true

# ── Default active version (blue) if not set via Data API ─────────────────
default_active := "blue"

active_version := data.config.active_version if {
    data.config.active_version
}

active_version := default_active if {
    not data.config.active_version
}

# ── Main decision result ───────────────────────────────────────────────────
result := {
    "allow": true,
    "headers": {"x-route-to": active_version},
    "reason": sprintf("Blue-green active version: %s", [active_version]),
}
