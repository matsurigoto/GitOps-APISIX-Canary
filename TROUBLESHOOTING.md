# 故障排除指南 (Troubleshooting Guide)

## 🔴 503 Service Temporarily Unavailable

### 問題描述
執行 `curl http://<APISIX_IP>/api/hello` 時出現 503 錯誤。

### 可能原因與解決方法

#### 1. OPA Plugin 未就緒（最常見）

**症狀**：
- APISIX route 已配置但返回 503
- APISIX 日誌顯示 OPA 連線失敗

**診斷**：
```bash
# 檢查 OPA 是否運行
kubectl get pods -n opa-system

# 檢查 APISIX 日誌
kubectl logs -n ingress-apisix -l app.kubernetes.io/name=apisix --tail=100
```

**解決方法**：
```bash
# 方法 1：停用 OPA plugin（快速修復）
# 編輯 gitops/apisix/apisix-route.yaml，註解掉 OPA plugin 配置
# 已在最新版本中預設停用

# 方法 2：部署 OPA（完整解決方案）
# 1. 確保 OPA deployment 存在
kubectl get deploy -n opa-system

# 2. 上傳 OPA bundle
export STORAGE_ACCOUNT=<your-storage-account>
./scripts/upload-opa-bundle.sh

# 3. 在 apisix-route.yaml 中啟用 OPA plugin
```

---

#### 2. Spring Boot Pods 未運行

**診斷**：
```bash
# 檢查 Spring Boot pods 狀態
kubectl get pods -n app

# 查看 pod 詳細資訊
kubectl describe pod -n app -l app=spring-boot

# 檢查 pod 日誌
kubectl logs -n app -l app=spring-boot,version=stable
```

**常見問題**：

**a) Image Pull 失敗**
```bash
# 症狀：ImagePullBackOff 或 ErrImagePull
# 解決：確認 ACR 登入資訊正確
kubectl get events -n app --sort-by='.lastTimestamp'

# 建立 image pull secret（如果需要）
kubectl create secret docker-registry acr-secret \
  --docker-server=<ACR_LOGIN_SERVER> \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  -n app
```

**b) Readiness Probe 失敗**
```bash
# 症狀：Pod 運行但 READY 顯示 0/1
# 檢查健康檢查端點
kubectl exec -n app <pod-name> -- curl localhost:8080/actuator/health

# 查看 probe 設定
kubectl get pod -n app <pod-name> -o yaml | grep -A 5 readinessProbe
```

**c) 資源不足**
```bash
# 症狀：Pod 處於 Pending 狀態
# 檢查節點資源
kubectl top nodes
kubectl describe nodes

# 降低資源需求（暫時方案）
# 編輯 deployment-stable.yaml，調整 resources.requests
```

---

#### 3. Service Endpoints 未就緒

**診斷**：
```bash
# 檢查 Service 是否有 endpoints
kubectl get endpoints -n app spring-boot-stable
kubectl get endpoints -n app spring-boot-canary

# 詳細查看 endpoints
kubectl describe endpoints -n app spring-boot-stable
```

**解決方法**：
```bash
# 如果 endpoints 為空，檢查 Service selector 是否匹配 Pod labels
kubectl get svc -n app spring-boot-stable -o yaml | grep -A 3 selector
kubectl get pods -n app --show-labels
```

---

#### 4. APISIX 配置問題

**診斷**：
```bash
# 檢查 APISIX pods
kubectl get pods -n ingress-apisix

# 查看 APISIX 日誌
kubectl logs -n ingress-apisix -l app.kubernetes.io/name=apisix --tail=50

# 檢查 ApisixRoute 狀態
kubectl get apisixroute -n app
kubectl describe apisixroute -n app spring-boot-canary
```

**常見問題**：

**a) ApisixRoute 未生效**
```bash
# 確認 Ingress Controller 運行中
kubectl get pods -n ingress-apisix -l app.kubernetes.io/name=ingress-controller

# 檢查 controller 日誌
kubectl logs -n ingress-apisix -l app.kubernetes.io/name=ingress-controller
```

**b) etcd 連線問題**
```bash
# 檢查 etcd
kubectl get pods -n ingress-apisix -l app.kubernetes.io/name=etcd

# 測試 etcd 健康
kubectl exec -n ingress-apisix apisix-etcd-0 -- etcdctl endpoint health
```

---

#### 5. Namespace 問題

**診斷**：
```bash
# 確認所有必要的 namespace 存在
kubectl get ns | grep -E "app|ingress-apisix|opa-system|observability"

# 檢查 Service 是否在正確的 namespace
kubectl get svc -A | grep spring-boot
```

---

## 🟡 其他常見問題

### APISIX Dashboard 無法登入

**解決方法**：
```bash
# 確認 dashboard 已啟用（values.yaml）
kubectl get svc -n ingress-apisix | grep dashboard

# 使用正確的登入資訊
# Username: admin
# Password: gitops-canary-admin-pwd-2026
```

### Canary 流量分配不生效

**診斷**：
```bash
# 檢查 upstream 配置
kubectl port-forward svc/apisix-admin 9180:9180 -n ingress-apisix &
curl http://127.0.0.1:9180/apisix/admin/upstreams/canary-upstream \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

**解決方法**：
```bash
# 重新初始化 upstream
./scripts/init-canary-upstream.sh

# 或手動調整權重
./scripts/canary-switch.sh --stable 90 --canary 10
```

---

## 📝 完整診斷流程

執行以下命令進行完整診斷：

```bash
#!/bin/bash
echo "=== 1. 檢查所有 Pods 狀態 ==="
kubectl get pods -A | grep -E "apisix|spring-boot|opa|etcd"

echo -e "\n=== 2. 檢查 Services ==="
kubectl get svc -n app
kubectl get svc -n ingress-apisix

echo -e "\n=== 3. 檢查 Endpoints ==="
kubectl get endpoints -n app

echo -e "\n=== 4. 檢查 ApisixRoute ==="
kubectl get apisixroute -n app
kubectl describe apisixroute -n app spring-boot-canary

echo -e "\n=== 5. APISIX 日誌（最近 20 行）==="
kubectl logs -n ingress-apisix -l app.kubernetes.io/name=apisix --tail=20

echo -e "\n=== 6. Spring Boot 日誌（最近 10 行）==="
kubectl logs -n app -l app=spring-boot,version=stable --tail=10

echo -e "\n=== 7. 測試連線 ==="
APISIX_IP=$(kubectl get svc -n ingress-apisix apisix-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "APISIX IP: $APISIX_IP"
curl -v http://$APISIX_IP/api/hello 2>&1 | grep -E "HTTP|503|error"
```

---

## 🚀 驗證修復

確認服務恢復正常：

```bash
# 1. 取得 APISIX IP
APISIX_IP=$(kubectl get svc -n ingress-apisix apisix-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 2. 測試 API
curl http://$APISIX_IP/api/hello
# 預期輸出：{"message":"Hello from v1","version":"v1",...}

curl http://$APISIX_IP/api/health
# 預期輸出：{"status":"UP","version":"v1"}

# 3. 檢查回應時間
time curl http://$APISIX_IP/api/hello
# 應該在 100ms 內回應
```
