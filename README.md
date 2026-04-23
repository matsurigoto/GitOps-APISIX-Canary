# GitOps-APISIX-Canary

AKS + ArgoCD GitOps 環境，使用 APISIX 作為 API Gateway，搭配 OPA 實現金絲雀/藍綠部署，完整可觀測性堆疊（Prometheus + Grafana + OpenTelemetry + Tempo）。

## 架構總覽

```
Internet → APISIX (LB) → Spring Boot v1 (stable) / v2 (canary)
                │
                ├─ OPA (policy decision: header-based canary)
                ├─ Prometheus (metrics)
                ├─ OTel Collector → Tempo (traces)
                └─ Grafana (dashboards + trace correlation)

ArgoCD (GitOps) ← watches this repo
OPA ← bundles from Azure Blob Storage
Admin API ← dynamic canary weight switching
```

## 目錄結構

```
├── infra/setup-azure.sh              # Azure 基礎設施 (AKS, ACR, Blob Storage)
├── app/                               # Spring Boot 應用程式原始碼
├── opa/policy/                        # OPA Rego 策略 (金絲雀 + 藍綠)
├── scripts/                           # 操作腳本 (canary switch, bundle upload)
├── .github/workflows/                 # CI/CD (build & push, OPA bundle)
└── gitops/                            # ArgoCD GitOps 資源
    ├── root-app.yaml                  # App-of-Apps (ApplicationSet)
    ├── argocd/                        # ArgoCD Helm values
    ├── apisix/                        # APISIX Helm values + CRD routes
    ├── spring-boot/                   # Deployments, Services, ServiceMonitor
    ├── observability/                 # Prometheus + Grafana + OTel + Tempo
    │   └── grafana-dashboards/        # 4 dashboards (Kustomize ConfigMaps)
    ├── opa/                           # OPA deployment (Workload Identity)
    └── job-caller/                    # 持續流量產生器 (5 秒間隔)
```

## 快速開始

### 1. 建立 Azure 基礎設施

```bash
# 編輯 infra/setup-azure.sh 中的變數 (ACR_NAME, STORAGE_ACCOUNT 等)
chmod +x infra/setup-azure.sh
./infra/setup-azure.sh
```

此腳本會建立：
- Resource Group
- Azure Container Registry (ACR)
- Azure Blob Storage (OPA bundles)
- AKS Cluster (3 nodes, Workload Identity 啟用)
- OPA Managed Identity + Federated Credential

### 2. 安裝 ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f gitops/argocd/values.yaml
```

取得 ArgoCD 初始密碼：
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 3. 安裝可觀測性堆疊 (必須先於 APISIX)

```bash
# kube-prometheus-stack (Prometheus + Grafana)
# 必須先安裝以提供 ServiceMonitor CRD
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n observability --create-namespace \
  -f gitops/observability/kube-prometheus-stack/values.yaml

# OpenTelemetry Collector
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm install otel-collector open-telemetry/opentelemetry-collector \
  -n observability \
  -f gitops/observability/otel-collector/values.yaml

# Grafana Tempo
helm repo add grafana https://grafana.github.io/helm-charts
helm install tempo grafana/tempo \
  -n observability \
  -f gitops/observability/tempo/values.yaml
```

### 4. 安裝 APISIX (含 Ingress Controller)

```bash
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install apisix apisix/apisix \
  -n ingress-apisix --create-namespace \
  -f gitops/apisix/values.yaml
```

### 5. 部署 ArgoCD Root App

```bash
kubectl apply -f gitops/root-app.yaml
```

### 6. 建置並推送 Spring Boot 映像

```bash
cd app
ACR_LOGIN_SERVER=$(az acr show --name acrgitopscanary2abd47 --query loginServer -o tsv)
az acr login --name acrgitopscanary2abd47
docker build -t ${ACR_LOGIN_SERVER}/spring-demo:v1 .
docker push ${ACR_LOGIN_SERVER}/spring-demo:v1
```

更新 `gitops/spring-boot/deployment-stable.yaml` 和 `deployment-canary.yaml` 中的 `<ACR_LOGIN_SERVER>`。

### 7. 上傳 OPA Bundle

```bash
export STORAGE_ACCOUNT=stgitopscanaryd44eb2
chmod +x scripts/upload-opa-bundle.sh
./scripts/upload-opa-bundle.sh
```

### 8. 初始化 Admin API Upstream

```bash
kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix &
chmod +x scripts/init-canary-upstream.sh
./scripts/init-canary-upstream.sh
```

## 金絲雀部署操作

### 逐步金絲雀升級

```bash
# Step 0: 確保 canary pods 已部署
kubectl get pods -n app -l version=canary  # 確認 canary pods 運行中

