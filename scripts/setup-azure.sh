#!/usr/bin/env bash
# Chạy 1 LẦN trong Azure Cloud Shell (Bash).
# Cách dùng: bash scripts/setup-azure.sh <github-user>/<repo>
set -euo pipefail

GH_REPO="${1:-}"
if [[ -z "$GH_REPO" || "$GH_REPO" != */* ]]; then
  echo "Thiếu tham số. Dùng: bash $0 <github-user>/<repo>"; exit 1
fi

LOCATION="southeastasia"
APP_NAME="gh-bicep-lab"
RG_DEV="rg-lab-bicep-dev"
RG_PROD="rg-lab-bicep-prod"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo ">> Subscription: $SUB_ID"

echo ">> 1/4 Tạo Resource Group"
az group create -n "$RG_DEV"  -l "$LOCATION" -o none
az group create -n "$RG_PROD" -l "$LOCATION" -o none

echo ">> 2/4 Tạo App Registration + Service Principal"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [[ -z "$APP_ID" ]]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  az ad sp create --id "$APP_ID" -o none
fi

echo ">> 3/4 Gán quyền Contributor trên từng Resource Group"
for RG in "$RG_DEV" "$RG_PROD"; do
  az role assignment create --assignee "$APP_ID" --role Contributor \
    --scope "/subscriptions/$SUB_ID/resourceGroups/$RG" -o none
done

echo ">> 4/4 Tạo federated credential (OIDC)"
create_cred () {
  local NAME="$1" SUBJECT="$2"
  cat > /tmp/cred.json <<JSON
{
  "name": "$NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "$SUBJECT",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
  az ad app federated-credential create --id "$APP_ID" --parameters @/tmp/cred.json -o none \
    && echo "   + $NAME" || echo "   ~ $NAME (đã tồn tại?)"
}
create_cred "gh-main"     "repo:${GH_REPO}:ref:refs/heads/main"
create_cred "gh-pr"       "repo:${GH_REPO}:pull_request"
create_cred "gh-env-dev"  "repo:${GH_REPO}:environment:dev"
create_cred "gh-env-prod" "repo:${GH_REPO}:environment:prod"

echo
echo "=============================================="
echo "XONG. Tạo 3 secret này trong GitHub repo:"
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUB_ID"
echo "=============================================="
