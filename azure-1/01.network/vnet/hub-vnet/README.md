# Hub VNet (01.network)

`01.network/vnet/hub-vnet`는 Hub VNet 리프입니다.

State 키: `azure/dev/01.network/vnet/hub-vnet/terraform.tfstate`

## 역할

- Hub Resource Group의 VNet 컨텍스트를 생성/출력
- 하위 네트워크 리프(`subnet/*`, `dns/*`, `security-group/*`, `route/*`)가 참조하는 기준 상태 제공

## 선행/후행

- 선행: `01.network/resource-group/hub-rg`
- 후행: `01.network/subnet/*`, `01.network/dns/*`, `02.storage`, `03.shared-services`, `09.connectivity` 등

## 배포 명령

```bash
cd azure/dev/01.network/vnet/hub-vnet
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 수정
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 수정 가이드

- 주소 공간/네이밍 변경: `terraform.tfvars`와 `variables.tf`를 우선 수정
- 하위 리프 참조 출력 변경: `outputs.tf` 수정 후 downstream 리프에서 `plan` 재확인
- 기존 리소스가 선배포된 상태라면 `import`로 state를 맞춘 뒤 적용

## 모듈 참조

예시:

```hcl
source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=chore/avm-wave1-modules-prune-and-convert"
```
