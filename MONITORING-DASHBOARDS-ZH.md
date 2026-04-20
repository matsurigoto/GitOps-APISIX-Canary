# APISIX 監控指標與 Grafana 儀表板擴充

## 📊 新增的儀表板總覽

本次更新為 GitOps-APISIX-Canary 項目新增了 **7 個全新的 Grafana 儀表板**，大幅增強 APISIX 監控能力。

### 原有儀表板 (4 個)
1. ✅ **APISIX Overview** - APISIX 總覽
2. ✅ **APISIX Route Metrics** - 路由指標
3. ✅ **Canary Traffic** - 金絲雀流量分析
4. ✅ **Spring Boot Metrics** - Spring Boot 應用指標

### 新增儀表板 (7 個)

#### 5. 🆕 **APISIX Node Metrics** (節點指標)
**檔案**: `apisix-node-metrics.json`

監控 APISIX 節點層級的基礎設施健康狀態：
- 節點狀態與健康檢查
- Worker 進程數量
- Shared Dictionary 記憶體使用率
- 與 etcd 的配置同步狀態
- APISIX 記憶體與 CPU 使用量
- etcd modify index 追蹤
- 節點運行時間
- 配置重載錯誤

**適用場景**: 基礎設施監控、容量規劃

---

#### 6. 🆕 **APISIX Upstream Health** (上游服務健康)
**檔案**: `apisix-upstream-health.json`

監控後端服務的健康狀態與連線品質：
- 上游服務健康狀態
- 活躍的上游服務數量
- 不健康的上游服務計數
- 請求分配到各上游的分布
- 上游響應時間 (P95)
- 連線池狀態
- 各服務的錯誤率
- 健康檢查成功率
- 上游延遲熱圖

**適用場景**: 診斷後端服務問題、負載平衡分析

---

#### 7. 🆕 **APISIX Security & Rate Limiting** (安全與限流)
**檔案**: `apisix-security.json`

監控安全事件與限流防護：
- 速率限制拒絕 (429 回應)
- IP 限制封鎖 (403 回應)
- 認證失敗 (401 回應)
- 錯誤請求 (400 回應)
- 各類型安全封鎖的時間趨勢
- 限流插件的 Shared Dict 使用率
- 被封鎖的 Top IP 列表
- 各路由的認證嘗試
- 請求驗證錯誤
- CORS 拒絕統計

**適用場景**: 安全監控、DDoS 防護分析

---

#### 8. 🆕 **APISIX SSL/TLS & Certificates** (SSL/TLS 與憑證)
**檔案**: `apisix-ssl-certs.json`

監控 SSL/TLS 配置與憑證管理：
- SSL/TLS 憑證總數
- 即將過期的憑證 (<30 天)
- SSL 握手速率
- 憑證到期時間表
- SSL/TLS 協議版本分布
- SSL 握手錯誤
- 加密套件使用統計
- 憑證剩餘天數儀表
- HTTPS vs HTTP 請求比率
- 客戶端憑證驗證
- SNI 路由統計

**適用場景**: 憑證管理、SSL/TLS 安全

---

#### 9. 🆕 **APISIX Plugin Metrics** (插件指標)
**檔案**: `apisix-plugins.json`

監控 APISIX 插件的使用與效能：
- 活躍插件數量
- OpenTelemetry 追蹤導出
- Prometheus 指標抓取
- OPA 策略評估
- Traffic Split 插件使用
- 代理快取命中率
- 插件執行延遲
- 請求驗證 (有效/無效)
- 故障注入活動
- CORS 插件使用
- Proxy/Response Rewrite 統計
- Serverless 函數執行

**適用場景**: 分析插件效能與使用模式

---

#### 10. 🆕 **APISIX Nginx/OpenResty Metrics** (Nginx/OpenResty 指標)
**檔案**: `apisix-nginx.json`

監控底層 Nginx/OpenResty 指標：
- Worker 進程數量
- 連線狀態 (active/reading/writing)
- 已接受 vs 已處理的連線
- 連線佇列/等待
- 請求速率
- LuaJIT 記憶體使用
- Timer 計數
- Worker CPU 使用率
- 連線速率

**適用場景**: 底層效能調校與除錯

---

#### 11. 🆕 **APISIX Performance & Cache** (效能與快取)
**檔案**: `apisix-performance.json`

全面的效能分析與快取指標：
- 整體請求速率
- 延遲百分位 (P50/P95/P99)
- 延遲分解 (上游 vs APISIX)
- 各狀態碼的吞吐量
- 快取命中率
- 快取狀態分布
- 響應大小分布
- 請求/響應主體大小
- 頻寬使用
- 延遲熱圖

**適用場景**: 效能優化與快取效率分析

---

## 🎯 APISIX 核心監控指標

### 請求指標
```
apisix_http_status               # 按狀態碼、路由分類的請求計數
apisix_http_latency_bucket       # 請求延遲直方圖
  - type="request"               # 總請求延遲
  - type="upstream"              # 上游服務延遲
  - type="apisix"                # APISIX 內部處理延遲
```

### 連線指標
```
apisix_nginx_http_current_connections
  - state="active"               # 活躍連線
  - state="waiting"              # 等待連線
  - state="reading"              # 讀取中連線
  - state="writing"              # 寫入中連線
```

### 頻寬指標
```
apisix_bandwidth
  - type="ingress"               # 入站流量
  - type="egress"                # 出站流量
```

