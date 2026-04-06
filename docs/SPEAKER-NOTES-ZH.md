# 🎤 講者筆記 — 當金絲雀遇上可觀測性

> 每張投影片的詳細講稿與提示，幫助講者掌握節奏和重點。

---

## 投影片 1 — 封面 (30 秒)

**講稿**

> 大家好，我是 [Name]。今天要分享的主題是「當金絲雀遇上可觀測性」。
> 我們會看到如何用 APISIX、OPA 和 OpenTelemetry 三個開源工具，
> 打造一個企業級的安全佈署架構。
> 更重要的是，我們要讓佈署的每一步都「看得見」。

**提示**
- 微笑，建立連結
- 簡短自我介紹（公司、角色、經驗）
- 不要在封面停留太久

---

## 投影片 2 — 你遇過這些問題嗎？ (2 分鐘)

**講稿**

> 開始之前，讓我問大家一個問題。
>
> 在座有多少人，曾經在週五下午部署新版本，然後整個週末在處理事故的？
> （等觀眾反應）
>
> 上個月，我們團隊部署了一個看似無害的版本更新。金絲雀佈署已經設定好了，
> 但沒有人注意到 canary 版本的 P95 延遲已經飆到了 3 秒。
> 直到 50% 的使用者被切過去，客服電話才瘋狂響起⋯⋯
>
> 這個故事告訴我們一件事：**佈署不是問題，看不見才是問題。**
>
> 工程師凌晨三點被叫起來，想切回穩定版卻操作錯誤——
> 如果當時有一個 Dashboard 清楚顯示 canary 的錯誤率比 stable 高了 5 倍，
> 這件事可能 3 分鐘就結束了，而不是拖了 30 分鐘。

**提示**
- 這是觀眾連結的關鍵時刻，用故事抓住注意力
- 語速放慢，讓痛點感染力發酵
- 讓觀眾舉手互動（「有多少人遇過⋯⋯」）

---

## 投影片 3 — 今天的三個核心命題 (1.5 分鐘)

**講稿**

> 所以今天，我要回答三個問題。
>
> 第一，怎麼讓「對的人」先測試新版本？不是讓全部使用者一起賭，
> 而是讓 QA、內部員工先走新路。這裡我們用 OPA——Open Policy Agent。
>
> 第二，怎麼在事故發生前就「看到」問題？金絲雀佈署不夠，
> 你需要 Dashboard、Metrics、Traces 讓問題無所遁形。
>
> 第三，怎麼用數據驅動佈署決策？不是靠工程師的直覺決定什麼時候增加流量，
> 而是看 P95 延遲、錯誤率這些 SLI 指標來決策。

**提示**
- 這三個命題就是整場演講的骨幹
- 每個命題對應後面 2-3 張投影片
- 用手指標示 1、2、3，幫助觀眾建立結構感

---

## 投影片 4 — 架構總覽 (1 分鐘)

**講稿**

> 在深入之前，先看一下整體架構。
>
> 最上面是使用者，請求進到 APISIX Gateway。
> APISIX 會做四件事：問 OPA「這個請求該走 stable 還是 canary？」、
> 送 trace 到 OTel Collector、輸出 Prometheus 指標、然後做流量分配。
>
> 下面是兩個版本的 Spring Boot——stable v1 和 canary v2。
> 最底層是可觀測性堆疊：Prometheus 收指標、OTel Collector 收 trace、
> Grafana 做 11 個 Dashboard。
>
> 最重要的是：所有這些配置都在 Git 裡，ArgoCD 負責自動同步。
> 所以任何變更都有紀錄、可追溯、可回滾。

**提示**
- 這張圖會在後面反覆引用，讓觀眾記住
- 用手或雷射筆指向各元件，從上到下走過一遍
- 不需要解釋每個元件的細節，後面會展開

---

## 投影片 5 — 為什麼選 APISIX？ (2 分鐘)

**講稿**

> 為什麼我們選 APISIX 而不是其他 API Gateway？
>
> 最大的原因是：APISIX 可以透過 Admin API 動態調整 upstream 權重，
> 不需要重啟、不需要重新部署。
>
> 大家想想，如果你用 Nginx Ingress 做金絲雀，你需要改 annotation、
> commit、push、等 ArgoCD sync⋯⋯ 少則一分鐘，多則五分鐘。
> 但 APISIX 只需要一個 API 呼叫，一秒生效。
>
> 而且 APISIX 原生支援 prometheus、opentelemetry、opa 這三個插件。
> 不需要額外的 sidecar，不需要額外的配置。
> 這代表我們的可觀測性是「天生的」，不是事後補上去的。

