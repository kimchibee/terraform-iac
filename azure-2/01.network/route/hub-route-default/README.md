# Hub — Route Table (UDR)

- **State:** `azure/dev/01.network/route/hub-route-default/terraform.tfstate`
- **선행:** `vnet/hub-vnet`, `vnet/spoke-vnet`

기본적으로 **Monitoring-VM-Subnet**에 Route Table을 연결합니다(`associate_route_table_to_monitoring_subnet`). 모니터링 VM에서 Spoke 워크로드로 트래픽을 보낼 때 NVA를 경유하는 등의 경로는 `enable_route_to_spoke_vnet` 또는 `custom_routes`로 정의합니다.
