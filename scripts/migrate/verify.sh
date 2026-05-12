#!/usr/bin/env bash
# hub/spoke 분리 작업 사후 검증
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

fails=0
note() { echo "[$1/8] $2"; }

note 1 "kimchibee 잔여 (azure/**/*.tf):"
if grep -rq "kimchibee" azure/ --include='*.tf'; then
  echo "  FAIL"
  grep -r "kimchibee" azure/ --include='*.tf'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 2 "legacy state key prefix (azure/dev/<숫자.>... 형식 잔여, 주석 제외):"
if grep -rqE '^\s*[^#]*key\s*=\s*"azure/dev/(0[1-9]|1[0-9])' azure/ --include='*.tf'; then
  echo "  FAIL"
  grep -rE '^\s*[^#]*key\s*=\s*"azure/dev/(0[1-9]|1[0-9])' azure/ --include='*.tf'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 3 "legacy backend_* 변수 참조 (data.tf):"
if grep -rqE '\bvar\.backend_(resource_group_name|storage_account_name|container_name)\b' azure/ --include='data.tf'; then
  echo "  FAIL"
  grep -rE '\bvar\.backend_(resource_group_name|storage_account_name|container_name)\b' azure/ --include='data.tf'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 4 "legacy backend_* 변수 선언 (variables.tf):"
if grep -rqE 'variable\s+"backend_(resource_group_name|storage_account_name|container_name)"' azure/ --include='variables.tf'; then
  echo "  FAIL"
  grep -rE 'variable\s+"backend_(resource_group_name|storage_account_name|container_name)"' azure/ --include='variables.tf'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 5 "tfvars에 subscription_id 잔여:"
if grep -rqE '^\s*(hub|spoke)_subscription_id\s*=' azure/ --include='terraform.tfvars*'; then
  echo "  FAIL"
  grep -rE '^\s*(hub|spoke)_subscription_id\s*=' azure/ --include='terraform.tfvars*'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 6 "tfvars에 legacy backend_* 잔여:"
if grep -rqE '^\s*backend_(resource_group_name|storage_account_name|container_name)\s*=' azure/ --include='terraform.tfvars*'; then
  echo "  FAIL"
  grep -rE '^\s*backend_(resource_group_name|storage_account_name|container_name)\s*=' azure/ --include='terraform.tfvars*'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 7 "모든 module source가 dev-gitlab.kis.zone 사용:"
non_gitlab=$(grep -rh 'source\s*=\s*"git::' azure/ --include='*.tf' 2>/dev/null | grep -vc 'dev-gitlab\.kis\.zone' 2>/dev/null || true)
non_gitlab="${non_gitlab:-0}"
non_gitlab="${non_gitlab// /}"
if [[ "$non_gitlab" -gt 0 ]]; then
  echo "  FAIL: $non_gitlab non-GitLab git:: sources"
  grep -rh 'source\s*=\s*"git::' azure/ --include='*.tf' | grep -v 'dev-gitlab\.kis\.zone'
  fails=$((fails+1))
else
  echo "  OK"
fi

note 8 "leaf 카운트 (azure/hub 37 / azure/spoke 23):"
hub_count=$(find azure/hub -mindepth 1 -name main.tf -not -path "*/modules/*" | wc -l | tr -d ' ')
spoke_count=$(find azure/spoke -mindepth 1 -name main.tf -not -path "*/modules/*" | wc -l | tr -d ' ')
if [[ "$hub_count" == "37" && "$spoke_count" == "23" ]]; then
  echo "  OK (hub=$hub_count, spoke=$spoke_count)"
else
  echo "  FAIL (hub=$hub_count expected 37, spoke=$spoke_count expected 23)"
  fails=$((fails+1))
fi

echo
echo "=== Total failures: $fails ==="
echo
echo "Note: terraform init -backend=false && terraform validate는 GitLab 접근 가능 환경에서"
echo "      운영자가 별도 수행. 본 스크립트는 정적 grep 검증만 수행."

exit "$fails"
