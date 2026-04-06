# 🎤 當金絲雀遇上可觀測性：APISIX + OPA + OTel 打造企業級安全佈署

> **可觀測性研討會** — 40 分鐘演講  
> 講者簡報規劃與議程大綱

---

## 📋 議程總覽

| 段落 | 內容 | 時間 | 投影片 |
|------|------|------|--------|
| 第一段 | 開場 + 問題定義 + 架構總覽 | 5 分鐘 | #1 ~ #4 |
| 第二段 | APISIX + OPA + OTel 背景技術 | 7 分鐘 | #5 ~ #7 |
| 第三段 | Preview / Stable 觀測 + Dashboard | 8 分鐘 | #8 ~ #11 |
| 第四段 | 漸進式擴散 + 決策指標 + Alert | 8 分鐘 | #12 ~ #14 |
| 第五段 | OTel / Prometheus / Kibana 整合 | 5 分鐘 | #15 ~ #16 |
| 第六段 | 業界最佳實踐 + 方案比較 | 5 分鐘 | #17 ~ #18 |
| 第七段 | 總結 + Q&A | 2 分鐘 | #19 ~ #20 |
| **合計** | | **40 分鐘** | **20 張** |

---

## 第一段：開場與問題定義 (5 分鐘)

### 投影片 1 — 封面 (30 秒)

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   當金絲雀遇上可觀測性                                │
│   APISIX + OPA + OTel 打造企業級安全佈署              │
│                                                     │
│   ──────────────────────────────                    │
│   可觀測性研討會                                      │
│   講者：[Your Name]                                  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

### 投影片 2 — 你遇過這些問題嗎？ (2 分鐘)

**痛點場景驅動**

> 🔥 「週五下午部署了新版本，全公司使用者同時踩到 bug」

> 🔥 「工程師凌晨三點被叫起來，想切回穩定版卻操作錯誤，事故擴大」

> 🔥 「明明有金絲雀佈署，但事故發生時沒人知道 canary 比 stable 的錯誤率高了 5 倍」

**核心問題**

> 💡 **佈署不是問題，看不見才是問題**

**演講開場鉤子建議**

> 「上個月，我們團隊部署了一個看似無害的版本更新。金絲雀佈署已經設定好了，但沒有人注意到 canary 版本的 P95 延遲已經飆到了 3 秒。直到 50% 的使用者被切過去，客服電話才瘋狂響起⋯⋯」

---

### 投影片 3 — 今天的三個核心命題 (1.5 分鐘)

```
1️⃣  如何讓「對的人」先測試新版本？
    → OPA 策略驅動路由

2️⃣  如何在事故發生前就「看到」問題？
    → 可觀測性 (Metrics + Traces + Logs)

3️⃣  如何用數據驅動佈署決策，而非靠直覺？
    → 漸進式金絲雀 + SLO Metrics
```

---

### 投影片 4 — 架構總覽 (1 分鐘)

```
Internet
   │
   ▼
┌──────────────────────────────────────────────────┐
│                 APISIX Gateway                   │
│  ┌──────────┐ ┌──────────┐ ┌────────────────┐   │
│  │   OPA    │ │   OTel   │ │  Prometheus    │   │
│  │ (策略決策)│ │ (追蹤)   │ │  (指標)        │   │
│  └──────────┘ └──────────┘ └────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │         Traffic Split (流量分配)           │   │
│  └──────────────────────────────────────────┘   │
└──────────────┬───────────────────┬───────────────┘
               │                   │
     ┌─────────▼────────┐ ┌───────▼──────────┐
     │  Spring Boot v1  │ │  Spring Boot v2  │
     │    (stable)      │ │    (canary)      │
     └─────────┬────────┘ └───────┬──────────┘
               │                   │
               ▼                   ▼
┌──────────────────────────────────────────────────┐
│              Observability Stack                  │
│  Prometheus ──→ Grafana ←── Tempo ←── OTel       │
│             11 Dashboards    Traces   Collector   │
└──────────────────────────────────────────────────┘

Control Plane: ArgoCD (GitOps) ← watches this repo
```

