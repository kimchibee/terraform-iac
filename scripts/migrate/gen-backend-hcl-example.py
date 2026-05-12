#!/usr/bin/env python3
"""각 leaf에 backend.hcl.example 생성."""
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAPPING_FILE = REPO_ROOT / 'scripts' / 'migrate' / 'leaf-mapping.tsv'

TEMPLATES = {
    'hub': '''# backend.hcl.example — Hub leaf 전용
#
# 사용법:
#   1) 이 파일을 backend.hcl로 복사 (backend.hcl은 .gitignore 대상)
#   2) terraform init -backend-config=backend.hcl
#
# Hub 구독의 state storage에 저장됨.

resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstatea9911"
container_name       = "tfstate"
key                  = "azure/dev/hub/{leaf_path}/terraform.tfstate"
use_azuread_auth     = false
''',
    'spoke': '''# backend.hcl.example — Spoke leaf 전용
#
# 사용법:
#   1) 이 파일을 backend.hcl로 복사 (backend.hcl은 .gitignore 대상)
#   2) <PLACEHOLDER> 부분을 spoke 구독의 실제 값으로 교체
#   3) terraform init -backend-config=backend.hcl
#
# Spoke 구독의 state storage에 저장됨.

resource_group_name  = "<SPOKE_STATE_RG>"
storage_account_name = "<SPOKE_STATE_STORAGE_ACCOUNT>"
container_name       = "tfstate"
key                  = "azure/dev/spoke/{leaf_path}/terraform.tfstate"
use_azuread_auth     = false
''',
}

count = 0
with MAPPING_FILE.open() as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        leaf_path, trunk = line.split('\t')
        leaf_dir = REPO_ROOT / 'azure' / trunk / leaf_path
        if not leaf_dir.is_dir():
            print(f'  SKIP (missing): {leaf_dir}')
            continue
        out = leaf_dir / 'backend.hcl.example'
        out.write_text(TEMPLATES[trunk].format(leaf_path=leaf_path))
        count += 1

print(f'\nGenerated {count} backend.hcl.example files')
