#!/bin/bash
set -euo pipefail

#=============================================================================
# GitOps-APISIX-Canary — Azure Infrastructure Setup
# Creates: Resource Group, ACR, Blob Storage, AKS (with Workload Identity)
#=============================================================================

# ── Configuration ───────────────────────────────────────────────────────────
RESOURCE_GROUP="rg-gitops-canary"
LOCATION="eastasia"
AKS_NAME="aks-gitops-canary"
ACR_NAME="acrgitopscanary$(openssl rand -hex 3)"   # must be globally unique
STORAGE_ACCOUNT="stgitopscanary$(openssl rand -hex 3)"
BLOB_CONTAINER="opa-bundles"
NODE_COUNT=3
NODE_VM_SIZE="Standard_D4s_v3"
OPA_IDENTITY_NAME="opa-identity"
K8S_OPA_NAMESPACE="opa-system"
K8S_OPA_SA="opa-sa"

echo "============================================"
echo "  GitOps-APISIX-Canary Infrastructure Setup"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Resource Group  : $RESOURCE_GROUP"
echo "  Location        : $LOCATION"
echo "  AKS Name        : $AKS_NAME"
echo "  ACR Name        : $ACR_NAME"
echo "  Storage Account : $STORAGE_ACCOUNT"
echo ""

# ── 1. Resource Group ──────────────────────────────────────────────────────
echo "▶ [1/10] Creating Resource Group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

# ── 2. Azure Container Registry ───────────────────────────────────────────
echo "▶ [2/10] Creating Azure Container Registry..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Basic \
  --admin-enabled true \
  --output table

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
echo "   ACR Login Server: $ACR_LOGIN_SERVER"

# ── 3. Blob Storage (for OPA bundles) ─────────────────────────────────────
echo "▶ [3/10] Creating Storage Account..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output table

echo "▶ [4/10] Creating Blob Container for OPA bundles..."
az storage container create \
  --name "$BLOB_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --public-access off \
  --output table

STORAGE_ACCOUNT_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net"
echo "   Blob URL: $STORAGE_ACCOUNT_URL"

# ── 4. AKS Cluster ────────────────────────────────────────────────────────
echo "▶ [5/10] Creating AKS Cluster (this may take 5-10 minutes)..."
az aks create \
  --name "$AKS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_VM_SIZE" \
  --attach-acr "$ACR_NAME" \
  --enable-managed-identity \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --network-plugin azure \
  --network-policy calico \
  --generate-ssh-keys \
  --output table

# ── 5. Get AKS credentials ────────────────────────────────────────────────
echo "▶ [6/10] Fetching AKS credentials..."
az aks get-credentials \
  --name "$AKS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --overwrite-existing

echo "   Verifying cluster connection..."
kubectl get nodes -o wide

# ── 6. Get AKS OIDC Issuer URL ────────────────────────────────────────────
AKS_OIDC_ISSUER=$(az aks show \
  --name "$AKS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)
echo "   OIDC Issuer: $AKS_OIDC_ISSUER"

# ── 7. Create User Assigned Managed Identity for OPA ──────────────────────
echo "▶ [7/10] Creating Managed Identity for OPA..."
az identity create \
  --name "$OPA_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

OPA_CLIENT_ID=$(az identity show \
  --name "$OPA_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query clientId -o tsv)
OPA_PRINCIPAL_ID=$(az identity show \
  --name "$OPA_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)

echo "   OPA Identity Client ID : $OPA_CLIENT_ID"
echo "   OPA Identity Principal ID : $OPA_PRINCIPAL_ID"

# ── 8. Grant Storage Blob Data Reader to OPA identity ─────────────────────
echo "▶ [8/10] Assigning Storage Blob Data Reader role..."
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id "$OPA_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" \
  --scope "$STORAGE_ACCOUNT_ID" \
  --output table

# ── 9. Create Federated Identity Credential (Workload Identity) ───────────
echo "▶ [9/10] Creating Federated Identity Credential..."
az identity federated-credential create \
  --name "opa-federated-cred" \
  --identity-name "$OPA_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:${K8S_OPA_NAMESPACE}:${K8S_OPA_SA}" \
  --audiences "api://AzureADTokenExchange" \
  --output table

# ── 10. Create Kubernetes Namespaces ──────────────────────────────────────
echo "▶ [10/10] Creating Kubernetes Namespaces..."
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ingress-apisix --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace opa-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ Infrastructure Setup Complete!"
echo "============================================"
echo ""
echo "Resources Created:"
echo "  Resource Group    : $RESOURCE_GROUP"
echo "  ACR Login Server  : $ACR_LOGIN_SERVER"
echo "  Storage Account   : $STORAGE_ACCOUNT"
echo "  Blob Container    : $BLOB_CONTAINER"
echo "  AKS Cluster       : $AKS_NAME"
echo "  OPA Client ID     : $OPA_CLIENT_ID"
echo ""
echo "Next Steps:"
echo "  1. Install ArgoCD:"
echo "     helm repo add argo https://argoproj.github.io/argo-helm"
echo "     helm install argocd argo/argo-cd -n argocd -f gitops/argocd/values.yaml"
echo ""
echo "  2. Install APISIX:"
echo "     helm repo add apisix https://charts.apiseven.com"
echo "     helm install apisix apisix/apisix -n ingress-apisix -f gitops/apisix/values.yaml"
echo ""
echo "  3. Install kube-prometheus-stack:"
echo "     helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
echo "     helm install monitoring prometheus-community/kube-prometheus-stack -n observability -f gitops/observability/kube-prometheus-stack/values.yaml"
echo ""
echo "  4. Apply ArgoCD root-app:"
echo "     kubectl apply -f gitops/root-app.yaml"
echo ""
echo "  5. Set GitHub Secrets:"
echo "     AZURE_CREDENTIALS, ACR_NAME=$ACR_NAME, ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
echo "     STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
echo ""
echo "  6. Update configuration files:"
echo "     - gitops/opa/configmap-opa-config.yaml → replace STORAGE_ACCOUNT_URL"
echo "     - gitops/opa/deployment.yaml → replace OPA_CLIENT_ID"
echo "     - gitops/spring-boot/deployment-*.yaml → replace ACR_LOGIN_SERVER"
echo ""
echo "Important Values (save these):"
echo "  export ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
echo "  export STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
echo "  export STORAGE_ACCOUNT_URL=$STORAGE_ACCOUNT_URL"
echo "  export OPA_CLIENT_ID=$OPA_CLIENT_ID"
echo "  export AKS_OIDC_ISSUER=$AKS_OIDC_ISSUER"