### 健康指標
```
apisix_etcd_reachable            # etcd 連線狀態 (1=健康, 0=不健康)
apisix_etcd_modify_indexes       # etcd 修改追蹤
apisix_upstream_status           # 上游健康狀態
```

### 記憶體與資源指標
```
apisix_shared_dict_capacity_bytes      # Shared Dict 容量
apisix_shared_dict_free_space_bytes    # Shared Dict 可用空間
apisix_node_info                       # 節點元數據
```

### 憑證指標
```
apisix_ssl_certs                 # SSL 憑證到期時間
```

---

## 📦 部署架構

### 自動化部署流程

```mermaid
graph LR
    A[Dashboard JSON] --> B[Kustomize]
    B --> C[ConfigMap]
    C --> D[Grafana Sidecar]
    D --> E[Auto Import]
    E --> F[Grafana UI]
```

### Kustomize 配置

所有儀表板透過 `kustomization.yaml` 自動生成 ConfigMap：

```yaml
configMapGenerator:
  - name: grafana-dashboard-apisix-node-metrics
    files:
      - apisix-node-metrics.json
    options:
      labels:
        grafana_dashboard: "1"     # Grafana Sidecar 自動發現
      annotations:
        grafana_folder: "GitOps Canary"
```

### 監控堆疊整合

```
APISIX (9091)
    ↓ metrics
ServiceMonitor (15s interval)
    ↓ scrape
Prometheus (observability namespace)
    ↓ query
Grafana Dashboards
    ↓ traces
Tempo (via OTEL Collector)
```

---

## 🔧 APISIX Prometheus 插件配置

在 `gitops/apisix/values.yaml` 中已啟用：

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
      prefer_name: true    # 使用路由名稱而非 ID
```

---

## 📊 儀表板統計

| 類別 | 數量 | 儀表板 |
|------|------|--------|
| **總覽與健康** | 2 | Overview, Node Metrics |
| **路由與流量** | 2 | Route Metrics, Canary Traffic |
| **效能與快取** | 1 | Performance & Cache |
| **後端服務** | 1 | Upstream Health |
| **安全防護** | 2 | Security & Rate Limiting, SSL/TLS |
| **插件與擴展** | 1 | Plugin Metrics |
| **底層系統** | 1 | Nginx/OpenResty |
| **應用層** | 1 | Spring Boot |
| **總計** | **11** | 全方位監控覆蓋 |

---

## 🎓 使用指南

### 維運人員
1. 從 **APISIX Overview** 開始，查看整體系統健康
2. 使用 **Route Metrics** 檢查特定路由
3. 透過 **Upstream Health** 監控後端服務
4. 查看 **Security & Rate Limiting** 進行安全檢查

### 開發人員
1. 使用 **Performance & Cache** 進行效能分析
2. 查看 **Spring Boot Metrics** 了解應用狀態
3. 透過 **Canary Traffic** 追蹤分散式追蹤

### 安全團隊
1. 監控 **Security & Rate Limiting** 查看安全事件
2. 檢查 **SSL/TLS & Certificates** 掌握憑證狀態
3. 審查認證失敗率

### SRE 團隊
1. 使用 **Node Metrics** 進行容量規劃
2. 查看 **Nginx/OpenResty Metrics** 了解資源使用
3. 分析 **Plugin Metrics** 優化插件效能

---

## ✅ 功能特色

### ✨ 完整覆蓋
- 從應用層到基礎設施的全棧監控
- 涵蓋安全、效能、健康三大面向
- 支援金絲雀部署專用監控

### 🚀 自動化
- ConfigMap 自動生成
- Grafana Sidecar 自動發現
- 無需手動導入儀表板

### 📈 生產就緒
- 遵循 Grafana 最佳實踐
- 合理的閾值設定
- 清晰的視覺化呈現

### 🔗 深度整合
- Prometheus 指標
- Tempo 分散式追蹤
- OTEL Collector 整合

---

## 🛠️ 故障排除

### 儀表板沒有資料

1. 檢查 APISIX 指標端點：
```bash
kubectl port-forward -n ingress-apisix svc/apisix 9091:9091
curl http://localhost:9091/apisix/prometheus/metrics
```

2. 驗證 ServiceMonitor：
```bash
kubectl get servicemonitor -n observability
kubectl describe servicemonitor apisix -n observability
```

3. 檢查 Prometheus targets：
   - 開啟 Prometheus UI → Status → Targets
   - 尋找 `apisix` 端點
   - 確認狀態為 "UP"

### 部分指標缺失

某些指標需要特定插件或配置：
- **SSL 指標**: 需要啟用 HTTPS/TLS 路由
- **快取指標**: 需要 proxy-cache 插件
- **插件指標**: 需要啟用對應插件
- **上游指標**: 需要配置上游健康檢查

---

## 📚 參考資料

- [APISIX Prometheus 插件文檔](https://apisix.apache.org/zh/docs/apisix/plugins/prometheus/)
- [APISIX OpenTelemetry 插件](https://apisix.apache.org/zh/docs/apisix/plugins/opentelemetry/)
- [Grafana 儀表板最佳實踐](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)

---

## 🎉 總結

本次更新為 GitOps-APISIX-Canary 項目新增了 **7 個專業級 Grafana 儀表板**，使 APISIX 監控能力提升到企業級水準：

✅ **11 個儀表板** 全方位覆蓋
✅ **60+ 個監控面板** 深入洞察
✅ **生產就緒** 可立即使用
✅ **自動化部署** 零手動操作
✅ **完整中英文文檔** 詳盡說明

現在您擁有完整的 APISIX 可觀測性解決方案！
