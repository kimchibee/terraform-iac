#!/usr/bin/env bash
# diagnose-tls-trust.sh — TLS 신뢰 셋업 상태 종합 진단
#
# 6 섹션 진단:
#   1. 환경변수 (REQUESTS_CA_BUNDLE / SSL_CERT_FILE / CURL_CA_BUNDLE)
#   2. Combined CA PEM 파일 상태
#   3. management.azure.com 인증서 체인의 issuer (인터셉션 여부)
#   4. 같은 PEM 으로 curl 직접 테스트
#   5. az CLI 가 사용하는 Python 위치 (자체 번들 vs 시스템)
#   6. Verdict + 권장 다음 단계
#
# Usage:
#   ./scripts/import/diagnose-tls-trust.sh
#   ./scripts/import/diagnose-tls-trust.sh --pem /path/to/other-ca.pem  # 다른 PEM 테스트
#   ./scripts/import/diagnose-tls-trust.sh --url https://other.example  # 다른 endpoint
set -uo pipefail

PEM_OVERRIDE=""
URL="https://management.azure.com"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pem) PEM_OVERRIDE="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 2 ;;
    *) echo "ERROR: 알 수 없는 옵션 $1" >&2; exit 2 ;;
  esac
done
HOST=$(echo "$URL" | sed -E 's|^https?://||; s|/.*$||')

hr()    { printf '%s\n' "----------------------------------------------------------------------"; }
title() { printf '\n[%s] %s\n' "$1" "$2"; hr; }

ENV_OK="false"
PEM_OK="false"
PEM_PATH=""
INTERCEPT_DETECTED="unknown"
INTERCEPT_ISSUER=""
CURL_OK="false"
AZ_PYTHON_TYPE="unknown"

# ─── 1. env vars 상태 ─────────────────────────────────────────────────────
title 1/6 "환경변수 상태"
printf "REQUESTS_CA_BUNDLE = %s\n" "${REQUESTS_CA_BUNDLE:-<unset>}"
printf "SSL_CERT_FILE      = %s\n" "${SSL_CERT_FILE:-<unset>}"
printf "CURL_CA_BUNDLE     = %s\n" "${CURL_CA_BUNDLE:-<unset>}"

if [[ -n "${REQUESTS_CA_BUNDLE:-}" || -n "${SSL_CERT_FILE:-}" ]]; then
  ENV_OK="true"
  PEM_PATH="${REQUESTS_CA_BUNDLE:-${SSL_CERT_FILE}}"
  echo "✓ TLS env vars 셋되어 있음"
else
  echo "✗ TLS env vars 미셋"
fi

[[ -n "$PEM_OVERRIDE" ]] && PEM_PATH="$PEM_OVERRIDE" && echo "  --pem override: $PEM_PATH"

# ─── 2. Combined CA PEM 파일 상태 ─────────────────────────────────────────
title 2/6 "Combined CA PEM 파일"
DEFAULT_PEM="${HOME}/.config/terraform-iac/combined-ca.pem"
[[ -z "$PEM_PATH" ]] && PEM_PATH="$DEFAULT_PEM" && echo "  (env 미셋 — 기본 경로 시도)"
echo "대상: $PEM_PATH"

if [[ -f "$PEM_PATH" ]]; then
  CERT_COUNT=$(grep -c -- "-----BEGIN CERTIFICATE-----" "$PEM_PATH" 2>/dev/null || echo 0)
  echo "✓ 파일 존재, 인증서 $CERT_COUNT 개"
  if [[ $CERT_COUNT -lt 50 ]]; then
    echo "  WARN: 인증서 수가 비정상적으로 적음 (보통 200+ 예상)"
  fi
  PEM_OK="true"
else
  echo "✗ 파일 없음 → setup-tls-trust.sh 실행 필요"
fi

# ─── 3. 인터셉팅 CA 식별 ──────────────────────────────────────────────────
title 3/6 "$HOST 인증서 체인 issuer"
CERT_INFO=$(echo | openssl s_client -connect "$HOST:443" \
  -servername "$HOST" 2>/dev/null \
  | openssl x509 -noout -issuer -subject 2>/dev/null || true)