**強調**：所有配置都在 Git 裡，ArgoCD 自動同步

---

## 第二段：背景技術介紹 — APISIX + OPA + OTel (7 分鐘)

### 投影片 5 — 為什麼選 APISIX？ (2 分鐘)

**APISIX 核心優勢**

| 特點 | 說明 |
|------|------|
| 高效能 | 基於 Nginx/OpenResty，高併發低延遲 |
| 原生插件支援 | `traffic-split`、`prometheus`、`opentelemetry`、`opa` |
| 動態配置 | Admin API 可即時調整 upstream 權重，**不需重啟** |
| 豐富生態 | 80+ 個插件，涵蓋安全、限流、認證、可觀測性 |

**APISIX vs Nginx Ingress**

| 功能 | APISIX | Nginx Ingress |
|------|--------|---------------|
| 金絲雀切換 | Admin API 一個呼叫即可 | annotation + 重新 apply |
| OPA 整合 | 原生插件 | 需要額外 sidecar |
| OpenTelemetry | 原生插件 | 需要額外配置 |
| 動態配置 | ✅ 不需重啟 | ❌ 需要 reload |

**本架構使用的 APISIX 插件配置**

```yaml
# gitops/apisix/apisix-route.yaml
plugins:
  - name: prometheus        # 路由層指標
  - name: opentelemetry     # 分散式追蹤
  - name: opa               # OPA 策略決策
    config:
      host: "http://opa.opa-system:8181"
      policy: "apisix/canary"
```

---

### 投影片 6 — OPA 在金絲雀佈署中的角色 (2.5 分鐘)

**OPA = Open Policy Agent → 策略即程式碼**

```rego
# opa/policy/canary.rego — 核心邏輯

package apisix.canary

# Header-based: QA 團隊帶 x-canary header 進行測試
canary_by_header if {
    input.request.headers["x-canary"] == "true"
}

# Cookie-based: 內部員工透過 cookie 體驗新版
canary_by_cookie if {
    cookie := input.request.headers.cookie
    contains(cookie, "canary=true")
}

# 路由決策
route_target := "canary" if { canary_by_header }
route_target := "canary" if { canary_by_cookie }
route_target := "stable" if { not canary_by_header; not canary_by_cookie }

# 回傳決策結果 (APISIX 加入 header)
result := {
    "allow": true,
    "headers": {"x-route-to": route_target},
}
```

**實際應用場景**

| 場景 | 做法 | 效果 |
|------|------|------|
| QA 測試 | 帶 `x-canary: true` header | 直接路由到 preview |
| 內部員工 | 設定 `canary=true` cookie | 優先體驗新版 |
| 微服務整合測試 | 服務間呼叫附帶 header | 整條鏈路走 canary |
| 一般使用者 | 無特殊 header/cookie | 走 stable 版本 |

**OPA Bundle 更新流程**

```
Rego 策略更新 → CI/CD 打包 bundle.tar.gz → Azure Blob Storage
                                                    ↓
                              OPA 每 30-60 秒自動拉取 → 策略生效
```

---

### 投影片 7 — OpenTelemetry 在這個架構中的定位 (2.5 分鐘)

**追蹤架構**

```
APISIX                 Spring Boot               OTel Collector
┌──────────┐          ┌───────────┐             ┌────────────┐
│ OTel     │  ──→     │ OTel Java │   ──→       │            │
│ Plugin   │          │ Agent     │             │  Receivers  │
│          │          │ (自動注入) │             │  (4317/4318)│
└──────────┘          └───────────┘             │            │
                                                │  Processors │
                                                │  (batch)    │
                                                │            │
                                                │  Exporters  │
                                                │  ├→ Tempo   │
                                                │  └→ Prom    │
                                                └────────────┘
```

**關鍵設計**

| 元件 | service.name | environment |
|------|-------------|-------------|
| Stable | `demo-api-stable` | `production` |
| Canary | `demo-api-canary` | `canary` |

→ Trace 中可以清楚區分版本，不用猜是哪個版本的請求

**Spring Boot OTel Agent — 零侵入**

