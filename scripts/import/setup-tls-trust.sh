#!/usr/bin/env bash
# setup-tls-trust.sh — 회사 네트워크의 TLS 인터셉션(Zscaler/Netskope 등) 환경에서
# az CLI(Python) 와 Terraform(Go) 둘 다 CA 신뢰 문제를 해결.
#
# 동작:
#   1. macOS Keychain (System + System Roots + Login) 에서 모든 CA 를 PEM 추출
#   2. Python certifi 번들과 합쳐 ~/.config/terraform-iac/combined-ca.pem 생성
#   3. REQUESTS_CA_BUNDLE / SSL_CERT_FILE / CURL_CA_BUNDLE export
#      - SSL_CERT_FILE 은 Go(=Terraform)도 honor → 한 번에 해결
#
# Usage:
#   source scripts/import/setup-tls-trust.sh    # 권장 — 현재 셸에 export 적용
#   ./scripts/import/setup-tls-trust.sh         # 파일만 생성, export 는 안내만
#
# 멱등: 매번 실행해도 동일 결과. 회사 CA 가 Keychain 에 새로 추가됐을 때 재실행하면
# combined-ca.pem 이 자동 갱신됨.

set -uo pipefail

# ───────── sourced 인지 executed 인지 판별 (bash + zsh 호환) ─────────
_sourced=0
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "$0" ]]; then
  _sourced=1
elif [[ "${ZSH_EVAL_CONTEXT:-}" == *:file* ]]; then
  _sourced=1
fi

_die() {
  echo "ERROR: $1" >&2
  if [[ $_sourced -eq 1 ]]; then return "${2:-1}" 2>/dev/null; else exit "${2:-1}"; fi
}

# ───────── macOS 만 지원 ─────────
if [[ "$(uname)" != "Darwin" ]]; then
  _die "macOS 전용. Linux 는 update-ca-certificates (Debian) 또는 update-ca-trust (RHEL) 사용." 2
fi

# ───────── python3 + certifi 확인 ─────────
if ! command -v python3 >/dev/null 2>&1; then
  _die "python3 가 PATH 에 없습니다. 'brew install python' 또는 az CLI 제공 python 사용." 3
fi
PY_CA=$(python3 -c 'import certifi; print(certifi.where())' 2>/dev/null || true)
if [[ -z "$PY_CA" || ! -f "$PY_CA" ]]; then
  _die "Python certifi 번들 위치 확인 실패. 'python3 -m pip install certifi' 시도하세요." 3
fi

# ───────── 출력 경로 ─────────
TLS_DIR="${HOME}/.config/terraform-iac"
TLS_PEM="${TLS_DIR}/combined-ca.pem"
mkdir -p "$TLS_DIR"

# ───────── PEM 생성 (certifi + macOS Keychains) ─────────
echo "[setup-tls-trust] macOS Keychain CA 추출 + Python certifi 결합 중..."

TMP_PEM="$(mktemp -t setup-tls-trust.XXXXXX)"
{
  cat "$PY_CA"
  echo ""
  echo "# --- macOS System.keychain ---"
  security find-certificate -a -p /Library/Keychains/System.keychain 2>/dev/null || true
  echo ""
  echo "# --- macOS SystemRootCertificates.keychain ---"
  security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null || true
  LOGIN_KC="${HOME}/Library/Keychains/login.keychain-db"
  if [[ -f "$LOGIN_KC" ]]; then
    echo ""
    echo "# --- ~/Library/Keychains/login.keychain-db ---"
    security find-certificate -a -p "$LOGIN_KC" 2>/dev/null || true
  fi
} > "$TMP_PEM"

# 원자적 교체
mv -f "$TMP_PEM" "$TLS_PEM"

# 통계
CERTS=$(grep -c -- "-----BEGIN CERTIFICATE-----" "$TLS_PEM" 2>/dev/null || echo 0)
echo "[setup-tls-trust] 완료: $TLS_PEM"
echo "  certifi 기본: $PY_CA"
echo "  총 인증서 수: $CERTS"

# ───────── export ─────────
export REQUESTS_CA_BUNDLE="$TLS_PEM"
export SSL_CERT_FILE="$TLS_PEM"
export CURL_CA_BUNDLE="$TLS_PEM"

if [[ $_sourced -eq 1 ]]; then
  echo "[setup-tls-trust] 현재 셸에 export 적용됨:"
  echo "  REQUESTS_CA_BUNDLE / SSL_CERT_FILE / CURL_CA_BUNDLE = $TLS_PEM"
  echo "  → az CLI (Python) + Terraform (Go) 둘 다 이 번들 사용"
else
  echo ""
  echo "[setup-tls-trust] 이 스크립트가 'source' 되지 않아 export 가 현재 셸에 적용 안 됨."
  echo "  다음 중 하나로 적용:"
  echo ""
  echo "  (a) 한 번만 적용:"
  echo "      source ${BASH_SOURCE[0]:-$0}"
  echo ""
  echo "  (b) 영구 적용 — 셸 rc 파일 (~/.zshrc 또는 ~/.bashrc) 에 추가:"
  echo "      [[ -f \"$TLS_PEM\" ]] && {"
  echo "        export REQUESTS_CA_BUNDLE=\"$TLS_PEM\""
  echo "        export SSL_CERT_FILE=\"$TLS_PEM\""
  echo "        export CURL_CA_BUNDLE=\"$TLS_PEM\""
  echo "      }"
  echo ""
  echo "  (c) scripts/import/env.sh 가 자동으로 위 PEM 을 감지해 export 합니다."
  echo "      'source scripts/import/env.sh' 하시면 자동 적용됨."
fi

unset _sourced TMP_PEM CERTS PY_CA TLS_DIR LOGIN_KC
