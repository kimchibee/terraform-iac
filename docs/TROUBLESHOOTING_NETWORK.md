# Network 스택 트러블슈팅

## 아키텍처: Private DNS Zone은 Hub와 Spoke 모두에 존재

이미지 아키텍처대로 **Hub**와 **Spoke** 모두에 Private DNS Zone이 있습니다.

- **Hub**: 공유 서비스용 Zone (blob, queue, table, file, vault, monitor, openai, cognitiveservices, azure-api, ml, notebooks, oms, ods, agentsvc) — Hub RG에 생성, Hub VNet 링크. Spoke VNet은 이 Zone들에도 링크(공유 서비스 접근).
- **Spoke**: Spoke 전용 서비스용 Zone (azure-api, openai, cognitiveservices, ml, notebooks) — Spoke RG에 생성, Spoke VNet 링크. APIM·OpenAI·AI Foundry PE는 이 Spoke Zone에 등록.

변수 `spoke_private_dns_zones`(기본값: 위 5종)로 Spoke 쪽 Zone 목록을 바꿀 수 있으며, `network` 스택 출력 `spoke_private_dns_zone_ids` / `spoke_private_dns_zone_names`로 apim·ai-services 스택에서 참조합니다.

---

## ResourceGroupNotFound: Resource group 'test-x-x-rg' could not be found (Virtual Network Link)

### 현상
`terraform apply` 시 Spoke VNet/서브넷은 생성되지만, **Private DNS Zone Virtual Network Link** 생성에서 다음 오류 발생:

```
Error: creating/updating Virtual Network Link (Subscription: "1b741693-..." [Spoke]
Resource Group Name: "test-x-x-rg"
...
ResourceGroupNotFound: Resource group 'test-x-x-rg' could not be found.
```

### 원인
- Private DNS Zone은 **Hub** 구독의 `test-x-x-rg`에 있음.
- Virtual Network Link 리소스는 **Zone이 있는 구독·리소스 그룹**에 생성되어야 함.
- 기존 spoke-vnet 모듈은 모든 리소스를 **Spoke provider** 하나로만 생성해, 링크 생성 요청이 Spoke 구독으로 가서 Hub RG를 찾지 못함.

### 해결
spoke-vnet 모듈을 **벤더링**하고, DNS 링크만 **Hub provider**로 생성하도록 수정함.

- **벤더 경로**: `azure/dev/network/spoke-vnet/terraform_modules/spoke-vnet/`
- **변경 사항**:
  - `versions.tf`: `configuration_aliases = [azurerm.hub]` 추가
  - `main.tf`: `azurerm_private_dns_zone_virtual_network_link.spoke`에 `provider = azurerm.hub` 지정
- **network/main.tf**: `module.spoke_vnet`에 `azurerm.hub = azurerm.hub` 전달
- **spoke-vnet/main.tf**: 소스를 Git 대신 `./terraform_modules/spoke-vnet`로 변경하고, 내부 모듈에 `azurerm.hub` 전달

이후 `terraform init -reconfigure` 후 `terraform apply` 시 링크는 Hub 구독의 `test-x-x-rg`에 정상 생성됨.

---

## BadRequest: A virtual network cannot be linked to multiple zones with overlapping namespaces

### 현상
Spoke에 동일 FQDN의 Private DNS Zone(azure-api, openai, ml, notebooks, cognitiveservices)을 만들고 Spoke VNet을 링크할 때:

```
Message: "A virtual network cannot be linked to multiple zones with overlapping namespaces.
You tried to link virtual network with 'privatelink.openai.azure.com' and 'privatelink.openai.azure.com' zones."
```

### 원인
한 VNet은 **동일 네임스페이스(도메인)** 의 Zone에 한 번만 링크할 수 있음. Hub Zone과 Spoke Zone에 같은 이름(예: privatelink.openai.azure.com)이 있으면 Spoke VNet을 둘 다에 링크할 수 없음.

### 해결
- **Spoke 전용 5종**(azure-api, openai, cognitiveservices, ml, notebooks)은 Spoke Zone에만 링크.
- **Hub Zone → Spoke VNet 링크**에는 이 5종을 제외하고, blob, file, queue, table, vault, monitor, oms, ods, agentsvc만 전달.

`network/main.tf`의 `hub_zone_ids_for_spoke_link` 로컬에서 `spoke_private_dns_zones` 키를 제외한 Hub zone ID만 Spoke 모듈에 넘기도록 되어 있음.
