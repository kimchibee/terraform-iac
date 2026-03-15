# 아키텍처 점검 보고서 (이미지 기준)

이미지에 나온 **Hub–Spoke + Private DNS Zone(이중 구성)** 아키텍처에 맞춰, 각 스택 배포 상태를 점검한 결과입니다.  
점검 일자: 2026-03-15 기준 (test 환경).

---

## 1. 점검 요약

| 구분 | 이미지 요구사항 | 배포 상태 | 비고 |
|------|-----------------|-----------|------|
| Hub VNet (test-x-x-rg / test-x-x-vnet) | RG, VNet(대역), 서브넷, VPN GW, Azure Firewall, DNS Resolver | ✅ 일치 | 10.0.0.0/20, 7개 서브넷 |
| Hub Private DNS Zones | blob, key vault, monitor, openai, cognitiveservices, azure-api, ml, notebooks, oms, ods, agentsvc (및 file/queue/table) | ✅ 일치 | 14종 Hub RG에 존재 |
| Spoke VNet (test-x-x-spoke-rg / test-x-x-spoke-vnet) | RG, VNet(대역), Peering, 서브넷 | ✅ 일치 | 10.1.0.0/24, apim-snet, pep-snet |
| Spoke Private DNS Zones | APIM_DNS Zone, OPENAI_DNS Zone, AIFoundry_DNS Zone | ✅ 일치 | azure-api, openai, cognitiveservices, ml, notebooks (5종) |
| Spoke → Hub/Shared DNS 링크 | Spoke VNet이 Hub Zone에도 링크 | ✅ 일치 | overlapping 제외 후 Hub Zone만 링크 |
| APIM (Spoke) | apim-subnet, APIM 서비스 | ✅ 일치 | test-x-x-apim-fmzn, apim-snet |
| Azure OpenAI (Spoke) | openai-subnet, OpenAI 서비스 | ✅ 일치 | test-x-x-aoaiesaz, Spoke RG |
| Azure AI Foundry (Spoke) | ai-foundry-subnet, AI Foundry/ML 워크스페이스 | ✅ 일치 | test-x-x-aifoundry, Spoke RG |
| VNet Peering | Hub ↔ Spoke 양방향 | ✅ 일치 | connectivity 스택에서 적용 |
| 공유 서비스 (Hub) | Log Analytics, Azure Monitor, Dashboard 등 | ✅ 일치 | shared-services 스택 |
| Storage / Key Vault (Hub) | Blob·Key Vault·PE | ✅ 일치 | storage 스택 |
| Compute (Hub) | Monitoring VM 등 | ✅ 일치 | compute 스택, Monitoring-VM-Subnet |
| RBAC | Monitoring VM·Key Vault 등 역할 | ⚠️ 미적용 4건 | plan 상 4 to add → 필요 시 apply |

---

## 2. 이미지 vs 배포 상세

### 2.1 Hub VNet (test 환경)

| 이미지 항목 | 배포된 리소스 | 확인 |
|-------------|----------------|------|
| RG | `test-x-x-rg` | ✅ |
| VNet 주소 공간 | `10.0.0.0/20` | ✅ |
| GatewaySubnet | VPN Gateway, (이미지) Site-to-Site VPN·Azure Firewall | ✅ |
| DNSResolver-Inbound | DNS Private Resolver (test-x-x-pdr) | ✅ |
| AzureFirewallSubnet / AzureFirewallManagementSubnet | 서브넷 존재 | ✅ |
| AppGatewaySubnet | Application Gateway용 | ✅ |
| Management/모니터링 | Monitoring-VM-Subnet, Log Analytics·Monitor(shared-services) | ✅ |
| pep-snet | Private Endpoint용 | ✅ |
| Hub Private DNS Zones | blob, file, queue, table, vault, monitor, oms, ods, agentsvc, openai, cognitiveservices, azure-api, ml, notebooks | ✅ 14종 |

### 2.2 Spoke VNet (test 환경)

