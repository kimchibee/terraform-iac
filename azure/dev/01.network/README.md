# Network (01)

이 스택은 **리소스 종류 → 리소스명 리프** 규칙을 따른다.

- `resource-group/*` 는 Resource Group만 관리
- `vnet/*` 는 VNet 리프만 관리
- `subnet/*` 는 Subnet 리프만 관리
- `application-security-group/*` 는 ASG만 관리
- `network-security-group/*` 는 NSG만 관리
- `route/*` 는 Route Table만 관리
- `security-policy/*` 는 Firewall Policy 계열만 관리

## 배포 순서 (권장)

1. `resource-group/hub-rg`
2. `application-security-group/keyvault-clients`
3. `application-security-group/vm-allowed-clients`
4. `network-security-group/keyvault-standalone`
5. `vnet/hub-vnet`
6. `subnet/hub-gateway-subnet`
7. `subnet/hub-dnsresolver-inbound-subnet`
8. `subnet/hub-azurefirewall-subnet`
9. `subnet/hub-azurefirewall-management-subnet`
10. `subnet/hub-appgateway-subnet`
11. `subnet/hub-monitoring-vm-subnet`
12. `subnet/hub-pep-subnet`
13. `security-policy/hub-sg-policy-default`
14. `route/hub-route-default`
15. `resource-group/spoke-rg`
16. `vnet/spoke-vnet`
17. `subnet/spoke-apim-subnet`
18. `subnet/spoke-pep-subnet`
19. `security-policy/spoke-sg-policy-default`
20. `route/spoke-route-default`

## 리프와 State 키

| 리소스 종류 | 리프 | State 키 |
|------|------|-----------|
| Resource Group | `01.network/resource-group/hub-rg` | `azure/dev/01.network/resource-group/hub-rg/terraform.tfstate` |
| Application Security Group | `01.network/application-security-group/keyvault-clients` | `azure/dev/01.network/security-group/application-security-group/keyvault-clients/terraform.tfstate` |
| Application Security Group | `01.network/application-security-group/vm-allowed-clients` | `azure/dev/01.network/security-group/application-security-group/vm-allowed-clients/terraform.tfstate` |
| Network Security Group | `01.network/network-security-group/keyvault-standalone` | `azure/dev/01.network/security-group/network-security-group/keyvault-standalone/terraform.tfstate` |
| VNet | `01.network/vnet/hub-vnet` | `azure/dev/01.network/vnet/hub-vnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-gateway-subnet` | `azure/dev/01.network/subnet/hub-gateway-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-dnsresolver-inbound-subnet` | `azure/dev/01.network/subnet/hub-dnsresolver-inbound-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-azurefirewall-subnet` | `azure/dev/01.network/subnet/hub-azurefirewall-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-azurefirewall-management-subnet` | `azure/dev/01.network/subnet/hub-azurefirewall-management-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-appgateway-subnet` | `azure/dev/01.network/subnet/hub-appgateway-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-monitoring-vm-subnet` | `azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/hub-pep-subnet` | `azure/dev/01.network/subnet/hub-pep-subnet/terraform.tfstate` |
| Security Policy | `01.network/security-policy/hub-sg-policy-default` | `azure/dev/01.network/security-group/security-policy/hub-sg-policy-default/terraform.tfstate` |
| Route | `01.network/route/hub-route-default` | `azure/dev/01.network/route/hub-route-default/terraform.tfstate` |
| Resource Group | `01.network/resource-group/spoke-rg` | `azure/dev/01.network/resource-group/spoke-rg/terraform.tfstate` |
| VNet | `01.network/vnet/spoke-vnet` | `azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate` |
| Subnet | `01.network/subnet/spoke-apim-subnet` | `azure/dev/01.network/subnet/spoke-apim-subnet/terraform.tfstate` |
| Subnet | `01.network/subnet/spoke-pep-subnet` | `azure/dev/01.network/subnet/spoke-pep-subnet/terraform.tfstate` |
| Security Policy | `01.network/security-policy/spoke-sg-policy-default` | `azure/dev/01.network/security-group/security-policy/spoke-sg-policy-default/terraform.tfstate` |
| Route | `01.network/route/spoke-route-default` | `azure/dev/01.network/route/spoke-route-default/terraform.tfstate` |

## 참고

- 기존 `securitygroup/hub/*` 와 `subnet/spoke-subnet-nsg` 는 legacy 구조로 보고 새 경로에서 더 이상 사용하지 않는다.
- 상세는 각 리프 README를 참고한다.

## Strict AVM Foundation 적용 범위

Strict AVM-only 파동에서 `01.network`는 아래 리프만 in-scope로 본다.

- `resource-group/*` -> `terraform_modules/resource-group` (AVM-only)
- `vnet/*` -> `terraform_modules/vnet` (AVM-only)
- `application-security-group/*` -> `terraform_modules/application-security-group` (AVM-only)
- `network-security-group/*` -> `terraform_modules/network-security-group` (AVM-only)
- `route/*` -> `terraform_modules/route-table` (AVM-only)
- `security-policy/*` -> `terraform_modules/firewall-policy` (AVM-only)

아래 리프는 strict AVM-only 기준에서 Deferred다.

- `subnet/*`
- `private-dns-zone/*`
- `private-dns-zone-vnet-link/*`
- `dns-private-resolver/*`
- `dns-private-resolver-inbound-endpoint/*`
- `public-ip/*`
- `virtual-network-gateway/*`
- `network-security-rule/*`
- `subnet-network-security-group-association/*`

## 현재 상태

- `01.network` 리프 배포 완료
- Hub/Spoke VNet 및 주요 Subnet, DNS Resolver, NSG/ASG 리소스 운영 중
