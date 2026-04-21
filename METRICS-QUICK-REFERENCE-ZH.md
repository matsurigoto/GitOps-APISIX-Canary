# APISIX 指標快速參考

## 儀表板 → 指標對應

### 1. APISIX 總覽
```
apisix_http_status                           # QPS、錯誤率
apisix_http_latency_bucket{type="request"}   # 延遲 P50/P95/P99
apisix_nginx_http_current_connections        # 活躍連接數
apisix_bandwidth{type="ingress|egress"}      # 頻寬
apisix_etcd_reachable                        # etcd 狀態
```

### 2. APISIX 路由指標
```
apisix_http_status by (route)                        # 依路由的 QPS
apisix_http_status by (route, code)                  # 依路由的狀態碼
apisix_http_latency_bucket{type="request"} by (route)  # 依路由的延遲
apisix_http_latency_bucket{type="upstream"} by (route) # 上游延遲
apisix_http_latency_bucket{type="apisix"} by (route)   # APISIX 延遲
```

### 3. 金絲雀流量
```
apisix_http_status{route=~".*canary.*"}      # 金絲雀流量
apisix_http_status{route=~".*stable.*"}      # 穩定版流量
apisix_http_latency_bucket by (route)        # 延遲比較
```

### 4. APISIX 節點指標
```
up{job="apisix"}                             # 節點數量
apisix_nginx_metric_errors_total             # Worker 進程
apisix_shared_dict_capacity_bytes            # 字典容量
apisix_shared_dict_free_space_bytes          # 字典可用空間
container_memory_usage_bytes{pod=~"apisix-.*"} # 記憶體使用量
container_cpu_usage_seconds_total{pod=~"apisix-.*"} # CPU 使用量
apisix_etcd_modify_indexes                   # 配置變更
```

### 5. APISIX 上游健康狀態
```
apisix_upstream_status                       # 上游健康狀態
apisix_http_status by (upstream)             # 依上游的請求數
apisix_http_latency_bucket{type="upstream"} by (upstream) # 上游延遲
apisix_node_info                             # 節點元數據
```

### 6. APISIX 安全性與限流
```
apisix_http_status{code="429"}               # 被限流
apisix_http_status{code="403"}               # IP 被封鎖
apisix_http_status{code="401"}               # 認證失敗
apisix_http_status{code="400"}               # 錯誤請求
apisix_shared_dict_*{name="plugin-limit-*"}  # 限流記憶體
```

### 7. APISIX SSL/TLS 與憑證
```
apisix_ssl_certs                             # 憑證到期時間
apisix_nginx_http_current_connections{state="ssl_handshake"} # SSL 握手
apisix_http_status by (ssl_protocol)         # TLS 協議
apisix_http_status by (ssl_cipher)           # 加密套件使用
apisix_http_status{scheme="https|http"}      # HTTPS vs HTTP
```

### 8. APISIX 插件指標
```
apisix_http_status{plugin!=""}               # 插件使用
apisix_http_status{plugin="opentelemetry"}   # OTEL 追蹤
apisix_http_status{plugin="opa"}             # OPA 評估
apisix_http_status{cache_status="HIT"}       # 快取命中
apisix_http_latency_bucket{type="apisix"} by (plugin) # 插件延遲
```

### 9. APISIX Nginx/OpenResty 指標
```
nginx_worker_processes                       # Worker 數量
apisix_nginx_http_current_connections by (state) # 連接狀態
nginx_connections_accepted                   # 已接受連接
nginx_connections_handled                    # 已處理連接
nginx_http_requests_total                    # 總請求數
nginx_lua_shared_dict_used_bytes             # LuaJIT 記憶體
nginx_lua_timers                             # 計時器數量
```

### 10. APISIX 效能與快取
```
apisix_http_status                           # 整體 QPS
apisix_http_latency_bucket{type="*"}         # 所有延遲類型
apisix_http_status{cache_status="*"}         # 快取效能
apisix_bandwidth_bucket{type="egress"}       # 回應大小
```

### 11. Spring Boot 指標
```
http_server_requests_seconds_count           # 請求數量
http_server_requests_seconds_sum             # 請求持續時間
jvm_memory_used_bytes                        # JVM 記憶體
jvm_gc_pause_seconds                         # GC 暫停
system_cpu_usage                             # CPU 使用率
process_uptime_seconds                       # 運行時間
```

---

## 常見 Prometheus 查詢模式

### 速率 (QPS)
```promql
sum(rate(apisix_http_status[5m]))            # 總 QPS
sum(rate(apisix_http_status[5m])) by (route) # 依路由的 QPS
```

### 百分位延遲
```promql
histogram_quantile(0.95, sum(rate(apisix_http_latency_bucket{type="request"}[5m])) by (le))
```

### 錯誤率
```promql
sum(rate(apisix_http_status{code=~"5.."}[5m])) / sum(rate(apisix_http_status[5m])) * 100
```

### 快取命中率
```promql
sum(rate(apisix_http_status{cache_status="HIT"}[5m])) / sum(rate(apisix_http_status{cache_status!=""}[5m])) * 100
```

### 記憶體使用百分比
```promql
(apisix_shared_dict_capacity_bytes - apisix_shared_dict_free_space_bytes) / apisix_shared_dict_capacity_bytes * 100
```

---

## 標籤參考

### apisix_http_status 的常見標籤
- `route` - 路由名稱/ID
- `code` - HTTP 狀態碼（200、404、500 等）
- `service` - 服務名稱
- `upstream` - 上游名稱
- `plugin` - 插件名稱
- `cache_status` - HIT、MISS、BYPASS、EXPIRED
- `ssl_protocol` - TLSv1.2、TLSv1.3
- `ssl_cipher` - 加密套件名稱
- `sni` - 伺服器名稱指示
- `scheme` - http、https

### apisix_http_latency_bucket 的常見標籤
- `type` - request、upstream、apisix
- `route` - 路由名稱/ID
- `le` - 直方圖區間（50、100、200、500、1000、5000、+Inf）

### apisix_nginx_http_current_connections 的常見標籤
- `state` - active、waiting、reading、writing

---

## 時間範圍建議

- **即時監控**：最近 5-15 分鐘
- **效能分析**：最近 1-6 小時
- **趨勢分析**：最近 24 小時 - 7 天
- **容量規劃**：最近 30-90 天

---

## 閾值建議

### 延遲 (P95)
- 綠色：< 200ms
- 黃色：200-1000ms
- 紅色：> 1000ms

### 錯誤率 (5xx)
- 綠色：< 1%
- 黃色：1-5%
- 紅色：> 5%

### 快取命中率
- 紅色：< 50%
- 黃色：50-80%
- 綠色：> 80%

### 憑證到期
- 紅色：< 7 天
- 黃色：7-30 天
- 橘色：30-60 天
- 綠色：> 60 天

### 記憶體使用率（共享字典）
- 綠色：< 70%
- 黃色：70-90%
- 紅色：> 90%

---

## 整合端點

### Prometheus
- 端點：`http://apisix:9091/apisix/prometheus/metrics`
- 抓取間隔：15s
- 保留期限：7 天

### Tempo
- 追蹤後端：OTLP gRPC
- 收集器：`http://otel-collector.observability:4318`
- UI：整合於金絲雀流量儀表板

### OTEL Collector
- 接收：OTLP（4317 gRPC、4318 HTTP）
- 匯出：Prometheus（8889）、Tempo（gRPC）

---

詳細儀表板文件請參閱：
- 英文：`gitops/observability/grafana-dashboards/README.md`
- 中文：`MONITORING-DASHBOARDS-ZH.md`
