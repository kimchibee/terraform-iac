#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# 목적:
# 1) 사용자에게 Hub/Spoke 구독 ID 입력을 안내받고
# 2) bootstrap/backend/terraform.tfvars 값을 읽어 각 리프 terraform.tfvars에 반영
# 3) 01.network -> 09.connectivity 순서로 순차 배포
# 4) 로그를 scripts/logs 하위에 저장하고, 터미널에도 동시에 출력
# 5) 마지막에 스택별 Terraform state 리소스 주소 표 출력
# -----------------------------------------------------------------------------

set -euo pipefail
export TF_IN_AUTOMATION=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_TFVARS="$REPO_ROOT/bootstrap/backend/terraform.tfvars"
LOG_ROOT="$SCRIPT_DIR/logs"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_LOG_DIR="$LOG_ROOT/deploy-$RUN_ID"
SUMMARY_TSV="$RUN_LOG_DIR/deploy-summary.tsv"
RESOURCE_TSV="$RUN_LOG_DIR/deployed-resources.tsv"

STACK_ORDER=(
  "01.network"
  "02.storage"
  "03.shared-services"
  "04.apim"
  "05.ai-services"
  "06.compute"
  "07.identity"
  "08.rbac"
  "09.connectivity"
)

NETWORK_LEAF_ORDER=(
  "resource-group/hub-rg"
  "resource-group/spoke-rg"
  "vnet/hub-vnet"
  "vnet/spoke-vnet"
  "subnet/hub-gateway-subnet"
  "subnet/hub-dnsresolver-inbound-subnet"
  "subnet/hub-azurefirewall-subnet"
  "subnet/hub-azurefirewall-management-subnet"
  "subnet/hub-appgateway-subnet"
  "security-group/application-security-group/keyvault-clients"
  "security-group/application-security-group/vm-allowed-clients"
  "security-group/network-security-group/keyvault-standalone"
  "security-group/network-security-group/hub-pep"
  "security-group/network-security-group/hub-monitoring-vm"
  "security-group/network-security-group/spoke-pep"
  "subnet/hub-monitoring-vm-subnet"
  "subnet/hub-pep-subnet"
  "subnet/spoke-apim-subnet"
  "subnet/spoke-pep-subnet"
  "security-group/security-policy/hub-sg-policy-default"
  "security-group/security-policy/spoke-sg-policy-default"
  "route/hub-route-default"
  "route/spoke-route-default"
  "dns/private-dns-zone/hub-blob"
  "public-ip/hub-vpn-gateway"
  "virtual-network-gateway/hub-vpn-gateway"
)

REQUIRED_PROVIDERS=(
  "Microsoft.OperationalInsights"
  "Microsoft.Insights"
  "Microsoft.OperationsManagement"
  "Microsoft.ApiManagement"
  "Microsoft.Network"
  "Microsoft.Storage"
  "Microsoft.KeyVault"
  "Microsoft.Compute"
  "Microsoft.CognitiveServices"
  "Microsoft.MachineLearningServices"
)

mkdir -p "$RUN_LOG_DIR"

print_guide() {
  cat <<'EOF'
[안내] Azure 로그인 및 구독 ID 확인 방법
1) 아직 로그인하지 않았다면:
   az login

2) 사용 가능한 구독 확인:
   az account list --query "[].{name:name,id:id,tenant:tenantId}" -o table

3) 현재 선택된 구독 확인:
   az account show --query "{name:name,id:id,tenant:tenantId}" -o table

4) 권장: Provider 자동 등록을 위해 아래 권한 필요
   - Hub/Spoke 구독 모두에서 Contributor 이상
   - (RBAC까지 자동 배포 시) User Access Administrator 또는 Owner

아래 프롬프트에서 Hub/Spoke 구독 ID(GUID)를 입력하세요.
EOF
}

