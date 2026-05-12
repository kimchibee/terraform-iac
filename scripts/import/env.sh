#!/usr/bin/env bash
# 공통 환경변수 — 작업 시작 시 `source scripts/import/env.sh` 로 로드

# 대상 구독
export AZ_SUB="20e3a0f3-f1af-4cc5-8092-dc9b276a9911"

# Terraform backend (state SA)
export TF_BACKEND_RG="terraform-state-rg"
export TF_BACKEND_SA="tfstatea9911"
export TF_BACKEND_CONTAINER="tfstate"

# Terraform 변수: subscription_id는 spec §5.1에 따라 환경변수로만 주입
export TF_VAR_hub_subscription_id="$AZ_SUB"
export TF_VAR_spoke_subscription_id="$AZ_SUB"

# 리포 루트 (스크립트에서 사용)
# Resolve script directory in both bash (BASH_SOURCE) and zsh ($0 when sourced)
_env_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export REPO_ROOT="$(cd "$_env_sh_dir/../.." && pwd)"
unset _env_sh_dir
export AZURE_ROOT="$REPO_ROOT/azure"
export IMPORT_DOC_DIR="$REPO_ROOT/docs/import"
