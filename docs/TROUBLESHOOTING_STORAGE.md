# Storage 스택 트러블슈팅

## 1. InvalidSubscriptionId — "The provided subscription identifier 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' is malformed or invalid"

**원인**  
`hub_subscription_id`에 예시 플레이스홀더(`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)가 들어 있는 상태로 plan/apply를 실행했거나, **`-var-file=terraform.tfvars`를 지정하지 않아** 변수 기본값/다른 값이 사용된 경우입니다.

**조치**  
- `azure/dev/storage/terraform.tfvars`를 열어 **`hub_subscription_id`** 가 실제 Hub 구독 ID(예: `f6e816bf-6df7-4fb5-953c-12507dc60879`)인지 확인합니다.  
- 아래처럼 **반드시 `-var-file=terraform.tfvars`** 를 붙여 실행합니다.  
  ```bash
  cd azure/dev/storage
  terraform plan -var-file=terraform.tfvars
  terraform apply -var-file=terraform.tfvars
  ```

---

## 2. State lock — "state blob is already locked"

**원인**  
`terraform apply` 실행 중 Ctrl+C 등으로 중단하면, Backend에 걸린 state 잠금이 풀리지 않고 남을 수 있습니다.

**조치**  
에러 메시지에 나온 **Lock ID**를 사용해 강제 잠금 해제 후 다시 plan/apply 합니다.  

```bash
cd azure/dev/storage
terraform force-unlock d56c1221-bb14-909f-0c7b-c8f2bfe208bf
```

(위 ID는 에러 메시지의 `ID: d56c1221-bb14-909f-0c7b-c8f2bfe208bf` 를 그대로 넣은 것입니다. 다른 Lock ID가 나오면 해당 ID로 바꿉니다.)

이후:

```bash
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

잠금은 **본인이 중단한 apply**에 대한 것일 때만 해제하는 것이 안전합니다. 다른 사용자/프로세스가 같은 state를 쓰는 중이면 그 작업이 끝날 때까지 기다린 뒤 사용하세요.
