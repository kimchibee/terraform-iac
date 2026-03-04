# 배포된 리소스 Destroy 순서

의존성 **역순**으로 한 스택씩 실행하세요. **Git Bash**에서 아래 명령을 복사해 실행하면 됩니다. (`&&`로 이어서 한 블록씩 실행.)

---

## 1. connectivity

```bash
cd azure/dev/connectivity && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

## 2. compute

```bash
cd azure/dev/compute && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

## 3. ai-services

```bash
cd azure/dev/ai-services && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

## 4. apim

```bash
cd azure/dev/apim && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

## 5. shared-services

```bash
cd azure/dev/shared-services && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

## 6. storage

```bash
cd azure/dev/storage && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

## 7. network

```bash
cd azure/dev/network && terraform init -backend-config=backend.hcl -reconfigure && terraform destroy -var-file=terraform.tfvars -auto-approve && cd ../../..
```

---

**참고:** Bootstrap(backend) 스택은 State 저장소이므로, 위 7개 스택 destroy 후에도 **terraform-state-rg / Storage 계정은 유지**할 수 있습니다. Backend까지 삭제하려면 `bootstrap/backend`에서 `terraform destroy` 후, Azure에서 `terraform-state-rg` 리소스 그룹을 수동 삭제하세요.
