---
name: dns-inbound-only-deploy-verify
overview: 요청하신 기준대로 1/2/4/5는 현행 유지하고 3번(DNS Resolver Inbound 통합)만 확정한 뒤, 네트워크부터 전체 스택을 apply 없이 plan/state/output 기반으로 검증합니다.
todos:
  - id: avm-guard-audit
    content: terraform-modules의 직접 azurerm 리소스 추가 여부와 AVM-only 준수 상태를 재검증한다
    status: completed
  - id: dns-inbound-only-check
    content: 01.network에서 DNS Resolver inbound 통합(3번)만 유효한지 확인하고 legacy inbound leaf가 비활성인지 점검한다
    status: completed
  - id: wave-stack-plan-run
    content: 01.network부터 09.connectivity까지 각 리프를 init/plan으로 순차 검증한다
    status: completed
  - id: image-verification-matrix
    content: 첨부 이미지 기준 리소스 검증 매트릭스를 작성해 plan/state/output 근거로 OK/GAP를 판정한다
    status: completed
  - id: final-gap-report
    content: AVM 준수 결과와 스택별 검증 결과, 미배포 GAP 및 후속 조치를 최종 보고한다
    status: completed
isProject: false
---

# DNS Inbound만 적용 + 전체 스택 검증 계획

## 합의된 기준

- 1/2/4/5는 추가 리팩터링 없이 **현재 상태 유지**
- 3번만 확정: DNS Resolver 리프 내부 inbound endpoint 통합 유지
- 전체 스택 배포 검증은 **plan-only**로 수행 (`apply` 미실행)
- 공용모듈은 AVM-only 정책 유지, 신규 `azurerm_`* 직접 리소스 추가 금지 여부 재확인

## 1) 공용모듈 AVM-only 가드 재검증

- `terraform-modules`에서 직접 `resource "azurerm_*"`가 없는지 전수 검사
- AVM 소스 사용 패턴(`source = "Azure/avm-..."`)과 예외 모듈 여부 점검
- 결과를 정책 문서와 대조:
  - [C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-modules/README.md](C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-modules/README.md)
  - [C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-modules/docs/STRICT_AVM_DEFERRED_MODULES.md](C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-modules/docs/STRICT_AVM_DEFERRED_MODULES.md)

## 2) 3번(DNS Resolver Inbound 통합)만 유효성 확인

- DNS 리프에서 inbound endpoint가 resolver 입력으로 통합되어 있는지 확인
- legacy inbound 디렉토리는 no-op/비활성 형태인지 확인
- 점검 파일:
  - [C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/azure/dev/01.network/dns/dns-private-resolver/hub/main.tf](C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/azure/dev/01.network/dns/dns-private-resolver/hub/main.tf)
  - [C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/azure/dev/01.network/dns/dns-private-resolver-inbound-endpoint/hub/main.tf](C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/azure/dev/01.network/dns/dns-private-resolver-inbound-endpoint/hub/main.tf)

## 3) 네트워크→전체 스택 순차 검증(plan-only)

- 스택 순서는 루트 가이드 기준 사용:
  - [C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/README.md](C:/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/README.md)
- 각 리프에서 공통 절차 수행:
  - `terraform init -backend-config=backend.hcl`
  - `terraform plan -var-file=terraform.tfvars`
- 대상 파동: `01.network -> 02.storage -> 03.shared-services -> 04.apim -> 05.ai-services -> 06.compute -> 07.identity -> 08.rbac -> 09.connectivity`
- 실패 리프는 원인 분류(인증/권한/remote state key/provider/version)와 함께 즉시 수정 후보 제시

## 4) 이미지 기준 배포 검증 매트릭스 작성

- 첨부 이미지의 Hub/Spoke 핵심 리소스를 체크리스트로 변환
- plan/state/output으로 존재 여부를 교차 확인
- 대표 검증 축:
  - Hub: RG, VNet/Subnet, VPN GW, DNS Resolver, NSG/ASG, KV/Storage/PE, Log Analytics
  - Spoke: RG, VNet/Subnet, APIM, OpenAI, Private Endpoint, DNS Zone/Link
  - 연결: VNet Peering, 라우팅/정책
- 산출물: `리소스명 / 기대상태 / 검증근거(plan|state|output) / 결과(OK|GAP)` 표

## 5) 최종 보고

- 3번만 적용 유지 여부 확인 결과
- 공용모듈 AVM-only 준수 여부(직접 azurerm 리소스 0건 여부)
- 스택별 plan 결과 요약(성공/실패/원인)
- 이미지 대비 미배포(GAP) 항목 및 다음 액션(필요 시 apply 대상 최소 리프 제안)