```dockerfile
# app/Dockerfile — 自動注入 OTel Java Agent
ARG OTEL_AGENT_VERSION=2.12.0
ADD https://github.com/.../opentelemetry-javaagent.jar /otel-agent.jar

ENV JAVA_TOOL_OPTIONS="-javaagent:/otel-agent.jar"
ENV OTEL_SERVICE_NAME="demo-api"
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector.observability:4318"
```

→ 不需要改一行 Java 程式碼，trace 自動產生

---

## 第三段：Preview / Stable 架構如何觀測 (8 分鐘)

### 投影片 8 — 雙版本並行：Preview / Stable 的架構 (2 分鐘)

**Kubernetes 部署架構**

```
                    Namespace: app
┌──────────────────────────────────────────────────┐
│                                                  │
│  Deployment: spring-boot-stable (replicas: 2)    │
│  ├─ APP_VERSION=v1                               │
│  ├─ OTEL_SERVICE_NAME=demo-api-stable            │
│  └─ Service: spring-boot-stable:8080             │
│                                                  │
│  Deployment: spring-boot-canary (replicas: 2)    │
│  ├─ APP_VERSION=v2                               │
│  ├─ OTEL_SERVICE_NAME=demo-api-canary            │
│  └─ Service: spring-boot-canary:8080             │
│                                                  │
└──────────────────────────────────────────────────┘
```

**流量控制雙層架構**

```
Layer 1 — OPA 策略路由 (精確控制)
  x-canary: true → canary
  canary=true cookie → canary
  預設 → stable

Layer 2 — APISIX 權重路由 (比例控制)
  stable: weight 100 ──→ 100% 流量
  canary: weight   0 ──→   0% 流量
  (透過 Admin API 動態調整)
```

**展示效果**

```bash
# 一般使用者 → stable
$ curl http://$LB_IP/api/hello
{"message":"Hello from v1","version":"v1",...}

# QA 帶 header → canary
$ curl -H "x-canary: true" http://$LB_IP/api/hello
{"message":"Hello from v2","version":"v2",...}

# 內部員工帶 cookie → canary
$ curl -b "canary=true" http://$LB_IP/api/hello
{"message":"Hello from v2","version":"v2",...}
```

---

### 投影片 9 — 事故場景：沒有可觀測性的金絲雀 (2 分鐘)

**🚨 事故時間軸**

```
14:00  工程師部署 canary v2
       ✅ ArgoCD 自動同步，canary pods 啟動

14:05  工程師想漸進式切 10% 流量
       ❌ 操作失誤：canary-switch.sh --stable 0 --canary 100
       → 一次全切，100% 流量走 canary

14:06  v2 有 bug，回應延遲飆升至 5 秒
       ❌ 沒有 dashboard → 沒人看到

14:10  5xx 錯誤率攀升至 30%
       ❌ 沒有 alert → 沒人收到通知

14:25  使用者大量回報 → 客服升級
       ❌ 慢了 20 分鐘才知道

14:30  工程師手動回滾
       → 事故持續 25 分鐘，影響全部使用者
```

**教訓**

> 🔑 **金絲雀佈署 ≠ 安全佈署**
>
> 沒有可觀測性的金絲雀，是盲人開車 🚗💨

**如果有可觀測性呢？**

```
14:05  切換 100% canary（操作錯誤）
14:06  Grafana Dashboard 即時顯示延遲飆升 ⚠️
14:07  Prometheus Alert 觸發：CanaryHighLatency 🔔
14:08  工程師收到 Slack 告警，執行回滾
       → 事故持續 3 分鐘，只影響 canary 流量
```

---

### 投影片 10 — 11 個 Grafana Dashboard 全景 (2 分鐘)

**Dashboard 分類總覽**

