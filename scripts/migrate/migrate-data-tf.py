#!/usr/bin/env python3
"""data.tf 일괄 변환: state key 경로에 hub/spoke 삽입 + backend var를 hub_/spoke_ 짝으로 치환."""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAPPING_FILE = REPO_ROOT / 'scripts' / 'migrate' / 'leaf-mapping.tsv'

LEAF_TO_TRUNK = {}
with MAPPING_FILE.open() as f:
    for line in f:
        line = line.rstrip('\n')
        if not line or line.startswith('#'):
            continue
        src, trunk = line.split('\t')
        LEAF_TO_TRUNK[src] = trunk

def leaf_path_from_key(key_value):
    m = re.match(r'azure/dev/(.+)/terraform\.tfstate$', key_value)
    if not m:
        return None
    return m.group(1)

def trunk_for_key(key_value):
    leaf = leaf_path_from_key(key_value)
    if leaf is None:
        return None
    return LEAF_TO_TRUNK.get(leaf)

BLOCK_RE = re.compile(
    r'(data\s+"terraform_remote_state"\s+"[^"]+"\s*\{[^}]*?\})',
    re.DOTALL,
)
KEY_RE = re.compile(r'key\s*=\s*"(azure/dev/[^"]+)"')
RG_RE  = re.compile(r'\bvar\.backend_resource_group_name\b')
SA_RE  = re.compile(r'\bvar\.backend_storage_account_name\b')
CN_RE  = re.compile(r'\bvar\.backend_container_name\b')

def transform_block(block):
    key_match = KEY_RE.search(block)
    if not key_match:
        return block, None
    key_value = key_match.group(1)
    trunk = trunk_for_key(key_value)
    if trunk is None:
        print(f'  WARN: cannot classify key {key_value!r}', file=sys.stderr)
        return block, None

    leaf = leaf_path_from_key(key_value)
    new_key = f'azure/dev/{trunk}/{leaf}/terraform.tfstate'
    block = block.replace(key_value, new_key)

    block = RG_RE.sub(f'var.{trunk}_backend_resource_group_name', block)
    block = SA_RE.sub(f'var.{trunk}_backend_storage_account_name', block)
    block = CN_RE.sub(f'var.{trunk}_backend_container_name', block)

    return block, trunk

def transform_file(path):
    text = path.read_text()
    new_text = text
    offset = 0
    trunks_seen = set()
    for m in BLOCK_RE.finditer(text):
        block = m.group(1)
        new_block, trunk = transform_block(block)
        if trunk:
            trunks_seen.add(trunk)
        if new_block != block:
            start = m.start(1) + offset
            end   = m.end(1)   + offset
            new_text = new_text[:start] + new_block + new_text[end:]
            offset += len(new_block) - len(block)
    if new_text != text:
        path.write_text(new_text)
    return trunks_seen

total_files = 0
for path in sorted((REPO_ROOT / 'azure').rglob('data.tf')):
    trunks = transform_file(path)
    if trunks:
        rel = path.relative_to(REPO_ROOT)
        print(f'  {",".join(sorted(trunks))}  {rel}')
        total_files += 1

print(f'\nTransformed {total_files} data.tf files')