if [[ -z "$CERT_INFO" ]]; then
  echo "✗ openssl s_client 응답 없음 (네트워크 또는 openssl 문제)"
else
  echo "$CERT_INFO"
  INTERCEPT_ISSUER=$(echo "$CERT_INFO" | grep -i '^issuer' | head -1)
  if echo "$CERT_INFO" | grep -qiE 'Zscaler|Netskope|BlueCoat|Forcepoint|McAfee|Sophos|Cisco.?Umbrella|FortiGate|Palo.?Alto|Symantec.?Proxy|Squid|MITM'; then
    INTERCEPT_DETECTED="yes"
    echo ""
    echo "✗ TLS 인터셉션 감지 (회사 프록시 vendor 패턴)"
  elif echo "$CERT_INFO" | grep -qiE 'Microsoft|DigiCert|GlobalSign|Let.?s Encrypt|GoDaddy|VeriSign|Sectigo|Amazon|Google'; then
    INTERCEPT_DETECTED="no"
    echo ""
    echo "✓ 정상 issuer — 인터셉션 없음"
  else
    INTERCEPT_DETECTED="maybe"
    echo ""
    echo "⚠ 알려진 패턴에 안 맞음 — 회사 내부 CA 일 가능성. 직접 판단 필요."
  fi
fi

# ─── 4. curl 직접 테스트 ──────────────────────────────────────────────────
title 4/6 "curl --cacert 으로 $URL 직접 테스트"
if [[ -f "$PEM_PATH" ]]; then
  CURL_OUT=$(curl --cacert "$PEM_PATH" --max-time 8 -sS -I "$URL" 2>&1 | head -3)
  echo "$CURL_OUT"
  if echo "$CURL_OUT" | grep -qE '^HTTP/'; then
    CURL_OK="true"
    echo "✓ curl 성공 — PEM 으로 $HOST 검증 OK"
  elif echo "$CURL_OUT" | grep -qiE 'SSL certificate problem|self.signed|unable to get local issuer|certificate verify failed'; then
    echo "✗ SSL 에러 — PEM 에 필요한 CA 가 빠져있음"
  else
    echo "⚠ 미정 결과 — 출력 직접 확인"
  fi
else
  echo "- PEM 파일 없어 스킵"
fi

# ─── 5. az CLI Python 환경 ───────────────────────────────────────────────
title 5/6 "az CLI Python 환경"
AZ_BIN=$(command -v az 2>/dev/null || echo "")
if [[ -z "$AZ_BIN" ]]; then
  echo "✗ az 명령 없음"