# Step 1: 建立 port-forward（在背景執行）
kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix &
# 記錄 process ID 以便稍後關閉: $PF_PID=$!

# Step 2: 初始化 canary upstream (如果還沒有執行過)
./scripts/init-canary-upstream.sh

# Step 3: 開始時設為 100% stable
./scripts/canary-switch.sh --stable 100 --canary 0

# Step 4: 10% 流量到 canary
./scripts/canary-switch.sh --stable 90 --canary 10

# Step 4: 10% 流量到 canary
./scripts/canary-switch.sh --stable 90 --canary 10

# Step 5: 觀察 Grafana "Canary Traffic Split" dashboard 5-10 分鐘
# 檢查錯誤率、延遲、SLO 違規等指標

# Step 6: 如果指標正常，增加到 50%
./scripts/canary-switch.sh --stable 50 --canary 50

# Step 7: 繼續觀察，如果一切正常，全面切換
./scripts/canary-switch.sh --stable 0 --canary 100

# Step 8: 完成後，更新 stable deployment image，重置 weight
kubectl set image deployment/spring-boot-stable spring-boot=<ACR_LOGIN_SERVER>/spring-demo:v2 -n app
./scripts/canary-switch.sh --stable 100 --canary 0

# Step 9: 清理 - 關閉 port-forward
kill $PF_PID  # 或使用 fg 然後 Ctrl+C
```

### 📝 重要注意事項

**在進行 canary 部署前，請確保：**

1. **Canary upstream 已初始化**
   ```bash
   # 檢查 canary upstream 是否存在
   kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix &
   curl -H "X-API-KEY: gitops-canary-admin-key-2026" \
     http://127.0.0.1:9180/apisix/admin/upstreams/canary-upstream
   
   # 如果不存在或配置不正確，重新初始化
   ./scripts/init-canary-upstream.sh
   ```

2. **Port-forward 必須保持活動狀態**
   - 在所有 canary-switch 操作期間保持同一個 port-forward 連接
   - 如果連接中斷，重新建立 port-forward 後再執行命令

3. **Windows PowerShell 用戶**
   ```powershell
   # 背景執行 port-forward
   Start-Process kubectl -ArgumentList "port-forward","svc/apisix-admin","9180:9180","-n","ingress-apisix" -WindowStyle Hidden
   
   # 執行 canary switch (使用 bash/WSL)
   wsl bash -c "./scripts/canary-switch.sh --stable 90 --canary 10"
   ```

### 藍綠一鍵切換

```bash
# 切換到 green (canary)
./scripts/bluegreen-switch.sh --active green

# 切換回 blue (stable)
./scripts/bluegreen-switch.sh --active blue
```

### OPA Header-based Canary

即使 weight 是 100:0，也可以透過 header 強制路由到 canary：
```bash
# 走 stable
curl http://<APISIX_LB_IP>/api/hello

