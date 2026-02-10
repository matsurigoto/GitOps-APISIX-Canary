# ============================================================================
# OPA Policy: Canary Routing Decision
# ============================================================================
# This policy is used by APISIX OPA plugin to decide canary routing.
# - If header "x-canary: true" → route to canary upstream
# - If header "x-canary-percentage" exists → probabilistic canary routing
# - Otherwise → route to stable upstream
# ============================================================================
package apisix.canary

import rego.v1

default allow := true

# ── Main decision result ───────────────────────────────────────────────────
result := {
    "allow": true,
    "headers": {"x-route-to": route_target},
    "reason": sprintf("Routing to %s", [route_target]),
}

# ── Header-based canary: explicit opt-in ───────────────────────────────────
canary_by_header if {
    input.request.headers["x-canary"] == "true"
}

# ── Cookie-based canary: user sticky session ───────────────────────────────
canary_by_cookie if {
    cookie := input.request.headers.cookie
    contains(cookie, "canary=true")
}

# ── Determine route target ────────────────────────────────────────────────
route_target := "canary" if {
    canary_by_header
}

route_target := "canary" if {
    canary_by_cookie
}

route_target := "stable" if {
    not canary_by_header
    not canary_by_cookie
}
