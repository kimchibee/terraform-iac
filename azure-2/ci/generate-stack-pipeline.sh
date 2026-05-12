#!/usr/bin/env bash
set -euo pipefail

STACK="$1"
BASE_DIR="azure-2/${STACK}"

# Find all leaves (directories containing main.tf)
LEAVES=$(find "${BASE_DIR}" -name "main.tf" -exec dirname {} \; | sort)

cat <<'HEADER'
include:
  - local: 'azure-2/ci/terraform-base.yml'

stages:
HEADER

# Generate stages
for LEAF in ${LEAVES}; do
  LEAF_NAME=$(echo "${LEAF}" | sed "s|azure-2/${STACK}/||" | tr '/' '-')
  echo "  - plan-${LEAF_NAME}"
  echo "  - approve-${LEAF_NAME}"
  echo "  - apply-${LEAF_NAME}"
done

echo ""

# Generate jobs
PREV_APPLY=""
for LEAF in ${LEAVES}; do
  LEAF_NAME=$(echo "${LEAF}" | sed "s|azure-2/${STACK}/||" | tr '/' '-')

  NEEDS_CLAUSE=""
  if [ -n "${PREV_APPLY}" ]; then
    NEEDS_CLAUSE="  needs: [\"${PREV_APPLY}\"]"
  fi

  cat <<EOF

plan-${LEAF_NAME}:
  extends: .terraform-plan
  stage: plan-${LEAF_NAME}
  variables:
    LEAF_DIR: "${LEAF}"
${NEEDS_CLAUSE}

approve-${LEAF_NAME}:
  extends: .terraform-approve
  stage: approve-${LEAF_NAME}
  needs: ["plan-${LEAF_NAME}"]

apply-${LEAF_NAME}:
  extends: .terraform-apply
  stage: apply-${LEAF_NAME}
  needs: ["approve-${LEAF_NAME}", "plan-${LEAF_NAME}"]
EOF

  PREV_APPLY="apply-${LEAF_NAME}"
done
