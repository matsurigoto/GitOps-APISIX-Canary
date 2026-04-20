# APISIX Monitoring & Grafana Dashboards

This directory contains comprehensive Grafana dashboards for monitoring Apache APISIX in a GitOps Canary deployment setup.

## 📊 Available Dashboards

### 1. **APISIX Overview** (`apisix-overview.json`)
High-level overview of APISIX gateway performance and health.

**Key Metrics:**
- Total QPS (Queries Per Second)
- Average latency (P50, P95, P99)
- 4xx and 5xx error rates
- Active connections
- Bandwidth (ingress/egress)
- etcd connectivity status
- Connection states over time

**Best for:** Quick health checks and overall system status

---

### 2. **APISIX Route Metrics** (`apisix-route-metrics.json`)
Detailed metrics broken down by individual routes.

**Key Metrics:**
- QPS by route
- HTTP status codes by route
- Latency percentiles (P50/P95/P99) by route
- Upstream latency breakdown
- APISIX internal processing latency
- Error rates (4xx/5xx) by route

**Best for:** Troubleshooting specific routes and analyzing route performance

---

### 3. **Canary Traffic Split** (`canary-traffic.json`)
Specialized dashboard for canary deployment monitoring.

**Key Metrics:**
- Traffic distribution (Stable vs Canary) pie chart
- QPS comparison between versions
- Latency comparison (P95)
- Error rate comparison (5xx)
- Success rate trends
- Recent request traces (Tempo integration)
- Bandwidth comparison

**Best for:** Monitoring canary rollouts and comparing version performance

---

### 4. **APISIX Node Metrics** (`apisix-node-metrics.json`) ✨ NEW
Infrastructure and node-level monitoring.

**Key Metrics:**
- Node status and health
- Worker processes
- Shared dictionary memory usage
- Config sync status with etcd
- APISIX memory and CPU usage
- etcd modify index
- Shared dict free space
- Node uptime
- Config reload errors

**Best for:** Infrastructure monitoring and capacity planning

---

### 5. **APISIX Upstream Health** (`apisix-upstream-health.json`) ✨ NEW
Backend service health and connectivity monitoring.

**Key Metrics:**
- Upstream health status
- Total active upstreams
- Unhealthy upstream count
- Request distribution across upstreams
- Upstream response times (P95)
- Connection pool status
- Error rates by upstream service
- Health check success rate
- Upstream latency heatmap

**Best for:** Diagnosing backend service issues and load balancing

---

### 6. **APISIX Security & Rate Limiting** (`apisix-security.json`) ✨ NEW
Security events and rate limiting monitoring.

**Key Metrics:**
- Rate limit rejections (429 responses)
- IP restriction blocks (403 responses)
- Authentication failures (401 responses)
- Bad requests (400 responses)
- Security blocks by type over time
- Shared dict usage for rate limiting plugins
- Top blocked IPs
- Auth attempts by route
- Request validation errors
- CORS rejections

**Best for:** Security monitoring and DDoS protection analysis

---

### 7. **APISIX SSL/TLS & Certificates** (`apisix-ssl-certs.json`) ✨ NEW
SSL/TLS configuration and certificate monitoring.

**Key Metrics:**
- Total SSL/TLS certificates
- Certificates expiring soon (<30 days)
- SSL handshake rate
- Certificate expiry timeline
- SSL/TLS protocol distribution
- SSL handshake errors
- Cipher usage
- Days remaining for certificates
- HTTPS vs HTTP request rates
- Client certificate validation
- SNI routing statistics

**Best for:** Certificate management and SSL/TLS security

---

### 8. **APISIX Plugin Metrics** (`apisix-plugins.json`) ✨ NEW
Plugin usage and performance monitoring.

**Key Metrics:**
- Active plugins count
- OpenTelemetry traces exported
- Prometheus metrics scrapes
- OPA policy evaluations
- Traffic split plugin usage
- Proxy cache hit rate
- Plugin execution latency
- Request validation (valid/invalid)
- Fault injection activity
- CORS plugin usage
- Proxy/response rewrite stats
- Serverless function executions

**Best for:** Analyzing plugin performance and usage patterns

---

### 9. **APISIX Nginx/OpenResty Metrics** (`apisix-nginx.json`) ✨ NEW
Low-level Nginx/OpenResty metrics.