**提示**
- 強調「動態配置」和「原生插件」這兩個關鍵差異
- 如果觀眾有用 Nginx Ingress 的，這裡會產生共鳴
- 可以順帶提到 APISIX 有 80+ 個插件

---

## 投影片 6 — OPA 在金絲雀佈署中的角色 (2.5 分鐘)

**講稿**

> 現在來看 OPA 的角色。OPA 全名是 Open Policy Agent，
> 核心理念是「策略即程式碼」。
>
> 看這段 Rego 程式碼：如果請求帶了 `x-canary: true` header，
> 或者 cookie 裡有 `canary=true`，OPA 就會回傳「路由到 canary」。
> 否則就走 stable。
>
> 這有什麼好處？QA 團隊可以在 Postman 裡加一個 header 就能測試新版本，
> 完全不影響一般使用者。內部員工可以透過 cookie 優先體驗新功能。
> 甚至微服務之間的呼叫，也可以帶 header 做整條鏈路的 canary 測試。
>
> 而且這個策略是透過 CI/CD 打包上傳到 Azure Blob Storage，
> OPA 每 30 到 60 秒就會自動拉取。所以策略更新也是 GitOps 的一部分，
> 有 code review、有測試、有紀錄。

**提示**
- 用具體場景讓 OPA 不抽象：「QA 在 Postman 加個 header」
- 強調 OPA bundle 的自動更新流程
- 如果時間允許，可以提到 bluegreen.rego 做即時 100:0 切換

---

## 投影片 7 — OpenTelemetry 在這個架構中的定位 (2.5 分鐘)

**講稿**

> OpenTelemetry 在這裡做的事情很簡單但很關鍵。
>
> APISIX 的 OTel plugin 負責閘道層的 trace，
> Spring Boot 的 OTel Java Agent 負責應用層的 trace。
> 兩者都送到 OTel Collector，然後 Collector 分發到 Tempo 儲存 trace，
> 同時也輸出 span metrics 到 Prometheus。
>
> 最重要的設計是：stable 和 canary 的 service.name 不同。
> stable 叫 `demo-api-stable`，canary 叫 `demo-api-canary`。
> 這樣在 Grafana 的 Tempo 面板裡，你可以一眼看出這個 trace 是哪個版本。
>
> 而且 Spring Boot 的 OTel Agent 是完全零侵入的。
> 你看 Dockerfile 裡就是加了一個 Java agent 環境變數，
> 不需要改一行 Java 程式碼，trace 自動產生。
> 這對開發團隊的接受度非常重要。

**提示**
- 「零侵入」是讓開發團隊願意接受可觀測性的關鍵
- 強調 service.name 區分版本的設計
- 可以提到 OTel Collector 的批次處理和記憶體限制配置

---

## 投影片 8 — 雙版本並行架構 (2 分鐘)

**講稿**

> 現在看 Kubernetes 的實際部署。
>
> 在 app namespace 裡有兩個 Deployment：spring-boot-stable 和 spring-boot-canary。
> 每個都有自己的 Service。唯一的差別是環境變數：
> stable 的 APP_VERSION 是 v1，canary 是 v2。
>
> 流量控制是兩層的。
> 第一層是 OPA，精確控制特定使用者。
> 第二層是 APISIX 權重，按比例分配流量。
>
> 我們來看 demo：同一個 URL，不帶 header 就是 v1，
> 帶了 `x-canary: true` 就是 v2。這就是 OPA 策略路由的效果。

**提示**
- 可以切到 terminal 做 live demo（如果有環境）
- 或者放預錄的 curl 輸出截圖
- 強調「同一個 endpoint，不同體驗」

---

## 投影片 9 — 事故場景 (2 分鐘)

**講稿**

> 現在讓我用一個時間軸告訴你，沒有可觀測性的金絲雀有多危險。
>
> 14:00，工程師部署了 canary v2，一切正常。
> 14:05，他想切 10% 流量，但打錯了指令，變成 100% 全切。
> 14:06，v2 有 bug，延遲飆到 5 秒。但沒有 dashboard，沒人看到。
> 14:10，5xx 錯誤率到了 30%。沒有 alert，沒人收到通知。
> 一直到 14:25，使用者大量投訴，客服才升級通報。
> 14:30 才手動回滾。事故持續了 25 分鐘。
>
> 如果有可觀測性呢？
> 14:06 Dashboard 就會顯示延遲異常，14:07 Alert 就會響，
> 14:08 工程師就能回滾。**3 分鐘結案。**
>
> 這就是可觀測性的價值——不是讓你避免錯誤，而是讓你在錯誤發生後**最快復原**。