# 強制走 canary
curl -H "x-canary: true" http://<APISIX_LB_IP>/api/hello
```

## 外部存取端點

部署完成後，取得各服務的外部 IP：
```bash
kubectl get svc -A | grep LoadBalancer
```

| 服務 | Namespace | Port | 說明 |
|------|-----------|------|------|
| APISIX Gateway | ingress-apisix | 80 | API 入口 |
| Grafana | observability | 3000 | 儀表板 (admin/admin) |
| Prometheus | observability | 9090 | 指標查詢 |
| ArgoCD | argocd | 443 | GitOps 管理 |
| Spring Boot (direct) | app | 8080 | 除錯直連 |

## Grafana Dashboards

| Dashboard | 說明 |
|-----------|------|
| APISIX Overview | 總 QPS、延遲 P50/P95/P99、4xx/5xx 率、bandwidth、連線數 |
| APISIX Route Metrics | 各 Route 的 QPS、延遲分佈、HTTP 狀態碼、upstream vs apisix 延遲 |
| Canary Traffic Split | Stable vs Canary 流量對比 (pie chart)、QPS/延遲/錯誤率雙軸圖、Tempo trace 面板 |
| Spring Boot Metrics | JVM heap/non-heap、GC pause、HTTP duration、Thread count、CPU |
| SLO Dashboard | 可用性/延遲 SLI 儀表盤、Error Budget 剩餘量、多視窗 Burn Rate 趨勢 |

## GitHub Actions

| Workflow | 觸發條件 | 說明 |
|----------|---------|------|
| CI/CD | push to `main` (paths: `app/**`) | 建置 Spring Boot → 推送 ACR → 更新 GitOps manifest |
| OPA Bundle | push to `main` (paths: `opa/policy/**`) | 打包 OPA bundle → 上傳 Blob Storage |

### 需要設定的 GitHub Secrets

| Secret | 說明 |
|--------|------|
| `AZURE_CREDENTIALS` | Azure Service Principal JSON |
| `ACR_NAME` | ACR 名稱 |
| `ACR_LOGIN_SERVER` | ACR login server (xxx.azurecr.io) |
| `STORAGE_ACCOUNT` | Blob Storage 帳戶名稱 |

## 雙軌管理策略

| 管理者 | 負責內容 | 模式 |
|--------|---------|------|
| Ingress Controller (CRD/GitOps) | 路由規則 (`/api/*`)、Plugin 設定 | 宣告式、Git 版控 |
| Admin API | Upstream 節點權重 (canary 比例) | 命令式、即時生效 |
| OPA (Blob Storage bundle) | Header-based 路由決策 | 自動 polling 更新 |

## � 故障排除

### Canary Switch 失敗

**問題：** `./scripts/canary-switch.sh` 執行失敗或無效

**可能原因與解決方案：**

1. **Port-forward 未建立或已中斷**
   ```bash
   # 檢查連接
   curl -H "X-API-KEY: gitops-canary-admin-key-2026" \
     http://127.0.0.1:9180/apisix/admin/routes
   
   # 如果失敗，重新建立 port-forward
   kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix
   ```

2. **Upstream 未初始化或配置不正確**
   ```bash
   # 檢查 upstream 配置
   curl -H "X-API-KEY: gitops-canary-admin-key-2026" \
     http://127.0.0.1:9180/apisix/admin/upstreams/canary-upstream
   
   # 重新初始化
   ./scripts/init-canary-upstream.sh
   ```

3. **API Key 不匹配**
   ```bash
   # 確認 API key 設定
   echo $APISIX_ADMIN_KEY
   # 應該輸出: gitops-canary-admin-key-2026
   
   # 如果未設定，export 環境變數
   export APISIX_ADMIN_KEY="gitops-canary-admin-key-2026"
   ```

### 流量仍然到達 Canary（即使 weight=0）

**問題：** 設定 `--canary 0` 後仍有流量到達 canary 版本

**診斷步驟：**

```bash
# 1. 檢查實際的 upstream 配置
curl -H "X-API-KEY: gitops-canary-admin-key-2026" \
  http://127.0.0.1:9180/apisix/admin/upstreams/canary-upstream | jq '.value.nodes'

# 2. 檢查是否有多個路由配置
curl -H "X-API-KEY: gitops-canary-admin-key-2026" \
  http://127.0.0.1:9180/apisix/admin/routes | jq '.list[].value | select(.status==1) | {name, priority, upstream_id}'

# 3. 檢查 Ingress Controller 同步狀態
kubectl get apisixroute -n app spring-boot-canary -o yaml | grep -A5 status

# 4. 檢查 OPA 策略決策（查看最近的日誌）
kubectl logs -n opa-system -l app=opa --tail=20 | grep "route_target"
```

**解決方案：**

```bash
# 方案 1: 完全移除 canary 節點（停止所有 canary 流量）
kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix &
curl -X PUT http://127.0.0.1:9180/apisix/admin/upstreams/canary-upstream \
  -H "X-API-KEY: gitops-canary-admin-key-2026" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "canary-upstream",
    "type": "roundrobin",
    "nodes": {
      "spring-boot-stable.app:8080": 100
    }
  }'

# 方案 2: 重啟 APISIX pod（刷新配置）
kubectl delete pod -n ingress-apisix -l app.kubernetes.io/name=apisix
```

### Ingress Controller CRD 同步失敗

**問題：** ApisixRoute 顯示 `ResourceSyncAborted` 錯誤

**診斷：**

```bash
# 查看 Ingress Controller 日誌
kubectl logs -n ingress-apisix -l app.kubernetes.io/name=apisix-ingress-controller \
  --tail=50 | grep -i "error\|401\|apikey"
```

**解決方案：**

確認 [gitops/apisix/values.yaml](gitops/apisix/values.yaml) 中的 API key 配置正確：

```yaml
ingress-controller:
  config:
    apisix:
      adminKey: "gitops-canary-admin-key-2026"  # 必須與 admin.credentials.admin 一致
```

### Port-forward 在 Windows 無法正常工作

**問題：** Windows CMD/PowerShell 中 `&` 背景執行不生效

**解決方案：**

```powershell
# PowerShell: 使用 Start-Process
Start-Job -ScriptBlock {
  kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix
}

# 或開啟新的終端視窗
Start-Process powershell -ArgumentList "-NoExit","-Command","kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix"

# 檢查連接
Test-NetConnection -ComputerName 127.0.0.1 -Port 9180
```

## �📚 文件

| 文件 | 說明 |
|------|------|
| [PRESENTATION-ZH.md](PRESENTATION-ZH.md) | 🎤 演講簡報規劃 — 40 分鐘議程大綱（可觀測性研討會） |
| [docs/SPEAKER-NOTES-ZH.md](docs/SPEAKER-NOTES-ZH.md) | 📝 講者筆記 — 每張投影片的詳細講稿與 Q&A 準備 |
| [MONITORING-DASHBOARDS-ZH.md](MONITORING-DASHBOARDS-ZH.md) | 📊 Grafana 儀表板擴充說明 |
| [METRICS-QUICK-REFERENCE.md](METRICS-QUICK-REFERENCE.md) | 📈 Prometheus 指標快速參考 |

## SLO 指標

本專案實作完整的 SLO 可觀測性，基於 Google SRE Book 的多視窗 Error Budget Burn Rate 策略。

### SLO 定義

| SLO | 目標 | SLI 計算方式 |
|-----|------|--------------|
| 可用性 | 99.5% | 非 5xx 請求數 / 總請求數 |
| 延遲 | 95% 請求 < 500ms | P95 < 500ms 請求數 / 總請求數 |

### Error Budget Burn Rate 告警

| Alert | 視窗 | Burn Rate 閾值 | 嚴重性 | 意義 |
|-------|------|----------------|--------|------|
| `SLOErrorBudgetBurnRateCritical` | 1h | > 14.4x | 🔴 critical | 2 小時內耗盡 error budget |
| `SLOErrorBudgetBurnRateFast` | 6h | > 6x | 🔴 critical | 數小時內大量消耗 |
| `SLOErrorBudgetBurnRateSlow` | 3d | > 3x | 🟡 warning | 月底前可能耗盡 |
| `CanarySLOViolation` | 1h | > 10x (canary) | 🟡 warning | Canary 快速消耗 error budget |
| `SLOLatencyBudgetBurnRateCritical` | 1h | > 14.4x | 🔴 critical | 延遲 SLO 快速違規 |
| `SLOLatencyBudgetBurnRateWarning` | 6h | > 6x | 🟡 warning | 延遲 SLO 消耗偏高 |

### SLO 相關檔案

```bash
gitops/observability/alerting/slo-rules.yaml          # SLI Recording Rules + Burn Rate 告警
gitops/observability/grafana-dashboards/slo-dashboard.json  # Grafana SLO Dashboard
```

## Canary 告警規則

本專案提供 Prometheus 告警規則以增強金絲雀佈署的可觀測性：

```bash
# 告警規則檔案
gitops/observability/alerting/canary-alerts.yaml
```

| Alert | 條件 | 嚴重性 |
|-------|------|--------|
| `CanaryHighErrorRate` | Canary 5xx > 5% 持續 2 分鐘 | 🔴 critical |
| `CanaryElevatedErrorRate` | Canary 5xx > 1% 持續 5 分鐘 | 🟡 warning |
| `CanaryHighLatency` | Canary P95 > 1s 持續 3 分鐘 | 🔴 critical |
| `CanaryElevatedLatency` | Canary P95 > 500ms 持續 5 分鐘 | 🟡 warning |
| `CanaryLatencyDrift` | Canary 延遲 > Stable × 1.5 持續 5 分鐘 | 🟡 warning |
| `CanaryErrorRateDrift` | Canary 錯誤率 > Stable × 5 持續 3 分鐘 | 🔴 critical |
| `CanaryTrafficDropped` | Canary 流量突然歸零 | 🟡 warning |
| `CanaryTrafficSpike` | Canary 流量異常暴增 | 🟡 warning |
| `UpstreamUnhealthy` | 上游服務健康檢查失敗 | 🔴 critical |
| `APISIXEtcdUnreachable` | APISIX 無法連接 etcd | 🔴 critical |

## 需要替換的 placeholder

部署前需替換以下佔位符：

| 檔案 | Placeholder | 替換為 |
|------|------------|--------|
| `gitops/spring-boot/deployment-stable.yaml` | `<ACR_LOGIN_SERVER>` | ACR login server |
| `gitops/spring-boot/deployment-canary.yaml` | `<ACR_LOGIN_SERVER>` | ACR login server |
| `gitops/opa/configmap-opa-config.yaml` | `<STORAGE_ACCOUNT>` | Storage account name |
| `gitops/opa/deployment.yaml` | `<OPA_CLIENT_ID>` | OPA Managed Identity client ID |