**Key Metrics:**
- Worker processes count
- Connection states (active/reading/writing)
- Accepted vs handled connections
- Connection queue/waiting
- Request rate
- LuaJIT memory usage
- Timer count
- Worker CPU usage
- Connection rate

**Best for:** Low-level performance tuning and debugging

---

### 10. **APISIX Performance & Cache** (`apisix-performance.json`) ✨ NEW
Comprehensive performance analysis with caching metrics.

**Key Metrics:**
- Overall request rate
- Latency percentiles (P50/P95/P99)
- Latency breakdown (upstream vs APISIX)
- Throughput by status code
- Cache hit rate
- Cache status distribution
- Response size distribution
- Request/response body sizes
- Bandwidth usage
- Latency heatmap

**Best for:** Performance optimization and cache efficiency analysis

---

### 11. **Spring Boot Metrics** (`spring-boot-metrics.json`)
Application-level metrics for Spring Boot backend services.

**Key Metrics:**
- HTTP request rate by URI/method/status
- HTTP request duration (P95)
- JVM heap and non-heap memory
- GC pause duration
- Thread counts (live/daemon/peak)
- CPU usage (process & system)
- Process uptime
- Version by instance

**Best for:** Application performance monitoring

---

## 🔧 APISIX Metrics Reference

### Core Metrics Exported by APISIX

#### Request Metrics
- `apisix_http_status` - Request count by status code, route, and labels
- `apisix_http_latency` - Request latency histogram with types:
  - `type="request"` - Total request latency
  - `type="upstream"` - Upstream service latency
  - `type="apisix"` - APISIX internal processing latency

#### Connection Metrics
- `apisix_nginx_http_current_connections` - Current connection states:
  - `state="active"` - Active connections
  - `state="waiting"` - Waiting connections
  - `state="reading"` - Reading connections
  - `state="writing"` - Writing connections

#### Bandwidth Metrics
- `apisix_bandwidth` - Traffic volume:
  - `type="ingress"` - Incoming traffic
  - `type="egress"` - Outgoing traffic

#### Health Metrics
- `apisix_etcd_reachable` - etcd connectivity (1=healthy, 0=unhealthy)
- `apisix_etcd_modify_indexes` - etcd modification tracking
- `apisix_upstream_status` - Upstream health status

#### Memory & Resource Metrics
- `apisix_shared_dict_capacity_bytes` - Shared dictionary capacity
- `apisix_shared_dict_free_space_bytes` - Shared dictionary free space
- `apisix_node_info` - Node metadata

#### Certificate Metrics
- `apisix_ssl_certs` - SSL certificate expiry time

### Available Labels

- `route` - Route name/identifier
- `code` - HTTP status code
- `type` - Latency type (request/upstream/apisix)
- `node` - Node identifier
- `state` - Connection state
- `upstream` - Upstream service name
- `plugin` - Plugin name
- `cache_status` - Cache hit/miss status
- `ssl_protocol` - TLS protocol version
- `ssl_cipher` - TLS cipher suite
- `sni` - Server Name Indication

---

## 🚀 Deployment

The dashboards are automatically deployed via Kustomize ConfigMap generation:

```yaml
# kustomization.yaml generates ConfigMaps with labels
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

configMapGenerator:
  - name: grafana-dashboard-<name>
    files:
      - <dashboard>.json
    options:
      labels:
        grafana_dashboard: "1"  # Auto-discovery by Grafana sidecar
      annotations:
        grafana_folder: "GitOps Canary"
```

### How It Works

1. **Kustomize** generates ConfigMaps from JSON dashboard files
2. **Grafana Sidecar** watches for ConfigMaps with label `grafana_dashboard: "1"`
3. **Auto-Import** dashboards are automatically loaded into Grafana
4. **Folder Organization** all dashboards appear in "GitOps Canary" folder

---

## 📈 Prometheus Configuration

### ServiceMonitor for APISIX

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: apisix
  namespace: observability
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: apisix
  endpoints:
  - port: prometheus
    path: /apisix/prometheus/metrics
    interval: 15s
```

### APISIX Configuration

Prometheus plugin is enabled in `values.yaml`:

```yaml
apisix:
  pluginAttrs:
    prometheus:
      export_uri: /apisix/prometheus/metrics
      enable_export_server: true
      export_addr:
        ip: "0.0.0.0"
        port: 9091
      metric_prefix: apisix_
      prefer_name: true
