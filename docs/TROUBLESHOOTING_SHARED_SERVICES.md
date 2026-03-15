# Shared Services 스택 트러블슈팅

## 1. azurerm 버전 충돌 — "locked provider ... 4.63.0 does not match configured version constraint ... ~> 3.75.0"

**원인**  
하위 모듈(`log-analytics-workspace`, `shared-services`)의 `versions.tf`에서 `azurerm`을 `~> 3.75.0`으로 고정했는데, lock 파일과 AVM 모듈은 `azurerm` 4.63.0을 사용합니다. `~> 3.75.0`은 3.75.x만 허용하므로 4.x와 충돌합니다.

**조치**  
다음 두 파일에서 `azurerm` 버전 제약을 4.x까지 허용하도록 수정했습니다.

- `azure/dev/shared-services/log-analytics-workspace/versions.tf`
- `azure/dev/shared-services/shared-services/versions.tf`

```hcl
# 변경 전
version = "~> 3.75.0"

# 변경 후
version = ">= 3.75.0, < 5.0.0"
```

---

## 2. Provider 캐시/checksum 불일치 — "cached package does not match any of the checksums recorded in the dependency lock file"

**원인**  
`terraform init`이 중간에 실패하거나, 다른 환경에서 생성한 lock 파일을 쓰는 경우 캐시와 lock 파일의 checksum이 맞지 않을 수 있습니다.

**조치**  
`.terraform` 디렉터리를 삭제한 뒤 **같은 디렉터리에서** 다시 init 합니다.

```bash
cd azure/dev/shared-services
rm -rf .terraform
terraform init -backend-config=backend.hcl
```

Windows PowerShell:

```powershell
cd azure\dev\shared-services
Remove-Item -Recurse -Force .terraform
terraform init -backend-config=backend.hcl
```

이후:

```bash
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
```

---

## 3. 정리: Shared Services 배포 전 순서

1. 위 1번처럼 `versions.tf`에서 `azurerm` 제약이 `>= 3.75.0, < 5.0.0` 인지 확인.
2. `.terraform` 삭제 후 `terraform init -backend-config=backend.hcl` 실행.
3. `terraform plan -var-file=terraform.tfvars` / `terraform apply -var-file=terraform.tfvars` 실행.
