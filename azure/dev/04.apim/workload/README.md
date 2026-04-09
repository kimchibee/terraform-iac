# APIM Workload (04)

`04.apim/workload`는 Spoke 구독에 APIM 리소스를 배포하는 리프입니다.

State 키: `azure/dev/04.apim/workload/terraform.tfstate`

## 선행 스택

1. `01.network` (특히 `vnet/spoke-vnet`, `subnet/spoke-apim-subnet`)
2. `02.storage`
3. `03.shared-services`

## 주요 변수

- `project_name`, `environment`, `location`, `tags`
- `spoke_subscription_id`
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name`
- `apim_sku_name`, `apim_publisher_name`, `apim_publisher_email`

## 참조 모듈

- `terraform_modules/api-management-service`

예시:

```hcl
source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/api-management-service?ref=chore/avm-vendoring-and-id-injection"
```

## 배포 명령

```bash
cd azure/dev/04.apim/workload
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 수정
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 수정 가이드

- APIM 이름/SKU/게시자 정보 변경: `terraform.tfvars` 수정 후 `plan -> apply`
- 신규 APIM 옵션 추가: `variables.tf` + `main.tf` 모듈 인자 추가
- 공용 모듈 변경 반영: `terraform init -upgrade` 후 재계획