| 이미지 항목 | 배포된 리소스 | 확인 |
|-------------|----------------|------|
| RG | `test-x-x-spoke-rg` | ✅ |
| VNet 주소 공간 | `10.1.0.0/24` | ✅ |
| VNet Peering | Hub ↔ Spoke (connectivity 스택) | ✅ |
| apim-subnet (이미지) | apim-snet, APIM 서비스 (test-x-x-apim-fmzn) | ✅ |
| openai-subnet (이미지) | Spoke 내 OpenAI 계정 + PE(pep-snet); test-x-x-aoaiesaz | ✅ |
| ai-foundry-subnet (이미지) | AI Foundry/ML 워크스페이스 test-x-x-aifoundry, Spoke Storage·ACR·App Insights, PE(pep-snet) | ✅ |
| Spoke 전용 Private DNS Zones | APIM → privatelink.azure-api.net, OpenAI → privatelink.openai.azure.com, AI Foundry → cognitiveservices, ml, notebooks | ✅ 5종 (Spoke RG) |
| Spoke → Hub/Shared DNS 링크 | blob, vault, monitor, file, queue, table, oms, ods, agentsvc (Spoke Zone과 중복 5종 제외) | ✅ |

### 2.3 스택별 plan 결과 (Hub 구독으로 plan 실행)

| 스택 | plan 결과 | 비고 |
|------|-----------|------|
| network | No changes | 구성 일치 |
| storage | No changes | 구성 일치 |
| shared-services | No changes | 구성 일치 |
| apim | No changes | 구성 일치 |
| ai-services | Output만 변경 가능, 인프라 변경 없음 | 구성 일치 |
| compute | No changes (또는 0 to add) | 구성 일치 |
| rbac | **4 to add** | APIM/AI 배포 후 역할 4건 미적용 → 필요 시 `terraform apply` |
| connectivity | No changes | 구성 일치 |

---

## 3. 결론 및 권장 사항

- **이미지 아키텍처와의 일치:**  
  Hub VNet, Spoke VNet, **Hub·Spoke 양쪽 Private DNS Zone**, Spoke의 APIM/OpenAI/AI Foundry, VNet Peering, 공유 서비스(Log Analytics·Monitor·Dashboard), Storage/Key Vault, Compute까지 **이미지에 나온 test 환경 구조와 일치**하게 배포되어 있습니다.

- **RBAC:**  
  `azure/dev/rbac`에서 `terraform plan -var-file=terraform.tfvars` 시 **4 to add**가 나오면, APIM/AI-services 배포로 생긴 리소스에 대한 역할 할당이 아직 반영되지 않은 상태입니다.  
  역할까지 완전히 맞추려면:
  ```bash
  az account set --subscription "<Hub 구독 ID>"
  cd azure/dev/rbac
  terraform apply -var-file=terraform.tfvars
  ```
  로 한 번 더 적용하는 것을 권장합니다.

- **Production 환경:**  
  이미지는 test와 production을 구분해 두 환경으로 나누어져 있습니다. 현재 점검은 **test 환경**만 대상이며, production은 별도 tfvars/워크스페이스로 동일 기준으로 배포·점검하면 됩니다.

---

## 4. 참고: 출력값 요약 (검증 시 사용)

- **Network:**  
  `hub_resource_group_name` = test-x-x-rg, `hub_vnet_name` = test-x-x-vnet, `spoke_vnet_name` = test-x-x-spoke-vnet,  
  `hub_private_dns_zone_ids`(14종), `spoke_private_dns_zone_ids`(azure-api, openai, cognitiveservices, ml, notebooks).
- **APIM:**  
  `apim_id` = …/test-x-x-apim-fmzn, `apim_gateway_url` = https://test-x-x-apim-fmzn.azure-api.net.
- **AI-services:**  
  `openai_id` = …/test-x-x-aoaiesaz, `ai_foundry_id` = …/test-x-x-aifoundry.

이 문서는 이미지 아키텍처 기준으로 “모든 스택이 정상 배포되었는지” 점검한 결과를 담은 보고서입니다.