```

---

## 🎯 Dashboard Usage Guide

### For Operators

1. **Start with APISIX Overview** - Get overall system health
2. **Check specific routes** - Use Route Metrics dashboard
3. **Monitor backends** - Review Upstream Health
4. **Security checks** - Examine Security & Rate Limiting dashboard

### For Developers

1. **Performance analysis** - Use Performance & Cache dashboard
2. **Application metrics** - Check Spring Boot Metrics
3. **Trace debugging** - Review Canary Traffic for trace links

### For Security Teams

1. **Security events** - Monitor Security & Rate Limiting
2. **SSL/TLS status** - Check SSL/TLS & Certificates
3. **Authentication** - Review auth failure rates

### For SREs

1. **Capacity planning** - Use Node Metrics dashboard
2. **Resource usage** - Check Nginx/OpenResty Metrics
3. **Plugin performance** - Analyze Plugin Metrics

---

## 🔗 Integration Points

### Prometheus
- **URL**: `http://monitoring-prometheus.observability:9090`
- **Datasource UID**: `prometheus`
- **Scrape Interval**: 15s
- **Retention**: 7 days

### Tempo (Distributed Tracing)
- **URL**: `http://tempo.observability:3100`
- **Datasource UID**: `tempo`
- **Integration**: OpenTelemetry traces from APISIX routes

### OTEL Collector
- **Receiver**: `http://otel-collector.observability:4318`
- **Exporter**: Prometheus metrics on port 8889
- **Trace Backend**: Tempo via OTLP gRPC

---

## 🛠️ Troubleshooting

### Dashboard Not Showing Data

1. Check APISIX metrics endpoint:
   ```bash
   kubectl port-forward -n ingress-apisix svc/apisix 9091:9091
   curl http://localhost:9091/apisix/prometheus/metrics
   ```

2. Verify ServiceMonitor:
   ```bash
   kubectl get servicemonitor -n observability
   kubectl describe servicemonitor apisix -n observability
   ```

3. Check Prometheus targets:
   - Open Prometheus UI → Status → Targets
   - Look for `apisix` endpoint
   - Verify it's in "UP" state

### Missing Metrics

Some metrics require specific plugins or configuration:
- **SSL metrics**: Require HTTPS/TLS enabled routes
- **Cache metrics**: Require proxy-cache plugin
- **Plugin metrics**: Require respective plugins enabled
- **Upstream metrics**: Require upstream health checks configured

### Dashboard Variables Not Working

Currently, dashboards use static queries. To add template variables:
1. Edit dashboard JSON
2. Add to `templating.list` section
3. Update panel queries to use `$variable_name`

---

## 📚 References

- [APISIX Prometheus Plugin](https://apisix.apache.org/docs/apisix/plugins/prometheus/)
- [APISIX OpenTelemetry Plugin](https://apisix.apache.org/docs/apisix/plugins/opentelemetry/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

---

## 📝 Customization

### Adding New Panels

1. Edit the dashboard JSON file
2. Add new panel object to `panels` array
3. Configure `gridPos` for layout positioning
4. Set appropriate datasource and queries

### Modifying Thresholds

Update `fieldConfig.defaults.thresholds`:

```json
"thresholds": {
  "mode": "absolute",
  "steps": [
    { "color": "green", "value": null },
    { "color": "yellow", "value": 100 },
    { "color": "red", "value": 500 }
  ]
}
```

### Adding Template Variables

Add to `templating.list` in dashboard JSON:

```json
"templating": {
  "list": [
    {
      "name": "namespace",
      "type": "query",
      "query": "label_values(apisix_http_status, namespace)",
      "current": { "selected": true, "text": "All", "value": "$__all" }
    }
  ]
}
```

---

## 🎉 Summary

You now have **11 comprehensive dashboards** covering:
- ✅ Overall performance and health
- ✅ Route-specific metrics
- ✅ Canary deployment monitoring
- ✅ Node and infrastructure metrics
- ✅ Upstream service health
- ✅ Security and rate limiting
- ✅ SSL/TLS certificate management
- ✅ Plugin performance
- ✅ Nginx/OpenResty low-level metrics
- ✅ Performance and caching analysis
- ✅ Application (Spring Boot) metrics

All dashboards are production-ready and follow Grafana best practices!
