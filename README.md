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

### 3. 安裝 APISIX (含 Ingress Controller)

```bash
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install apisix apisix/apisix \
  -n ingress-apisix --create-namespace \
  -f gitops/apisix/values.yaml
```

### 4. 安裝可觀測性堆疊

```bash
# kube-prometheus-stack (Prometheus + Grafana)
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

### 5. 部署 ArgoCD Root App

```bash
kubectl apply -f gitops/root-app.yaml
```

### 6. 建置並推送 Spring Boot 映像

```bash
cd app
ACR_LOGIN_SERVER=$(az acr show --name acrgitopscanaryc31ba2 --query loginServer -o tsv)
az acr login --name acrgitopscanaryc31ba2
docker build -t ${ACR_LOGIN_SERVER}/spring-demo:v1 .
docker push ${ACR_LOGIN_SERVER}/spring-demo:v1
```

更新 `gitops/spring-boot/deployment-stable.yaml` 和 `deployment-canary.yaml` 中的 `<ACR_LOGIN_SERVER>`。

### 7. 上傳 OPA Bundle

```bash
export STORAGE_ACCOUNT=stgitopscanarya395e3
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
# Step 1: 部署 canary (scale up canary deployment)
kubectl scale deployment spring-boot-canary -n app --replicas=1

# Step 2: 10% 流量到 canary
kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix &
./scripts/canary-switch.sh --stable 90 --canary 10

# Step 3: 觀察 Grafana "Canary Traffic Split" dashboard 5-10 分鐘

# Step 4: 增加到 50%
./scripts/canary-switch.sh --stable 50 --canary 50

# Step 5: 全面切換
./scripts/canary-switch.sh --stable 0 --canary 100

# Step 6: 完成後，更新 stable deployment image，重置 weight
./scripts/canary-switch.sh --stable 100 --canary 0
kubectl scale deployment spring-boot-canary -n app --replicas=0
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

## 需要替換的 placeholder

部署前需替換以下佔位符：

| 檔案 | Placeholder | 替換為 |
|------|------------|--------|
| `gitops/spring-boot/deployment-stable.yaml` | `<ACR_LOGIN_SERVER>` | ACR login server |
| `gitops/spring-boot/deployment-canary.yaml` | `<ACR_LOGIN_SERVER>` | ACR login server |
| `gitops/opa/configmap-opa-config.yaml` | `<STORAGE_ACCOUNT>` | Storage account name |
| `gitops/opa/deployment.yaml` | `<OPA_CLIENT_ID>` | OPA Managed Identity client ID |
