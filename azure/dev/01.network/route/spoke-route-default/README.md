# Spoke — Route Table (UDR)

- **State:** `azure/dev/01.network/route/spoke-route-default/terraform.tfstate`
- **선행:** `vnet/hub-vnet`, `vnet/spoke-vnet` (원격 state). NVA 경로 사용 시 `vnet/hub-vnet`의 `hub_subnet_address_prefixes`로 모니터링 대역 CIDR를 읽음.

`apim-snet`·`pep-snet` 등에 Route Table을 붙이고, Hub **Monitoring-VM-Subnet** 대역(및 `custom_routes`)으로의 사용자 정의 경로를 둘 수 있습니다. VNet 피어링만으로도 동일 대역 통신은 가능하므로, **NVA/방화벽·강제 터널** 설계일 때만 `enable_route_to_hub_monitoring` 또는 `custom_routes`를 켜세요.
