#!/usr/bin/env bash
set -euo pipefail
# 모든 leaf (main.tf가 있는 디렉토리) 의 상대 경로 출력
cd "$REPO_ROOT"
find azure -name main.tf -type f \
  -not -path 'azure/ci/*' -not -path 'azure/script/*' \
  | xargs -n1 dirname | sort