is_guid() {
  local v="$1"
  [[ "$v" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

read_guid() {
  local prompt="$1"
  local value=""
  while true; do
    read -r -p "$prompt: " value
    if is_guid "$value"; then
      echo "$value"
      return
    fi
    echo "  - GUID 형식이 아닙니다. 예: 12345678-1234-1234-1234-123456789abc"
  done
}

get_tfvar_value() {
  local key="$1"
  local file="$2"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"?([^\"#]+)\"?.*$/\1/p" "$file" | head -n1 | xargs
}

replace_if_key_exists() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"

  if rg -q "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { re = "^[[:space:]]*" key "[[:space:]]*=" }
      $0 ~ re { print key " = \"" value "\""; next }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
  fi
}

collect_leaf_dirs() {
  local stack="$1"
  local stack_dir="$REPO_ROOT/azure/dev/$stack"
  if [[ ! -d "$stack_dir" ]]; then
    return
  fi
  find "$stack_dir" \
    -type d \( -name ".terraform" -o -name ".git" \) -prune -o \
    -type f -name "main.tf" -print0 | while IFS= read -r -d '' f; do
    dirname "$f"
  done | sort -u
}

ensure_backend_hcl_for_leaves() {
  local created=0
  local leaf
  while IFS= read -r leaf; do
    [[ -z "$leaf" ]] && continue
    if [[ ! -f "$leaf/backend.hcl" ]]; then
      cat > "$leaf/backend.hcl" <<EOF
resource_group_name  = "$BACKEND_RG"
storage_account_name = "$BACKEND_SA"
container_name       = "$BACKEND_CONTAINER"
key                  = "${leaf#$REPO_ROOT/}/terraform.tfstate"
EOF
      created=$((created + 1))
    fi
  done < <(
    find "$REPO_ROOT/azure/dev" \
      -type d \( -name ".terraform" -o -name ".git" \) -prune -o \
      -type f -name "main.tf" -print0 | while IFS= read -r -d '' f; do
      dirname "$f"
    done | sort -u
  )
  echo "[완료] backend.hcl 자동 보정 생성: ${created}개"
}

collect_leaf_dirs_ordered() {
  local stack="$1"
  local stack_dir="$REPO_ROOT/azure/dev/$stack"
  local leaf

  if [[ "$stack" != "01.network" ]]; then
    collect_leaf_dirs "$stack"
    return
  fi

  for leaf in "${NETWORK_LEAF_ORDER[@]}"; do
    local abs="$stack_dir/$leaf"
    if [[ -f "$abs/main.tf" ]]; then
      echo "$abs"
    fi
  done

  # NETWORK_LEAF_ORDER에 없는 리프가 생기면 뒤에 자동 추가
  collect_leaf_dirs "$stack" | while IFS= read -r extra; do
    [[ -z "$extra" ]] && continue
    local rel="${extra#$stack_dir/}"
    local listed=0
    local item
    for item in "${NETWORK_LEAF_ORDER[@]}"; do
      if [[ "$rel" == "$item" ]]; then
        listed=1
        break
      fi
    done
    [[ "$listed" -eq 0 ]] && echo "$extra"
  done
}

ensure_required_providers() {
  local subscription_id="$1"
  local pending=0

  az account set --subscription "$subscription_id" >/dev/null
  echo "구독 $subscription_id 의 Provider 등록 상태 점검 중..."

  for ns in "${REQUIRED_PROVIDERS[@]}"; do
    local state
    state="$(az provider show --namespace "$ns" --query "registrationState" -o tsv 2>/dev/null || true)"
    if [[ "$state" != "Registered" ]]; then
      echo "  - $ns: ${state:-NotRegistered} -> 등록 요청"
      az provider register --namespace "$ns" >/dev/null
      pending=1
    else
      echo "  - $ns: Registered"
    fi
  done

  if [[ "$pending" -eq 1 ]]; then
    echo "  - 일부 Provider는 등록 완료까지 시간이 걸릴 수 있습니다."
    echo "  - 아래 명령으로 상태 확인 가능:"
    echo "    az provider show --namespace Microsoft.CognitiveServices --query registrationState -o tsv"
    echo "    az provider show --namespace Microsoft.MachineLearningServices --query registrationState -o tsv"
  fi
}

apply_leaf() {
  local stack="$1"
  local leaf_abs="$2"
  local leaf_rel="${leaf_abs#$REPO_ROOT/}"
  local leaf_id="${leaf_rel//\//__}"
  local log_file="$RUN_LOG_DIR/${stack//\//_}__${leaf_id}.log"
  local status="success"

  echo
  echo "===== [STACK: $stack] [LEAF: $leaf_rel] ====="
  echo "log: $log_file"

  # backend는 Hub 구독에 있으므로 init/apply 전에 항상 Hub 구독으로 고정
  az account set --subscription "$HUB_SUBSCRIPTION_ID" >/dev/null

  (
    cd "$leaf_abs"
    local init_ok=0
    local init_attempt
    for init_attempt in 1 2 3; do
      if terraform init -upgrade -backend-config=backend.hcl -input=false; then
        init_ok=1
        break
      fi
      echo "WARN: terraform init 실패(시도 ${init_attempt}/3), 5초 후 재시도..."
      sleep 5
    done

    if [[ "$init_ok" -ne 1 ]]; then
      echo "ERROR: terraform init 재시도 후에도 실패"
      exit 1
    fi

    if [[ -f "terraform.tfvars" ]]; then
      terraform apply -auto-approve -var-file=terraform.tfvars -input=false
    else
      terraform apply -auto-approve -input=false
    fi
  ) 2>&1 | tee "$log_file" || status="failed"

  printf "%s\t%s\t%s\t%s\n" "$stack" "$leaf_rel" "$status" "$log_file" >> "$SUMMARY_TSV"

  if [[ "$status" == "success" ]]; then
    (
      cd "$leaf_abs"
      terraform state list 2>/dev/null || true
    ) | while IFS= read -r addr; do
      [[ -z "$addr" ]] && continue
      printf "%s\t%s\t%s\n" "$stack" "$leaf_rel" "$addr" >> "$RESOURCE_TSV"
    done
  fi
}

test_monitoring_vm_openai() {
  local vm_leaf="$REPO_ROOT/azure/dev/06.compute/linux-monitoring-vm"
  local ai_leaf="$REPO_ROOT/azure/dev/05.ai-services/workload"
  local test_log="$RUN_LOG_DIR/monitoring-vm-openai-test.log"

  if [[ ! -d "$vm_leaf" || ! -d "$ai_leaf" ]]; then
    echo "SKIP: monitoring-vm 또는 ai-services 리프가 없어 GPT 호출 테스트를 건너뜁니다." | tee -a "$test_log"
    return 0
  fi

  if [[ ! -f "$vm_leaf/backend.hcl" || ! -f "$ai_leaf/backend.hcl" ]]; then
    echo "SKIP: backend.hcl 미생성 상태라 GPT 호출 테스트를 건너뜁니다." | tee -a "$test_log"
    return 0
  fi

  echo "[후속검증] monitoring-vm에서 GPT 호출 테스트 시작..." | tee -a "$test_log"

  local vm_id vm_name openai_id openai_endpoint
  local vm_rg spoke_rg aoai_name aoai_host api_key

  vm_id="$(cd "$vm_leaf" && terraform output -raw vm_id 2>/dev/null || true)"
  vm_name="$(cd "$vm_leaf" && terraform output -raw vm_name 2>/dev/null || true)"
  openai_id="$(cd "$ai_leaf" && terraform output -raw openai_id 2>/dev/null || true)"
  openai_endpoint="$(cd "$ai_leaf" && terraform output -raw openai_endpoint 2>/dev/null || true)"

  if [[ -z "$vm_id" || -z "$vm_name" || -z "$openai_id" || -z "$openai_endpoint" ]]; then
    echo "SKIP: vm/openai output 조회 실패로 GPT 호출 테스트를 건너뜁니다." | tee -a "$test_log"
    return 0
  fi

  vm_rg="$(sed -n 's#^.*/resourceGroups/\([^/]*\)/.*$#\1#p' <<< "$vm_id")"
  spoke_rg="$(sed -n 's#^.*/resourceGroups/\([^/]*\)/.*$#\1#p' <<< "$openai_id")"
  aoai_name="$(basename "$openai_id")"
  aoai_host="${openai_endpoint#https://}"
  aoai_host="${aoai_host%/}"

  az account set --subscription "$SPOKE_SUBSCRIPTION_ID" >/dev/null
  api_key="$(az cognitiveservices account keys list -g "$spoke_rg" -n "$aoai_name" --query key1 -o tsv)"

  if [[ -z "$api_key" ]]; then
    echo "SKIP: OpenAI API 키 조회 실패로 GPT 호출 테스트를 건너뜁니다." | tee -a "$test_log"
    return 0
  fi

  az account set --subscription "$HUB_SUBSCRIPTION_ID" >/dev/null

  local dep result message
  for dep in gpt-41-mini gpt-5-mini; do
    local vm_script
    vm_script=$(
      cat <<EOF
set -eu
echo "--- DNS ($dep) ---"
nslookup "$aoai_host"
echo "--- CALL ($dep) ---"
cat > /tmp/body.json <<'JSON'
{"messages":[{"role":"user","content":"Say OK only"}],"max_completion_tokens":20}
JSON
curl -sS --max-time 60 -o /tmp/resp.json -w "HTTP:%{http_code}\n" "https://$aoai_host/openai/deployments/$dep/chat/completions?api-version=2024-10-21" -H "api-key: $api_key" -H "Content-Type: application/json" -d @/tmp/body.json
head -c 400 /tmp/resp.json
echo
EOF
    )

    message="$(
      az vm run-command invoke \
        -g "$vm_rg" \
        -n "$vm_name" \
        --command-id RunShellScript \
        --scripts "$vm_script" \
        --query "value[0].message" \
        -o tsv 2>&1 || true
    )"

    echo "$message" >> "$test_log"
    if rg -q "HTTP:200" <<< "$message"; then
      result="success"
    else
      result="failed"
    fi
    printf "gpt_test\t%s\t%s\t%s\n" "$dep" "$result" "$test_log" >> "$SUMMARY_TSV"
    echo "GPT 호출 테스트 ($dep): $result" | tee -a "$test_log"
  done
}

echo -e "stack\tleaf\tstatus\tlog_file" > "$SUMMARY_TSV"
echo -e "stack\tleaf\tresource_address" > "$RESOURCE_TSV"

if [[ ! -f "$BOOTSTRAP_TFVARS" ]]; then
  echo "ERROR: $BOOTSTRAP_TFVARS 파일이 없습니다."
  echo "       bootstrap/backend 배포 후 terraform.tfvars를 준비하세요."
  exit 1
fi

print_guide

HUB_SUBSCRIPTION_ID="$(read_guid "Hub 구독 ID 입력")"
SPOKE_SUBSCRIPTION_ID="$(read_guid "Spoke 구독 ID 입력")"

BACKEND_RG="$(get_tfvar_value "resource_group_name" "$BOOTSTRAP_TFVARS")"
BACKEND_SA="$(get_tfvar_value "storage_account_name" "$BOOTSTRAP_TFVARS")"
BACKEND_CONTAINER="$(get_tfvar_value "container_name" "$BOOTSTRAP_TFVARS")"
BACKEND_LOCATION="$(get_tfvar_value "location" "$BOOTSTRAP_TFVARS")"

if [[ -z "$BACKEND_RG" || -z "$BACKEND_SA" || -z "$BACKEND_CONTAINER" ]]; then
  echo "ERROR: bootstrap/backend/terraform.tfvars 에서 backend 값(resource_group_name/storage_account_name/container_name)을 읽지 못했습니다."
  exit 1
fi

SKIP_OPTIONAL_VPN_LEAVES="${SKIP_OPTIONAL_VPN_LEAVES:-true}"

echo
echo "[1/5] Hub/Spoke 구독 Provider 등록/점검 시작..."
ensure_required_providers "$HUB_SUBSCRIPTION_ID"
ensure_required_providers "$SPOKE_SUBSCRIPTION_ID"
echo "[완료] Provider 등록/점검 완료"

# 이후 terraform backend 접근이 안정적이도록 Hub 구독으로 복귀
az account set --subscription "$HUB_SUBSCRIPTION_ID" >/dev/null

echo
echo "[2/5] tfvars 값 동기화 시작..."
while IFS= read -r tfvars; do
  replace_if_key_exists "$tfvars" "hub_subscription_id" "$HUB_SUBSCRIPTION_ID"
  replace_if_key_exists "$tfvars" "spoke_subscription_id" "$SPOKE_SUBSCRIPTION_ID"
  replace_if_key_exists "$tfvars" "backend_resource_group_name" "$BACKEND_RG"
  replace_if_key_exists "$tfvars" "backend_storage_account_name" "$BACKEND_SA"
  replace_if_key_exists "$tfvars" "backend_container_name" "$BACKEND_CONTAINER"
  if [[ -n "$BACKEND_LOCATION" ]]; then
    replace_if_key_exists "$tfvars" "location" "$BACKEND_LOCATION"
  fi
done < <(find "$REPO_ROOT/azure/dev" -type f -name "terraform.tfvars" | sort)
echo "[완료] terraform.tfvars 동기화 완료"

echo
echo "[3/5] backend.hcl 생성 스크립트 실행..."
if [[ -f "$SCRIPT_DIR/generate-backend-hcl.sh" ]]; then
  bash "$SCRIPT_DIR/generate-backend-hcl.sh" | tee "$RUN_LOG_DIR/generate-backend-hcl.log"
else
  echo "WARN: scripts/generate-backend-hcl.sh 파일이 없어 backend.hcl 자동 생성을 건너뜁니다."
fi
ensure_backend_hcl_for_leaves

echo
echo "[4/5] 스택 순차 배포 시작..."
for stack in "${STACK_ORDER[@]}"; do
  echo
  echo "########## DEPLOY STACK: $stack ##########"
  while IFS= read -r leaf; do
    [[ -z "$leaf" ]] && continue
    if [[ "$SKIP_OPTIONAL_VPN_LEAVES" == "true" ]]; then
      case "${leaf#$REPO_ROOT/}" in
        azure/dev/01.network/public-ip/hub-vpn-gateway|azure/dev/01.network/virtual-network-gateway/hub-vpn-gateway)
          printf "%s\t%s\t%s\t%s\n" "$stack" "${leaf#$REPO_ROOT/}" "skipped(optional-vpn)" "-" >> "$SUMMARY_TSV"
          echo "SKIP (optional-vpn): ${leaf#$REPO_ROOT/}"
          continue
          ;;
      esac
    fi
    if [[ ! -f "$leaf/backend.hcl" ]]; then
      printf "%s\t%s\t%s\t%s\n" "$stack" "${leaf#$REPO_ROOT/}" "skipped(no-backend.hcl)" "-" >> "$SUMMARY_TSV"
      echo "SKIP (backend.hcl 없음): ${leaf#$REPO_ROOT/}"
      continue
    fi
    apply_leaf "$stack" "$leaf"
  done < <(collect_leaf_dirs_ordered "$stack")
done

echo
echo "[5/5] 결과 요약"
echo
echo "배포 요약 (stack / leaf / status / log_file)"
if command -v column >/dev/null 2>&1; then
  column -t -s $'\t' "$SUMMARY_TSV"
else
  cat "$SUMMARY_TSV"
fi

echo
echo "스택별 배포 리소스명 (Terraform state address 기준)"
if command -v column >/dev/null 2>&1; then
  column -t -s $'\t' "$RESOURCE_TSV"
else
  cat "$RESOURCE_TSV"
fi

echo
echo "로그 디렉터리: $RUN_LOG_DIR"

echo
test_monitoring_vm_openai