| 類別 | # | Dashboard | 用途 | 主要使用者 |
|------|---|-----------|------|-----------|
| 全局總覽 | 1 | APISIX Overview | 整體 QPS、延遲、錯誤率、連線數 | SRE |
| 路由分析 | 2 | Route Metrics | 每個路由的效能比較 | 開發/SRE |
| **🔥 金絲雀** | **3** | **Canary Traffic Split** | **stable vs canary 全面對比** | **全員** |
| 節點指標 | 4 | Node Metrics | Worker 進程、記憶體、etcd 同步 | SRE |
| 後端健康 | 5 | Upstream Health | 上游服務可用性、延遲 | SRE |
| 安全防護 | 6 | Security & Rate Limiting | 429/403/401 事件 | 安全團隊 |
| SSL 憑證 | 7 | SSL/TLS & Certificates | 憑證到期、握手統計 | 安全團隊 |
| 插件指標 | 8 | Plugin Metrics | OTel/OPA/Prometheus 插件效能 | 開發 |
| 系統底層 | 9 | Nginx/OpenResty | Worker、連線、LuaJIT 記憶體 | SRE |
| 效能快取 | 10 | Performance & Cache | 延遲百分位、快取命中率 | 開發 |
| 應用指標 | 11 | Spring Boot Metrics | JVM、GC、HTTP Duration | 開發 |

**部署方式（全自動）**

```
Dashboard JSON → Kustomize → ConfigMap → Grafana Sidecar → 自動匯入
                 (label: grafana_dashboard=1)
```

---

### 投影片 11 — 重點 Dashboard：Canary Traffic Split (2 分鐘)

**🎯 這是這場演講的核心 Dashboard**

```
┌──────────────────────────────────────────────────────────────┐
│                   Canary Traffic Split                        │
├──────────────┬──────────────┬────────────────────────────────┤
│  🥧 流量比例  │  📊 即時 QPS  │  ⏱️ 延遲比較                    │
│              │              │                                │
│   stable     │  stable ───  │  P50: stable ─── canary ───   │
│    72%       │  canary ···  │  P95: stable ─── canary ───   │
│   canary     │              │  P99: stable ─── canary ───   │
│    28%       │              │                                │
├──────────────┴──────────────┴────────────────────────────────┤
│  ❌ 錯誤率對比                │  🔗 Tempo 追蹤連結              │
│                              │                               │
│  stable 5xx: 0.1% ──        │  [View Traces in Tempo]       │
│  canary 5xx: 0.3% ···       │  service.name = demo-api-*    │
│                              │                               │
└──────────────────────────────┴───────────────────────────────┘
```

**核心 Prometheus 查詢**

```promql
# 金絲雀錯誤率
sum(rate(apisix_http_status{route=~".*canary.*", code=~"5.."}[5m]))
  / sum(rate(apisix_http_status{route=~".*canary.*"}[5m])) * 100

# 延遲比較 (P95)
histogram_quantile(0.95,
  sum(rate(apisix_http_latency_bucket{type="request", route=~".*canary.*"}[5m])) by (le)
)

# 流量分配比例
sum(rate(apisix_http_status{route=~".*canary.*"}[5m]))
  / sum(rate(apisix_http_status[5m])) * 100
```

**Demo 建議** (如果時間允許，在此處安排 1-2 分鐘 Live Demo)
1. 呼叫 API → 展示 stable 回應
2. 帶 `x-canary: true` header → 展示 canary 回應
3. 執行 `canary-switch.sh` 切換權重 → Dashboard 即時變化

---

## 第四段：漸進式擴散 — 降低 Production 事故機率 (8 分鐘)

### 投影片 12 — 漸進式金絲雀佈署流程 (3 分鐘)

**時間軸圖**

```
時間        stable%    canary%    動作
──────────────────────────────────────────────────────────
T+0min      100%       0%        🔒 OPA 僅允許內部測試者走 canary
                                  → QA 帶 x-canary header 測試

T+10min      90%      10%        📊 觀察 Dashboard 10 分鐘
                                  → 確認延遲、錯誤率正常

T+20min      50%      50%        ⚖️ 對比觀察，設定 Alert
                                  → stable vs canary 指標並排比較

T+30min       0%     100%        ✅ 全量切換
                                  → 持續監控 5 分鐘

Rollback    100%       0%        🚨 任何時刻一鍵回滾
(任何時刻)                        → canary-switch.sh --stable 100 --canary 0
```