else
  AZ_VER=$(az --version 2>&1 | head -10)
  echo "$AZ_VER" | head -3
  echo ""
  AZ_REAL=$(readlink "$AZ_BIN" 2>/dev/null || echo "$AZ_BIN")
  [[ "$AZ_REAL" != /* ]] && AZ_REAL="$(cd "$(dirname "$AZ_BIN")" && pwd)/$AZ_REAL"
  echo "az binary: $AZ_BIN"
  echo "az target: $AZ_REAL"

  # Python 위치 파싱 시도 (az --version 출력)
  AZ_PYTHON=$(echo "$AZ_VER" | grep -iE "python.+location" | sed -E "s|.*[Ll]ocation[: ']+||; s|'.*$||" | head -1)
  if [[ -n "$AZ_PYTHON" && -f "$AZ_PYTHON" ]]; then
    echo "az Python: $AZ_PYTHON"
  fi

  # az 바이너리 경로 기반으로 설치 타입 판별 (../ 등 unresolved 도 매칭되게)
  if echo "$AZ_REAL $AZ_PYTHON" | grep -qE 'Cellar|homebrew'; then
    AZ_PYTHON_TYPE="brew"
    echo "→ Homebrew 설치 — REQUESTS_CA_BUNDLE 정상 honor"
  elif echo "$AZ_REAL $AZ_PYTHON" | grep -qiE 'microsoft|/opt/az|Azure SDK'; then
    AZ_PYTHON_TYPE="official"
    echo "→ 공식 .pkg/.msi — 자체 번들 python. REQUESTS_CA_BUNDLE 무시 가능성 있음"
  elif [[ -n "$AZ_BIN" ]]; then
    AZ_PYTHON_TYPE="other"
    echo "→ 위 경로 기준 분류 안 됨 — 동작은 보통 OK"
  fi
fi

# ─── 6. Verdict + 다음 단계 ───────────────────────────────────────────────
title 6/6 "Verdict + 권장 다음 단계"

if [[ "$ENV_OK" == "false" && "$PEM_OK" == "false" ]]; then
  cat <<EOF
✗ 셋업 자체가 안 됨 — env vars 도 PEM 도 없음

  source scripts/import/setup-tls-trust.sh
EOF
elif [[ "$ENV_OK" == "false" && "$PEM_OK" == "true" ]]; then
  cat <<EOF
✗ PEM 은 있는데 env vars 가 현재 셸에 export 안 됨

  source scripts/import/env.sh
EOF
elif [[ "$PEM_OK" == "false" ]]; then
  cat <<EOF
✗ env var 가 가리키는 PEM 파일이 없음 — 경로 확인 또는 재생성

  source scripts/import/setup-tls-trust.sh
EOF
elif [[ "$CURL_OK" == "true" && "$AZ_PYTHON_TYPE" == "official" ]]; then
  AZ_CERTIFI=""
  if [[ -n "${AZ_PYTHON:-}" && -f "${AZ_PYTHON:-/dev/null}" ]]; then
    AZ_CERTIFI=$("$AZ_PYTHON" -c 'import certifi; print(certifi.where())' 2>/dev/null || true)
  fi
  cat <<EOF
⚠ curl 은 OK 인데 az 가 자체 번들 python 을 사용

방법 A (권장) — Homebrew 로 재설치:
  brew install azure-cli   # 또는 'brew reinstall azure-cli'

방법 B — az 자체 certifi 번들에 PEM 내용 append:
  AZ_CERTIFI="$AZ_CERTIFI"
  sudo cp "\$AZ_CERTIFI" "\$AZ_CERTIFI.bak"
  sudo cp "$PEM_PATH" "\$AZ_CERTIFI"

방법 C — 임시: az 호출 시 env override
  REQUESTS_CA_BUNDLE="$PEM_PATH" SSL_CERT_FILE="$PEM_PATH" az <cmd>
EOF
elif [[ "$CURL_OK" == "true" ]]; then
  cat <<EOF
✓ 모든 진단 통과 — TLS 셋업 정상

curl 성공 + env vars OK + PEM OK + az Python 정상. 그래도 az 가 SSL 에러 내면
az 버전이 오래된 가능성: 'brew upgrade azure-cli'
EOF
elif [[ "$INTERCEPT_DETECTED" == "yes" ]]; then
  cat <<EOF
✗ 회사 TLS 인터셉션 활성 + 현재 PEM 에 회사 CA 부재

  $INTERCEPT_ISSUER

→ IT 에 회사 root CA 파일 (.crt 또는 .pem) 요청 후:

  방법 A: 받은 파일을 setup 스크립트로 합치기 (--add-ca 옵션 예정)
    source scripts/import/setup-tls-trust.sh --add-ca /path/to/corp-root.crt

  방법 B: 즉시 수동 합치기
    cat /path/to/corp-root.crt >> "$PEM_PATH"
    재시도: ./scripts/import/diagnose-tls-trust.sh
EOF
else
  cat <<EOF
⚠ curl 실패하지만 인터셉션 명확치 않음

가능 원인:
  - VPN/프록시 비활성
  - 회사 내부 CA — IT 에 root CA 요청
  - PEM 손상 — 다음으로 재생성: source scripts/import/setup-tls-trust.sh
EOF
fi

hr
echo "Verdict 코드: env_ok=$ENV_OK  pem_ok=$PEM_OK  intercept=$INTERCEPT_DETECTED  curl_ok=$CURL_OK  az_python=$AZ_PYTHON_TYPE"
