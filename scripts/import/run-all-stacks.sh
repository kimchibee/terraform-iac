#!/usr/bin/env bash
# 모든 leaf를 의존 순서대로 import 실행
# Pre-condition:
#  - scripts/import/env.sh source 됨
#  - leaf-to-resource-map.csv 가 채워져 있음
#  - generate-imports.sh 가 한 번 실행되어 leaf별 imports.tf 가 생성됨
set -euo pipefail

# 스택 순서 (DEPLOY-GUIDE 와 동일)
STACK_ORDER=(
  "01.network/resource-group"
  "01.network/vnet"
  "01.network/subnet"
  "01.network/security-group"
  "01.network/route"
  "01.network/dns"
  "01.network/public-ip"
  "01.network/virtual-network-gateway"
  "02.storage"
  "03.shared-services"
  "04.apim"
  "05.ai-services"
  "06.compute"
  "07.identity"
  "08.rbac"
  "09.connectivity"
)

for prefix in "${STACK_ORDER[@]}"; do
  for side in hub spoke; do
    BASE="azure/$side/$prefix"
    [[ -d "$REPO_ROOT/$BASE" ]] || continue
    # main.tf 있는 leaf 디렉토리 나열
    find "$REPO_ROOT/$BASE" -name main.tf -type f | while read mf; do
      leaf_abs=$(dirname "$mf")
      leaf="${leaf_abs#$REPO_ROOT/}"
      # imports.tf 가 있는 경우에만 실행
      if [[ ! -f "$leaf_abs/imports.tf" ]]; then
        echo "[skip] $leaf (no imports.tf)"
        continue
      fi
      echo "==== $leaf ===="
      "$REPO_ROOT/scripts/import/run-import.sh" "$leaf" || {
        echo "[STOP] $leaf 실패 — 중단"
        exit 1
      }
    done
  done
done

echo "[done] 모든 스택 완료"