**操作指令**

```bash
# 每一步只需一個指令
./scripts/canary-switch.sh --stable 90 --canary 10

# 背後原理：
# PATCH http://apisix-admin:9180/apisix/admin/upstreams/canary-upstream
# → 即時生效，不需重啟、不需 redeploy
```

**關鍵原則**

| 原則 | 說明 |
|------|------|
| 🔍 先看再切 | 每次增加流量前，確認 Dashboard 指標正常 |
| ⏸️ 延遲異常就暫停 | canary P95 > stable P95 × 1.5 → 暫停 |
| 🔙 錯誤就回滾 | canary 5xx > 1% → 立即回滾 |
| ⏱️ 留觀察時間 | 每階段至少觀察 10 分鐘 |

---

### 投影片 13 — 決策指標：什麼時候該停？什麼時候該進？ (2.5 分鐘)

**決策矩陣**

| 指標 | 🟢 安全 (綠燈) | 🟡 警告 (黃燈) | 🔴 危險 (紅燈 = 回滾) |
|------|---------------|---------------|---------------------|
| P95 延遲 | < 200ms | 200ms ~ 1000ms | > 1000ms |
| 5xx 錯誤率 | < 1% | 1% ~ 5% | > 5% |
| Canary vs Stable 延遲差 | < 20% | 20% ~ 50% | > 50% |
| OPA 策略錯誤 | 0 | > 0 | 持續增加 |

**對應 Prometheus Alert Rules**

```yaml
# gitops/observability/alerting/canary-alerts.yaml

# 🔴 Canary 錯誤率過高
- alert: CanaryHighErrorRate
  expr: |
    sum(rate(apisix_http_status{route=~".*canary.*", code=~"5.."}[5m]))
    / sum(rate(apisix_http_status{route=~".*canary.*"}[5m])) > 0.05
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Canary 5xx 錯誤率超過 5%"
    runbook: "執行 ./scripts/canary-switch.sh --stable 100 --canary 0"

# 🔴 Canary 延遲過高
- alert: CanaryHighLatency
  expr: |
    histogram_quantile(0.95,
      sum(rate(apisix_http_latency_bucket{type="request",
        route=~".*canary.*"}[5m])) by (le)) > 1000
  for: 3m
  labels:
    severity: critical
  annotations:
    summary: "Canary P95 延遲超過 1 秒"
    runbook: "執行 ./scripts/canary-switch.sh --stable 100 --canary 0"
```

→ 這些閾值即是 Prometheus Alerting Rules 的設定依據

---

### 投影片 14 — Alert 的角色 (2.5 分鐘)

**告警規則總覽**

| Alert 名稱 | 條件 | 持續時間 | 嚴重性 |
|------------|------|---------|--------|
| `CanaryHighErrorRate` | canary 5xx > 5% | 2 分鐘 | 🔴 critical |
| `CanaryHighLatency` | canary P95 > 1s | 3 分鐘 | 🔴 critical |
| `CanaryTrafficAnomaly` | canary 流量突然歸零或暴增 | 1 分鐘 | 🟡 warning |
| `UpstreamUnhealthy` | upstream 健康檢查失敗 | 1 分鐘 | 🔴 critical |
| `CanaryLatencyDrift` | canary 延遲 > stable × 1.5 | 5 分鐘 | 🟡 warning |

**告警管道**

```
Prometheus AlertManager
    ├─ Slack        → #deploy-alerts 頻道
    ├─ PagerDuty    → On-call 工程師
    ├─ Teams        → 團隊通知
    ├─ Email        → 管理層摘要
    └─ Webhook      → 自動回滾腳本 (進階)
```

**重點：告警要 Actionable**

每個 Alert 都要回答：
1. 📌 **什麼壞了？** — Canary 延遲飆升
2. 📌 **影響是什麼？** — 10% 使用者體驗下降
3. 📌 **該怎麼做？** — 執行 `canary-switch.sh --stable 100 --canary 0`

→ 告警不是通知，是**行動指令**