**提示**
- 這是全場最有張力的時刻
- 語速放慢，讓兩個時間軸的對比發酵
- 可以用紅色/綠色背景對比「沒有觀測」vs「有觀測」

---

## 投影片 10 — 11 個 Dashboard 全景 (2 分鐘)

**講稿**

> 我們的架構有 11 個 Grafana Dashboard，涵蓋從閘道到應用的每一層。
>
> 今天最重要的是第 3 個：Canary Traffic Split。
> 這個 dashboard 讓你一眼看到 stable 和 canary 的流量比例、
> QPS、延遲、錯誤率的即時對比。
>
> 但我想特別提一下其他幾個：
> Upstream Health 讓你知道後端服務是不是活著。
> Security & Rate Limiting 讓你看到有沒有異常的 429、403。
> Spring Boot Metrics 讓你看到 JVM 層面的指標。
>
> 這些 dashboard 都是透過 Kustomize 自動生成 ConfigMap，
> Grafana sidecar 自動發現和匯入。所以部署完就有，不需要手動操作。

**提示**
- 不要逐個介紹 11 個，重點放在 Canary Traffic Split
- 快速掃過其他 dashboard 就好
- 強調「自動部署」—— ConfigMap + Sidecar

---

## 投影片 11 — Canary Traffic Split Dashboard (2 分鐘)

**講稿**

> 來仔細看這個 Canary Traffic Split Dashboard。
>
> 左上是流量分配圓餅圖，即時顯示 stable 和 canary 各拿到多少百分比的流量。
> 旁邊是 QPS 趨勢圖，兩條線讓你比較兩個版本的請求量。
> 右邊是延遲比較：P50、P95、P99 都有，可以立刻發現 canary 是不是比 stable 慢。
>
> 下面是錯誤率對比：如果 canary 的紅線比 stable 高，你就知道新版本有問題。
> 最右邊是 Tempo 追蹤連結，可以直接點進去看一條完整的 request trace。
>
> 這些資料背後是 Prometheus 查詢。
> 例如這個查詢就是算 canary 的 5xx 錯誤率佔所有 canary 請求的百分比。
> 低於 1% 是綠燈，超過 5% 就是紅燈，該回滾了。

**提示**
- 如果有真實 Grafana 截圖，在這裡展示
- 可以用 job-caller 產生測試流量來生成真實數據
- 這裡是安排 Live Demo 的最佳時機

---

## 投影片 12 — 漸進式金絲雀佈署流程 (3 分鐘)

**講稿**

> 有了 Dashboard 和 Alert，我們就能做漸進式金絲雀佈署。
>
> 第一步：0% canary，只有帶 header 的內部測試者能到 canary。
> 讓 QA 先驗證功能、跑完整合測試。
>
> 第二步：切 10% 流量。然後看 Dashboard 10 分鐘。
> 延遲正常嗎？錯誤率正常嗎？沒問題就繼續。
>
> 第三步：切 50%。這是關鍵的對比期，因為兩邊流量差不多，
> 你可以做 A/B 比較。同時啟動 Alert，如果指標異常就自動通知。
>
> 第四步：100%，全量切換。但這時候 stable 還在，
> 如果發現問題，一個指令就回到 100% stable。
>
> 每一步只需要一個指令：
> `canary-switch.sh --stable 90 --canary 10`
> 背後就是 PATCH APISIX Admin API，一秒生效。

**提示**
- 用時間軸視覺化讓觀眾理解流程
- 強調「每次切之前要先看 Dashboard」
- 提到 rollback 只需要一個指令

---

## 投影片 13 — 決策指標 (2.5 分鐘)

**講稿**

> 那什麼時候該繼續增加流量？什麼時候該停？什麼時候該回滾？
>
> 我們用這個決策矩陣。
> P95 延遲低於 200ms 是綠燈。200 到 1000 是黃燈，暫停觀察。超過 1 秒是紅燈，回滾。
> 5xx 錯誤率低於 1% 是綠燈。1% 到 5% 是黃燈。超過 5% 是紅燈。
>
> 最重要的是第三行：canary 和 stable 的延遲差。
> 如果 canary 比 stable 慢 50% 以上，即使絕對值還在可接受範圍，
> 你也應該暫停，因為這代表新版本的效能有退步。
>
> 這些閾值不是隨便定的，而是直接對應到 Prometheus Alert Rules。
> 意思是：不需要有人盯著 Dashboard 看，
> Prometheus 會自動幫你判斷，超標就告警。

**提示**
- 用紅/黃/綠色讓表格更直覺
- 強調「自動化」—— 不需要人盯著看
- 順帶提到這些閾值應該根據 SLO 調整

