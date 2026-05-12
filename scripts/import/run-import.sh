#!/usr/bin/env bash
# 단일 leaf에 대해 init → plan → apply 일괄 실행, run-log.csv에 기록
# Pre-condition: imports.tf 가 leaf 디렉토리에 이미 생성되어 있음
set -euo pipefail

LEAF="${1:?leaf path}"
LOG="$IMPORT_DOC_DIR/run-log.csv"
STARTED=$(date -u +%FT%TZ)

cd "$REPO_ROOT"

echo "[run-import] $LEAF — init"
"$REPO_ROOT/scripts/import/tf-init-leaf.sh" "$LEAF" >/dev/null

echo "[run-import] $LEAF — plan"
cd "$REPO_ROOT/$LEAF"
PLAN_OUT=$(terraform plan -out=plan.out -input=false -no-color 2>&1)
SUMMARY=$(echo "$PLAN_OUT" | grep -E '^Plan: ' | head -1)
echo "  $SUMMARY"

# "0 to change, 0 to destroy" 확인
if ! echo "$SUMMARY" | grep -qE '0 to change, 0 to destroy'; then
  echo "[run-import] $LEAF — DIFF DETECTED, NOT APPLYING"
  echo "$LEAF,$STARTED,\"$SUMMARY\",,diff-detected" >> "$LOG"
  exit 2
fi

echo "[run-import] $LEAF — apply"
terraform apply -input=false plan.out >/dev/null
APPLIED=$(date -u +%FT%TZ)

# imports.tf 제거 후 sanity plan
rm -f imports.tf plan.out
terraform plan -no-color > /tmp/sanity.log 2>&1 || true
if grep -q "No changes" /tmp/sanity.log; then
  STATUS="success"
else
  STATUS="sanity-diff"
fi

echo "$LEAF,$STARTED,\"$SUMMARY\",$APPLIED,$STATUS" >> "$LOG"
echo "[run-import] $LEAF — $STATUS"