---

## 第五段：OTel + Prometheus + Alert + Kibana 如何應用 (5 分鐘)

### 投影片 15 — 可觀測性三支柱在本架構的對應 (2.5 分鐘)

**三支柱對應表**

| 支柱 | 工具 | 資料來源 | 用途 |
|------|------|---------|------|
| **Metrics** | Prometheus + Grafana | APISIX prometheus plugin, Spring Boot Actuator, OTel Collector | QPS、延遲、錯誤率、JVM 狀態 |
| **Traces** | OTel + Tempo + Grafana | APISIX OTel plugin, Spring Boot OTel Agent | 請求鏈路追蹤，找出瓶頸 |
| **Logs** | EFK/ELK (Kibana) | Spring Boot 日誌, APISIX 存取日誌 | 錯誤詳情、除錯分析 |

**Kibana 在本架構的角色**

本 repo 聚焦 Metrics + Traces，完整架構建議搭配 EFK Stack：

| 功能 | Kibana 做法 |
|------|------------|
| 區分版本日誌 | 按 `x-route-to` header 篩選 stable vs canary |
| 鏈路除錯 | 按 trace-id 搜尋完整鏈路日誌 |
| 錯誤告警 | Watcher 監控 canary 錯誤日誌頻率 |
| 日誌分析 | 比對 stable/canary 的錯誤模式差異 |

**日誌收集路徑**

```
APISIX access log    → Filebeat → Elasticsearch → Kibana
Spring Boot stdout   → Fluentd  → Elasticsearch → Kibana
```

---

### 投影片 16 — 資料流全景圖 (2.5 分鐘)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        資料流全景圖                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [APISIX Gateway]                                                   │
│     ├─ prometheus plugin ──→ Prometheus ──→ Grafana Dashboard       │
│     ├─ OTel plugin ────────→ OTel Collector ──→ Tempo               │
│     │                              │              └──→ Grafana Trace │
│     │                              └──→ Prometheus (span metrics)   │
│     └─ access log ─────────→ Filebeat ──→ Elasticsearch ──→ Kibana  │
│                                                                     │
│  [Spring Boot Stable/Canary]                                        │
│     ├─ actuator/prometheus ──→ Prometheus ──→ Grafana Dashboard     │
│     ├─ OTel Java Agent ─────→ OTel Collector ──→ Tempo              │
│     └─ stdout log ──────────→ Fluentd ──→ Elasticsearch ──→ Kibana  │
│                                                                     │
│  [Prometheus AlertManager]                                          │
│     └─ Alert Rules ──→ Slack / PagerDuty / 回滾腳本觸發             │
│                                                                     │
│  [OTel Collector] (中樞)                                             │
│     ├─ Receivers: OTLP (gRPC 4317, HTTP 4318)                      │
│     ├─ Processors: memory_limiter, batch                            │
│     └─ Exporters: Tempo (traces), Prometheus (metrics), debug       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 第六段：業界最佳實踐 (5 分鐘)

### 投影片 17 — 金絲雀佈署 + 可觀測性：8 大最佳實踐 (3 分鐘)

| # | 實踐 | 說明 |
|---|------|------|
| 1 | **GitOps First** | 所有配置版本化，ArgoCD 自動同步，可審計可回溯 |
| 2 | **Policy as Code** | OPA 策略也走 CI/CD，變更有 review、有測試、有紀錄 |
| 3 | **漸進式佈署** | 永遠不要一次性 0→100%，最少三階段 (10% → 50% → 100%) |
| 4 | **SLO-driven Rollout** | 用 SLI/SLO 指標（延遲、錯誤率）決定是否繼續佈署 |
| 5 | **自動回滾** | 結合 Prometheus Alert + Webhook，錯誤率超標自動觸發回滾 |
| 6 | **Trace-based Testing** | 在 canary 階段利用 distributed tracing 比對新舊版本行為差異 |
| 7 | **Dashboard as Runbook** | Dashboard 不只是看的，要附帶 SOP：指標異常 → 該做什麼操作 |
| 8 | **Chaos Engineering** | 定期在 canary 階段注入故障，驗證可觀測性和告警是否正常運作 |

