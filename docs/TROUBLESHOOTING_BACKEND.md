# Backend / State 저장소 트러블슈팅

## ResourceGroupNotFound — "Resource group 'terraform-state-rg' could not be found" (Subscription: Spoke ID)

**원인**  
Terraform 백엔드(azurerm)는 **구독 ID를 별도로 지정하지 않고**, state 저장소(Storage Account)에 접근할 때 **현재 Azure CLI 기본 구독**을 사용합니다.  
Bootstrap으로 만든 state 저장소(`terraform-state-rg`, `tfstate7dc60879`)는 **Hub 구독**에 있는데, Azure CLI 기본 구독이 **Spoke 구독**으로 되어 있으면 Spoke 구독에서 해당 RG를 찾다가 404가 납니다.

**조치**  
`terraform init` / `plan` / `apply` / `output` 등 **state를 읽거나 쓰는 모든 명령 전에**, Azure CLI 기본 구독을 **Hub 구독**으로 맞춥니다.

```bash
# Hub 구독으로 전환 (terraform.tfvars의 hub_subscription_id와 동일한 값 사용)
az account set --subscription "f6e816bf-6df7-4fb5-953c-12507dc60879"
```

이후 같은 터미널에서:

```bash
cd azure/dev/network
terraform apply -var-file=terraform.tfvars -auto-approve
```

**참고**  
- Spoke 쪽 리소스(예: Spoke VNet)는 provider `azurerm.spoke`가 `spoke_subscription_id`로 생성하므로, **apply 시점의 Azure CLI 기본 구독**과 무관하게 Spoke 구독에 생성됩니다.  
- 다만 **state를 읽고 쓰는 백엔드 접근**만 Hub 구독을 사용하므로, 기본 구독을 Hub로 두고 실행하면 됩니다.
