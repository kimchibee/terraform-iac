#!/usr/bin/env bash
set -euo pipefail

# 전제: scripts/import/env.sh 가 source 되어 있음

OUT_JSON="$IMPORT_DOC_DIR/inventory.json"
OUT_CSV="$IMPORT_DOC_DIR/inventory.csv"

echo "[1/3] az resource list 실행..."
az resource list --subscription "$AZ_SUB" -o json > "$OUT_JSON"

echo "[2/3] CSV 변환..."
jq -r '
  ["id","type","resourceGroup","name","location"],
  (.[] | [.id, .type, .resourceGroup, .name, .location])
  | @csv
' "$OUT_JSON" > "$OUT_CSV"

echo "[3/3] 요약"
echo "총 리소스: $(jq 'length' "$OUT_JSON")"
echo "RG별:"
jq -r 'group_by(.resourceGroup) | .[] | "\(.[0].resourceGroup): \(length)"' "$OUT_JSON" | sort

echo "산출: $OUT_JSON, $OUT_CSV"
