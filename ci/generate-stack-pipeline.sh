#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 스택별 GitLab child pipeline YAML 동적 생성
# Usage: bash ci/generate-stack-pipeline.sh <stack-name>
# Example: bash ci/generate-stack-pipeline.sh 01.network > ci/generated/01-network.yml
# Compatible: bash 3.2+ (macOS), ash (Alpine)
# ------------------------------------------------------------------------------
set -euo pipefail

STACK="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_DIR="$REPO_ROOT/azure/dev/$STACK"
SKIP_OPTIONAL_VPN="${SKIP_OPTIONAL_VPN_LEAVES:-true}"

# leaf 경로에서 job 이름용 slug 생성
slugify() {
  echo "$1" | tr '/' '-' | tr '.' '-' | tr ' ' '-'
}

# wave 이름 → leaf 목록 반환
get_wave_leaves() {
  local wave="$1"
  case "$wave" in
    01-resource-groups)
      echo "resource-group/hub-rg resource-group/spoke-rg" ;;
    02-vnets)
      echo "vnet/hub-vnet vnet/spoke-vnet" ;;
    03-subnets)
      echo "subnet/hub-gateway-subnet subnet/hub-dnsresolver-inbound-subnet subnet/hub-azurefirewall-subnet subnet/hub-azurefirewall-management-subnet subnet/hub-appgateway-subnet subnet/hub-monitoring-vm-subnet subnet/hub-pep-subnet subnet/spoke-apim-subnet subnet/spoke-pep-subnet" ;;
    04-asg-nsg)
      echo "security-group/application-security-group/keyvault-clients security-group/application-security-group/vm-allowed-clients security-group/network-security-group/keyvault-standalone security-group/network-security-group/hub-pep security-group/network-security-group/hub-monitoring-vm security-group/network-security-group/spoke-pep" ;;
    05-security-policy)
      echo "security-group/security-policy/hub-sg-policy-default security-group/security-policy/spoke-sg-policy-default security-group/network-security-rule/hub-monitoring-vm-allow-vm-clients-22 security-group/network-security-rule/hub-monitoring-vm-allow-vm-clients-3389 security-group/network-security-rule/hub-monitoring-vm-allow-keyvault-outbound security-group/network-security-rule/hub-pep-allow-keyvault-clients-443 security-group/network-security-rule/hub-pep-allow-keyvault-outbound" ;;
    06-nsg-association)
      echo "security-group/subnet-network-security-group-association/hub-monitoring-vm-subnet security-group/subnet-network-security-group-association/hub-pep-subnet security-group/subnet-network-security-group-association/spoke-pep-subnet" ;;
    07-routes)
      echo "route/hub-route-default route/spoke-route-default" ;;
    08-dns-zones)
      echo "dns/private-dns-zone/hub-blob dns/private-dns-zone/hub-vault dns/private-dns-zone/spoke-openai dns/private-dns-zone/spoke-cognitiveservices dns/private-dns-zone/spoke-azure-api dns/private-dns-zone/spoke-ml dns/private-dns-zone/spoke-notebooks" ;;
    09-dns-links)
      echo "dns/private-dns-zone-vnet-link/hub-blob-to-hub-vnet dns/private-dns-zone-vnet-link/hub-openai-to-hub-vnet dns/private-dns-zone-vnet-link/hub-vault-to-hub-vnet dns/private-dns-zone-vnet-link/spoke-openai-to-spoke-vnet dns/private-dns-zone-vnet-link/spoke-cognitiveservices-to-spoke-vnet dns/private-dns-zone-vnet-link/spoke-azure-api-to-spoke-vnet dns/private-dns-zone-vnet-link/spoke-ml-to-spoke-vnet dns/private-dns-zone-vnet-link/spoke-notebooks-to-spoke-vnet" ;;
    10-dns-resolver)
      echo "dns/dns-private-resolver/hub dns/dns-private-resolver-inbound-endpoint/hub" ;;
    11-vpn-gateway)
      echo "public-ip/hub-vpn-gateway virtual-network-gateway/hub-vpn-gateway" ;;
  esac
}

NETWORK_WAVE_ORDER="01-resource-groups 02-vnets 03-subnets 04-asg-nsg 05-security-policy 06-nsg-association 07-routes 08-dns-zones 09-dns-links 10-dns-resolver 11-vpn-gateway"

# 일반 스택: leaf 목록 수집 (알파벳순)
collect_leaves() {
  local stack_dir="$1"
  find "$stack_dir" \
    -type d \( -name ".terraform" -o -name ".git" -o -name "modules" \) -prune -o \
    -type f -name "main.tf" -print | while IFS= read -r f; do
    local d
    d="$(dirname "$f")"
    if [ -f "$d/backend.tf" ]; then
      echo "${d#$REPO_ROOT/}"
    fi
  done | sort -u
}

# ===========================================================================
# YAML 생성 시작
# ===========================================================================

