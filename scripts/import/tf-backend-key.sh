#!/usr/bin/env bash
# leaf 경로 → backend state key 변환
# 예: azure/hub/01.network/resource-group/hub-rg
#  → azure/dev/hub/01.network/resource-group/hub-rg/terraform.tfstate
set -euo pipefail

LEAF="${1:?leaf path required (e.g. azure/hub/01.network/.../hub-rg)}"
# azure/ 제거 후 dev/ 삽입
SUFFIX="${LEAF#azure/}"
echo "azure/dev/${SUFFIX}/terraform.tfstate"