---

## 投影片 14 — Alert 的角色 (2.5 分鐘)

**講稿**

> 說到 Alert，我想強調一個觀念：
> **告警不是通知，是行動指令。**
>
> 每個 Alert 都要回答三個問題：什麼壞了？影響是什麼？該怎麼做？
>
> 例如 CanaryHighErrorRate：
> 什麼壞了？canary 5xx 錯誤率超過 5%。
> 影響是什麼？有 10% 的使用者收到錯誤回應。
> 該怎麼做？執行回滾腳本，一鍵回到 stable。
>
> 告警管道可以是 Slack、PagerDuty、Teams、Email。
> 但進階做法是接 Webhook，讓 Alert 直接觸發回滾腳本。
> 這就是「自動回滾」—— 人類不需要介入，系統自己修復。
>
> 當然自動回滾需要充分的測試和信心，初期建議先用半自動：
> Alert 通知 on-call 工程師，工程師確認後執行回滾。

**提示**
- 「告警不是通知，是行動指令」——這句話可以重複強調
- 分享自動回滾的風險和建議
- 可以展示一個 Alert YAML 片段

---

## 投影片 15 — 可觀測性三支柱 (2.5 分鐘)

**講稿**

> 來總結一下可觀測性三支柱在我們架構中的對應。
>
> Metrics：Prometheus 收集 APISIX 和 Spring Boot 的指標，
> 透過 Grafana 的 11 個 Dashboard 呈現。
> 這是「現在發生什麼事」的即時視角。
>
> Traces：OpenTelemetry 從 APISIX 和 Spring Boot 收集 trace，
> 存到 Tempo，在 Grafana 裡查看。
> 這是「一個請求經過了哪些服務」的鏈路視角。
>
> Logs：這部分我們建議搭配 EFK Stack——Elasticsearch、Fluentd、Kibana。
> 雖然我們的 repo 聚焦在 Metrics 和 Traces，
> 但完整的可觀測性一定需要 Logs。
>
> Kibana 可以按 x-route-to header 篩選日誌，區分 stable 和 canary。
> 也可以按 trace-id 搜尋一條請求的完整日誌鏈路。

**提示**
- 三支柱是大家熟悉的框架，快速對應即可
- Kibana/Logs 的部分坦承 repo 目前聚焦 Metrics + Traces
- 如果觀眾問到 Logs，可以分享 EFK 整合的建議

---

## 投影片 16 — 資料流全景圖 (2.5 分鐘)

**講稿**

> 這張圖把所有的資料流串在一起。
>
> 左邊是資料來源：APISIX 和 Spring Boot。
> 每個來源都輸出三種資料：metrics 到 Prometheus、
> traces 到 OTel Collector 再到 Tempo、logs 到 Elasticsearch。
>
> 中間是 OTel Collector，它是我們的資料中樞。
> 接收 OTLP 資料，做批次處理和記憶體限制，
> 然後分發到 Tempo（存 traces）和 Prometheus（存 metrics）。
>
> 右邊是呈現層：Grafana Dashboard 和 Kibana。
>
> 另外一條重要的線是 Prometheus AlertManager，
> 它根據 Alert Rules 發通知到 Slack 或 PagerDuty。
> 甚至可以觸發回滾腳本。

**提示**
- 用手指沿著資料流走一遍
- 強調 OTel Collector 作為「中樞」的角色
- 可以提到 OTel Collector 的可擴展性（可以加更多 exporter）

---

## 投影片 17 — 業界最佳實踐 (3 分鐘)

**講稿**

> 最後分享 8 個業界最佳實踐。
>
> 第一，GitOps First。所有配置都在 Git 裡，ArgoCD 負責同步。
> 這保證了可追溯性和可重現性。
>
> 第二，Policy as Code。OPA 策略也走 CI/CD，有 review、有測試。
>
> 第三，漸進式佈署。永遠不要一次 0 到 100%，至少三階段。
>
> 第四，SLO-driven Rollout。用 SLI 指標決定是否繼續。
>
> 第五，自動回滾。Alert 加 Webhook，錯誤率超標就自動回滾。
>
> 第六，Trace-based Testing。用 distributed tracing 比對新舊版本的行為差異。
>
> 第七，Dashboard as Runbook。Dashboard 不只是看的，
> 每個面板都要有對應的操作 SOP。
>
> 第八，Chaos Engineering。定期注入故障，驗證告警是否真的會響。
> 不要等到真正出事才發現 Alert 沒設好。

