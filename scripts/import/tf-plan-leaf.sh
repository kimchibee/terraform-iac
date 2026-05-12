#!/usr/bin/env bash
set -euo pipefail
LEAF="${1:?leaf path}"
cd "$REPO_ROOT/$LEAF"
terraform plan -out=plan.out -input=false -no-color | tee /tmp/plan-out.log
# 요약 라인 추출
grep -E '^Plan: ' /tmp/plan-out.log | head -1 || true
