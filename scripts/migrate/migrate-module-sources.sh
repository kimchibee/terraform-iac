#!/usr/bin/env bash
# main.tf의 GitHub kimchibee 모듈 URL을 내부 GitLab URL로 치환
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

python3 <<'PY'
import re
from pathlib import Path

OLD_RE = re.compile(
    r'git::https://github\.com/kimchibee/terraform-modules\.git//avm/'
    r'(?P<mod>terraform-azurerm-avm-[a-z0-9-]+?)'
    r'(?P<ver>-v\d+\.\d+\.\d+)?'
    r'(?P<sub>/modules/[a-z0-9_]+)?'
    r'\?ref=main'
)
NEW_PREFIX = 'git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/'

def replace(m):
    mod = m.group('mod')
    sub = m.group('sub')
    new_repo = f'{mod}-main.git'
    suffix = f'//{sub.lstrip("/")}' if sub else ''
    return f'{NEW_PREFIX}{new_repo}{suffix}?ref=main'

changed = 0
for path in sorted(Path('azure').rglob('main.tf')):
    text = path.read_text()
    new_text, n = OLD_RE.subn(replace, text)
    if n > 0:
        path.write_text(new_text)
        print(f'{n:>2}  {path}')
        changed += n
print(f'\nTotal lines changed: {changed}')
PY
