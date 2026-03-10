# APISIX Metrics Quick Reference

## Dashboard → Metrics Mapping

### 1. APISIX Overview
```
apisix_http_status                           # QPS, error rates
apisix_http_latency_bucket{type="request"}   # Latency P50/P95/P99
apisix_nginx_http_current_connections        # Active connections
apisix_bandwidth{type="ingress|egress"}      # Bandwidth
apisix_etcd_reachable                        # etcd status
```

### 2. APISIX Route Metrics
```
apisix_http_status by (route)                        # QPS by route
apisix_http_status by (route, code)                  # Status codes by route
apisix_http_latency_bucket{type="request"} by (route)  # Latency by route
apisix_http_latency_bucket{type="upstream"} by (route) # Upstream latency
apisix_http_latency_bucket{type="apisix"} by (route)   # APISIX latency
```

### 3. Canary Traffic
```
apisix_http_status{route=~".*canary.*"}      # Canary traffic
apisix_http_status{route=~".*stable.*"}      # Stable traffic
apisix_http_latency_bucket by (route)        # Latency comparison
```

### 4. APISIX Node Metrics
```
up{job="apisix"}                             # Node count
apisix_nginx_metric_errors_total             # Worker processes
apisix_shared_dict_capacity_bytes            # Dict capacity
apisix_shared_dict_free_space_bytes          # Dict free space
container_memory_usage_bytes{pod=~"apisix-.*"} # Memory usage
container_cpu_usage_seconds_total{pod=~"apisix-.*"} # CPU usage
apisix_etcd_modify_indexes                   # Config changes
```

### 5. APISIX Upstream Health
```
apisix_upstream_status                       # Upstream health
apisix_http_status by (upstream)             # Requests by upstream
apisix_http_latency_bucket{type="upstream"} by (upstream) # Upstream latency
apisix_node_info                             # Node metadata
```

### 6. APISIX Security & Rate Limiting
```
apisix_http_status{code="429"}               # Rate limited
apisix_http_status{code="403"}               # IP blocked
apisix_http_status{code="401"}               # Auth failed
apisix_http_status{code="400"}               # Bad requests
apisix_shared_dict_*{name="plugin-limit-*"}  # Rate limit memory
```

### 7. APISIX SSL/TLS & Certificates
```
apisix_ssl_certs                             # Cert expiry time
apisix_nginx_http_current_connections{state="ssl_handshake"} # SSL handshakes
apisix_http_status by (ssl_protocol)         # TLS protocol
apisix_http_status by (ssl_cipher)           # Cipher usage
apisix_http_status{scheme="https|http"}      # HTTPS vs HTTP
```

### 8. APISIX Plugin Metrics
```
apisix_http_status{plugin!=""}               # Plugin usage
apisix_http_status{plugin="opentelemetry"}   # OTEL traces
apisix_http_status{plugin="opa"}             # OPA evaluations
apisix_http_status{cache_status="HIT"}       # Cache hits
apisix_http_latency_bucket{type="apisix"} by (plugin) # Plugin latency
```

### 9. APISIX Nginx/OpenResty Metrics
```
nginx_worker_processes                       # Worker count
apisix_nginx_http_current_connections by (state) # Connection states
nginx_connections_accepted                   # Accepted conns
nginx_connections_handled                    # Handled conns
nginx_http_requests_total                    # Total requests
nginx_lua_shared_dict_used_bytes             # LuaJIT memory
nginx_lua_timers                             # Timer count
```

### 10. APISIX Performance & Cache
```
apisix_http_status                           # Overall QPS
apisix_http_latency_bucket{type="*"}         # All latency types
apisix_http_status{cache_status="*"}         # Cache performance
apisix_bandwidth_bucket{type="egress"}       # Response sizes
```

### 11. Spring Boot Metrics
```
http_server_requests_seconds_count           # Request count
http_server_requests_seconds_sum             # Request duration
jvm_memory_used_bytes                        # JVM memory
jvm_gc_pause_seconds                         # GC pauses
system_cpu_usage                             # CPU usage
process_uptime_seconds                       # Uptime
```

---

## Common Prometheus Query Patterns

### Rate (QPS)
```promql
sum(rate(apisix_http_status[5m]))            # Total QPS
sum(rate(apisix_http_status[5m])) by (route) # QPS by route
```

### Percentile Latency
```promql
histogram_quantile(0.95, sum(rate(apisix_http_latency_bucket{type="request"}[5m])) by (le))
```

### Error Rate
```promql
sum(rate(apisix_http_status{code=~"5.."}[5m])) / sum(rate(apisix_http_status[5m])) * 100
```

### Cache Hit Rate
```promql
sum(rate(apisix_http_status{cache_status="HIT"}[5m])) / sum(rate(apisix_http_status{cache_status!=""}[5m])) * 100
```

### Memory Usage Percentage
```promql
(apisix_shared_dict_capacity_bytes - apisix_shared_dict_free_space_bytes) / apisix_shared_dict_capacity_bytes * 100
```

---

## Label Reference

### Common Labels on apisix_http_status
- `route` - Route name/ID
- `code` - HTTP status code (200, 404, 500, etc.)
- `service` - Service name
- `upstream` - Upstream name
- `plugin` - Plugin name
- `cache_status` - HIT, MISS, BYPASS, EXPIRED
- `ssl_protocol` - TLSv1.2, TLSv1.3
- `ssl_cipher` - Cipher suite name
- `sni` - Server Name Indication
- `scheme` - http, https

### Common Labels on apisix_http_latency_bucket
- `type` - request, upstream, apisix
- `route` - Route name/ID
- `le` - Histogram bucket (50, 100, 200, 500, 1000, 5000, +Inf)

### Common Labels on apisix_nginx_http_current_connections
- `state` - active, waiting, reading, writing

---

## Time Range Recommendations

- **Real-time monitoring**: Last 5-15 minutes
- **Performance analysis**: Last 1-6 hours
- **Trend analysis**: Last 24 hours - 7 days
- **Capacity planning**: Last 30-90 days

---

## Threshold Recommendations

### Latency (P95)
- Green: < 200ms
- Yellow: 200-1000ms
- Red: > 1000ms

### Error Rate (5xx)
- Green: < 1%
- Yellow: 1-5%
- Red: > 5%

### Cache Hit Rate
- Red: < 50%
- Yellow: 50-80%
- Green: > 80%

### Certificate Expiry
- Red: < 7 days
- Yellow: 7-30 days
- Orange: 30-60 days
- Green: > 60 days

### Memory Usage (Shared Dict)
- Green: < 70%
- Yellow: 70-90%
- Red: > 90%

---

## Integration Points

### Prometheus
- Endpoint: `http://apisix:9091/apisix/prometheus/metrics`
- Scrape Interval: 15s
- Retention: 7 days

### Tempo
- Trace Backend: OTLP gRPC
- Collector: `http://otel-collector.observability:4318`
- UI: Integrated in Canary Traffic dashboard

### OTEL Collector
- Receives: OTLP (4317 gRPC, 4318 HTTP)
- Exports: Prometheus (8889), Tempo (gRPC)

---

For detailed dashboard documentation, see:
- English: `gitops/observability/grafana-dashboards/README.md`
- Chinese: `MONITORING-DASHBOARDS-ZH.md`