if [ "$STACK" = "01.network" ]; then
  # ---- 01.network: wave 기반 pipeline ----

  echo "include:"
  echo "  - local: ci/templates/terraform-base.yml"
  echo ""
  echo "stages:"
  for wave in $NETWORK_WAVE_ORDER; do
    if [ "$SKIP_OPTIONAL_VPN" = "true" ] && [ "$wave" = "11-vpn-gateway" ]; then
      continue
    fi
    echo "  - plan-${wave}"
    echo "  - approve-${wave}"
    echo "  - apply-${wave}"
  done
  echo ""

  prev_wave=""
  for wave in $NETWORK_WAVE_ORDER; do
    if [ "$SKIP_OPTIONAL_VPN" = "true" ] && [ "$wave" = "11-vpn-gateway" ]; then
      continue
    fi

    leaves="$(get_wave_leaves "$wave")"
    plan_jobs=""

    # Plan jobs
    for leaf in $leaves; do
      leaf_dir="azure/dev/$STACK/$leaf"
      [ -d "$REPO_ROOT/$leaf_dir" ] || continue

      slug="$(slugify "$leaf")"
      plan_job="plan:${slug}"
      plan_jobs="${plan_jobs} ${plan_job}"

      echo "\"${plan_job}\":"
      echo "  extends: .terraform-plan"
      echo "  stage: plan-${wave}"
      echo "  variables:"
      echo "    LEAF_DIR: ${leaf_dir}"
      if [ -n "$prev_wave" ]; then
        echo "  needs: [\"approve:${prev_wave}\"]"
      fi
      echo ""
    done

    # Approve gate (수동 승인)
    echo "\"approve:${wave}\":"
    echo "  stage: approve-${wave}"
    echo "  script:"
    echo "    - echo \"Wave ${wave} approved\""
    echo "  when: manual"
    echo "  allow_failure: false"
    if [ -n "$plan_jobs" ]; then
      echo "  needs:"
      for pj in $plan_jobs; do
        echo "    - \"${pj}\""
      done
    fi
    echo ""

    # Apply jobs
    for leaf in $leaves; do
      leaf_dir="azure/dev/$STACK/$leaf"
      [ -d "$REPO_ROOT/$leaf_dir" ] || continue

      slug="$(slugify "$leaf")"
      plan_job="plan:${slug}"

      echo "\"apply:${slug}\":"
      echo "  extends: .terraform-apply"
      echo "  stage: apply-${wave}"
      echo "  variables:"
      echo "    LEAF_DIR: ${leaf_dir}"
      echo "  needs:"
      echo "    - \"approve:${wave}\""
      echo "    - job: \"${plan_job}\""
      echo "      artifacts: true"
      echo ""
    done

    prev_wave="$wave"
  done

else
  # ---- 일반 스택: leaf별 순차 pipeline ----

  echo "include:"
  echo "  - local: ci/templates/terraform-base.yml"
  echo ""

  # stages 수집
  leaf_list=""
  while IFS= read -r leaf; do
    [ -z "$leaf" ] && continue
    leaf_list="${leaf_list}${leaf_list:+|}${leaf}"
  done < <(collect_leaves "$STACK_DIR")

  # stages 출력
  echo "stages:"
  IFS='|'
  for leaf_dir in $leaf_list; do
    leaf_name="${leaf_dir#azure/dev/$STACK/}"
    slug="$(slugify "$leaf_name")"
    echo "  - plan-${slug}"
    echo "  - approve-${slug}"
    echo "  - apply-${slug}"
  done
  unset IFS
  echo ""

  # jobs 출력
  prev_slug=""
  IFS='|'
  for leaf_dir in $leaf_list; do
    leaf_name="${leaf_dir#azure/dev/$STACK/}"
    slug="$(slugify "$leaf_name")"

    # Plan
    echo "\"plan:${slug}\":"
    echo "  extends: .terraform-plan"
    echo "  stage: plan-${slug}"
    echo "  variables:"
    echo "    LEAF_DIR: ${leaf_dir}"
    if [ -n "$prev_slug" ]; then
      echo "  needs: [\"apply:${prev_slug}\"]"
    fi
    echo ""

    # Approve
    echo "\"approve:${slug}\":"
    echo "  stage: approve-${slug}"
    echo "  script:"
    echo "    - echo \"${leaf_name} approved\""
    echo "  when: manual"
    echo "  allow_failure: false"
    echo "  needs: [\"plan:${slug}\"]"
    echo ""

    # Apply
    echo "\"apply:${slug}\":"
    echo "  extends: .terraform-apply"
    echo "  stage: apply-${slug}"
    echo "  variables:"
    echo "    LEAF_DIR: ${leaf_dir}"
    echo "  needs:"
    echo "    - \"approve:${slug}\""
    echo "    - job: \"plan:${slug}\""
    echo "      artifacts: true"
    echo ""

    prev_slug="$slug"
  done
  unset IFS
fi