---

### 投影片 18 — 與業界方案比較 (2 分鐘)

| 方案 | 特色 | 可觀測性整合 | 複雜度 |
|------|------|-------------|--------|
| Argo Rollouts | K8s 原生、自動 progressive delivery | 支援 Prometheus Analysis | 中 |
| Flagger | 搭配 Istio/Linkerd，自動金絲雀 | 內建 metric check | 中高 |
| Istio + Kiali | Service Mesh 方案 | 完整但複雜度高 | 高 |
| **本架構** | **策略驅動、閘道層控制** | **完整 Metrics + Traces** | **中低** |

**本架構的差異化優勢**

```
✅ 不需要 Service Mesh → 降低複雜度與資源消耗
✅ OPA 提供比 annotation 更靈活的路由策略
✅ 閘道層觀測 + 應用層觀測 → 雙管齊下
✅ Admin API 動態切換 → 不需重新部署
✅ 11 個 Dashboard → 企業級全方位監控
✅ GitOps → 所有操作可追溯
```

---

## 第七段：總結與 Q&A (2 分鐘)

### 投影片 19 — 關鍵帶走訊息 (Key Takeaways) (1.5 分鐘)

```
1. ✅ 金絲雀佈署不難，難的是看見它
     → 沒有可觀測性的金絲雀等於盲人開車

2. ✅ OPA 讓你精準控制誰先走新路
     → 不再是「全部使用者一起賭」

3. ✅ 漸進式擴散 + SLO 閾值 = 數據驅動的佈署決策
     → 讓指標說話，不靠直覺

4. ✅ Metrics + Traces + Logs 三支柱缺一不可
     → Prometheus / Tempo / Kibana 各司其職

5. ✅ Dashboard 是你的佈署 Runbook
     → 看板上的每個面板都要有對應的操作 SOP

6. ✅ GitOps 確保可重現性
     → 所有操作都有紀錄，出事能追溯
```

---

### 投影片 20 — 資源連結 & QR Code (30 秒)

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   📦 GitHub Repository                              │
│   github.com/matsurigoto/GitOps-APISIX-Canary       │
│   [QR Code]                                         │
│                                                     │
│   📚 參考資料                                        │
│   • APISIX: apisix.apache.org                       │
│   • OPA: openpolicyagent.org                        │
│   • OpenTelemetry: opentelemetry.io                 │
│   • Grafana Tempo: grafana.com/oss/tempo            │
│                                                     │
│   💬 聯繫講者                                        │
│   [Your contact info]                               │
│                                                     │
│   🙏 感謝聆聽！Questions?                            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 📊 簡報設計建議

### 風格建議
- **深色主題** — 符合工程師審美，也適合投影
- 大量使用**架構圖**和**流程圖**（Mermaid 或 draw.io）
- Dashboard 截圖使用**真實 Grafana 畫面**（搭配 job-caller 產生測試流量）
- 程式碼片段使用**語法高亮**，字體夠大（最小 18pt）

### 每張投影片的原則
- 一張投影片 = 一個概念
- 關鍵數字放大（如「11 個 Dashboard」、「30 秒策略更新」）
- 使用紅/黃/綠色標示閾值（與 Grafana dashboard 一致）
- 避免滿版文字，善用圖表和表格

### 核心敘事弧

```
痛點出發 → 展示架構 → 解釋每一層如何解決問題 → Dashboard/Metrics 驗證 → 最佳實踐收尾
```

> 這條敘事弧讓聽眾始終知道「為什麼要聽這些」，而不只是技術堆疊介紹。

### Demo 建議
在投影片 #11 和 #12 之間安排 1-2 分鐘的 **Live Demo 或預錄影片**：

1. 呼叫 API → 展示 stable 回應
2. 帶 `x-canary: true` header → 展示 canary 回應
3. 執行 `canary-switch.sh` 切換權重
4. Grafana Canary Traffic Split Dashboard 即時變化
5. (進階) 觸發一個錯誤 → 展示 Alert 通知
