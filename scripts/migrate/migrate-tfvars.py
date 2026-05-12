#!/usr/bin/env python3
"""terraform.tfvars / .example 일괄 정리."""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

REMOVE_KEYS = [
    'hub_subscription_id',
    'spoke_subscription_id',
    'backend_resource_group_name',
    'backend_storage_account_name',
    'backend_container_name',
]

HUB_BACKEND_BLOCK = '''
hub_backend_resource_group_name  = "terraform-state-rg"
hub_backend_storage_account_name = "tfstatea9911"
hub_backend_container_name       = "tfstate"
'''.strip()

SPOKE_BACKEND_BLOCK = '''
spoke_backend_resource_group_name  = "<SPOKE_STATE_RG>"
spoke_backend_storage_account_name = "<SPOKE_STATE_STORAGE_ACCOUNT>"
spoke_backend_container_name       = "tfstate"
'''.strip()

EXAMPLE_HEADER = '''# terraform.tfvars.example
#
# 사용법:
#   1) 이 파일을 terraform.tfvars로 복사
#   2) <PLACEHOLDER> 부분을 실제 값으로 교체
#   3) hub_subscription_id, spoke_subscription_id는 본 파일에 두지 않음 —
#      환경변수로 주입: export TF_VAR_hub_subscription_id=...
#                       export TF_VAR_spoke_subscription_id=...
#   4) backend 설정은 별도 backend.hcl 파일을 사용:
#      terraform init -backend-config=backend.hcl
#
'''

EXAMPLE_HEADER_MARKER = '# terraform.tfvars.example'

def remove_keys(text, keys):
    lines = text.splitlines(keepends=True)
    out = []
    for line in lines:
        stripped = line.lstrip()
        if any(stripped.startswith(f'{k} ') or stripped.startswith(f'{k}\t') or stripped.startswith(f'{k}=')
               for k in keys):
            continue
        out.append(line)
    return ''.join(out)

def trunks_declared(leaf_dir):
    variables_tf = leaf_dir / 'variables.tf'
    if not variables_tf.exists():
        return set()
    text = variables_tf.read_text()
    trunks = set()
    if 'variable "hub_backend_resource_group_name"' in text:
        trunks.add('hub')
    if 'variable "spoke_backend_resource_group_name"' in text:
        trunks.add('spoke')
    return trunks

def process(path, is_example):
    leaf_dir = path.parent
    text = path.read_text()

    new_text = remove_keys(text, REMOVE_KEYS)

    trunks = trunks_declared(leaf_dir)

    additions = []
    if 'hub' in trunks and 'hub_backend_resource_group_name' not in new_text:
        additions.append(HUB_BACKEND_BLOCK)
    if 'spoke' in trunks and 'spoke_backend_resource_group_name' not in new_text:
        additions.append(SPOKE_BACKEND_BLOCK)

    if additions:
        new_text = new_text.rstrip() + '\n\n' + '\n\n'.join(additions) + '\n'

    if is_example and EXAMPLE_HEADER_MARKER not in new_text:
        new_text = EXAMPLE_HEADER + new_text.lstrip()

    if new_text != text:
        path.write_text(new_text)
        return True
    return False

total = 0
for path in sorted((REPO_ROOT / 'azure').rglob('terraform.tfvars*')):
    if path.name not in ('terraform.tfvars', 'terraform.tfvars.example'):
        continue
    is_example = path.name == 'terraform.tfvars.example'
    if process(path, is_example):
        rel = path.relative_to(REPO_ROOT)
        print(f'  {"EXAMPLE" if is_example else "TFVARS "}  {rel}')
        total += 1

print(f'\nTransformed {total} tfvars files')
