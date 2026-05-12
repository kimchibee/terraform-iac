#!/usr/bin/env bash
# 매핑 tsv를 읽어 mv로 leaf 디렉터리를 hub/spoke 트리로 재배치
# git mv는 .gitignore된 파일(terraform.tfvars 등)을 옮기지 않으므로
# 일반 mv를 사용. 이후 git add azure/에서 rename으로 감지됨.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MAPPING="${REPO_ROOT}/scripts/migrate/leaf-mapping.tsv"

if [[ ! -f "$MAPPING" ]]; then
  echo "ERROR: mapping not found at $MAPPING" >&2
  exit 1
fi

cd "$REPO_ROOT"

while IFS=$'\t' read -r src_path trunk; do
  src="azure/${src_path}"
  dst_parent="azure/${trunk}/$(dirname "$src_path")"
  dst="azure/${trunk}/${src_path}"

  if [[ ! -d "$src" ]]; then
    echo "SKIP (already moved or missing): $src"
    continue
  fi

  mkdir -p "$dst_parent"
  mv "$src" "$dst"
  echo "MOVED: $src -> $dst"
done < "$MAPPING"