**提示**
- 不需要每個都深入，快速帶過
- 可以根據觀眾反應選 2-3 個展開
- 第五和第七通常最有共鳴

---

## 投影片 18 — 方案比較 (2 分鐘)

**講稿**

> 市面上有很多金絲雀佈署的方案，這裡做一個簡單比較。
>
> Argo Rollouts 和 Flagger 都是很好的選擇，
> 但它們各自有不同的依賴。
> Argo Rollouts 需要用它的 CRD，Flagger 通常搭配 Service Mesh。
>
> 我們這個架構的特點是：不需要 Service Mesh。
> 這大幅降低了複雜度和資源消耗。
> OPA 提供比 annotation 更靈活的路由策略。
> 閘道層和應用層同時有可觀測性，雙管齊下。
>
> 而且我們有 11 個 Dashboard，從閘道到應用到基礎設施全覆蓋。
> 這在業界的開源方案中是相對完整的。

**提示**
- 不要貶低其他方案，各有優缺
- 強調「不需要 Service Mesh」是最大差異
- 如果有人問「為什麼不用 Istio」，答案是：可以用，但複雜度更高

---

## 投影片 19 — Key Takeaways (1.5 分鐘)

**講稿**

> 最後，帶大家回顧六個關鍵訊息。
>
> 一，金絲雀佈署不難，難的是看見它。
> 二，OPA 讓你精準控制誰先走新路。
> 三，用 SLO 指標驅動佈署決策，不靠直覺。
> 四，Metrics、Traces、Logs 三支柱缺一不可。
> 五，Dashboard 是你的佈署 Runbook。
> 六，GitOps 確保一切可追溯。
>
> 如果今天你只記得一件事，請記得：
> **沒有可觀測性的金絲雀，等於盲人開車。**

**提示**
- 語速放慢，每個 takeaway 停頓一下
- 最後一句重複「盲人開車」，這是全場的核心金句
- 看著觀眾，製造連結

---

## 投影片 20 — 資源連結 & Q&A (30 秒)

**講稿**

> 所有的程式碼和配置都開源在 GitHub 上，
> 歡迎掃 QR Code 或到 github.com/matsurigoto/GitOps-APISIX-Canary 查看。
>
> 感謝大家的時間！如果有任何問題，我很樂意討論。

**提示**
- 確認 QR Code 可以掃
- 準備好可能的 Q&A 問題（見下方）

---

## 🎯 Q&A 準備 — 常見問題

### Q: 為什麼不用 Istio/Linkerd 做金絲雀？
> Istio 是很強大的方案，但它引入了 sidecar proxy 的額外複雜度和資源消耗。我們的架構在閘道層處理流量分配，不需要每個 Pod 注入 sidecar，對既有服務的侵入性更低。如果你的架構已經有 Service Mesh，那用 Istio 的 VirtualService 做金絲雀當然也很好。

### Q: OPA 的效能影響大嗎？
> OPA 的策略評估通常在毫秒級（< 1ms），對整體延遲影響很小。Bundle 是預編譯的，所以評估速度很快。我們的 OPA 配置只要求 100m CPU、128Mi RAM，資源消耗也很輕量。

### Q: 如何做到自動回滾？
> Prometheus AlertManager 支援 Webhook receiver。你可以設定當 CanaryHighErrorRate alert 觸發時，AlertManager 呼叫一個 webhook endpoint，這個 endpoint 執行 canary-switch.sh 回到 100% stable。但建議初期先用半自動——Alert 通知人，人來執行回滾。

### Q: 如果 OTel Collector 掛了怎麼辦？
> OTel Collector 有 memory limiter 保護，不會因為資料量過大而 OOM。如果 Collector 真的掛了，APISIX 和 Spring Boot 的 trace 資料會在 buffer 中等待，不會影響正常請求處理。但你會短暫失去 trace 資料。建議用 Kubernetes 的 liveness probe 確保自動重啟。

### Q: 為什麼 Dashboard 有 11 個這麼多？
> 11 個 Dashboard 是按角色設計的。SRE 看 Overview 和 Node Metrics，開發看 Route Metrics 和 Spring Boot，安全團隊看 Security 和 SSL。大多數時候你只需要看 1-2 個。特別是佈署時，重點看 Canary Traffic Split 就好。

### Q: Kibana/EFK 這部分 repo 裡有嗎？
> 目前 repo 聚焦在 Metrics 和 Traces，EFK Stack 的配置不在裡面。但架構上是完全相容的：APISIX 的 access log 可以用 Filebeat 收集，Spring Boot 的 stdout 可以用 Fluentd 收集，都送到 Elasticsearch。這是一個合理的下一步擴展。
