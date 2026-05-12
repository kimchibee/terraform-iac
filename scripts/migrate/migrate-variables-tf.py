#!/usr/bin/env python3
"""variables.tf 갱신: 기존 backend_* 선언 제거, data.tf에 실제 등장한 hub_/spoke_backend_* 선언 추가."""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

OLD_VAR_RE = re.compile(
    r'(?:^|\n)\s*variable\s+"backend_(?:resource_group_name|storage_account_name|container_name)"\s*\{[^}]*\}',
    re.DOTALL,
)

NEW_VAR_TEMPLATE = {
    'hub': '''
variable "hub_backend_resource_group_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "hub_backend_storage_account_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage account 이름"
}

variable "hub_backend_container_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage container 이름"
}
''',
    'spoke': '''
variable "spoke_backend_resource_group_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "spoke_backend_storage_account_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage account 이름"
}

variable "spoke_backend_container_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage container 이름"
}
''',
}

def trunks_used_by_data_tf(data_tf):
    if not data_tf.exists():
        return set()
    text = data_tf.read_text()
    trunks = set()
    if 'var.hub_backend_' in text:
        trunks.add('hub')
    if 'var.spoke_backend_' in text:
        trunks.add('spoke')
    return trunks

total = 0
for variables_tf in sorted((REPO_ROOT / 'azure').rglob('variables.tf')):
    leaf_dir = variables_tf.parent
    data_tf = leaf_dir / 'data.tf'

    text = variables_tf.read_text()
    new_text = OLD_VAR_RE.sub('', text).rstrip() + '\n'

    # idempotency: don't add hub_backend_* if it already exists in the file
    trunks = trunks_used_by_data_tf(data_tf)
    appended = []
    for trunk in sorted(trunks):
        marker = f'variable "{trunk}_backend_resource_group_name"'
        if marker in new_text:
            continue
        new_text = new_text.rstrip() + '\n' + NEW_VAR_TEMPLATE[trunk]
        appended.append(trunk)

    if new_text != text:
        variables_tf.write_text(new_text)
        rel = variables_tf.relative_to(REPO_ROOT)
        appended_str = ','.join(appended) if appended else '-'
        print(f'  removed-old / added={appended_str}  {rel}')
        total += 1

print(f'\nTransformed {total} variables.tf files')
