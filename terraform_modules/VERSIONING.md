# 버전 관리 정책 (Versioning)

terraform_modules는 **Git Tag 기반**으로 버전을 관리합니다.

---

## 1. 태그 규칙

- **형식**: `v<MAJOR>.<MINOR>.<PATCH>` (시맨틱 버저닝 권장)
  - 예: `v1.0.0`, `v1.2.3`
- **MAJOR**: 하위 호환성이 깨지는 변경 (변수 삭제, 출력 삭제, 리소스 이름 변경 등)
- **MINOR**: 하위 호환을 유지하는 기능 추가 (새 변수, 새 출력, 새 리소스 옵션)
- **PATCH**: 버그 수정, 문서/주석 수정 등 동작 변경이 거의 없는 수정

---

## 2. terraform-infra에서의 사용

- **필수**: 모듈 소스를 참조할 때 반드시 `ref=<태그>`를 지정합니다.
- **금지**: `ref=main`, `ref=master` 등 브랜치 이름으로 참조하지 않습니다.

### 올바른 예

```hcl
source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/vnet?ref=v1.2.0"
```

### 잘못된 예

```hcl
# 브랜치 참조 — 변경 사항이 불확실함
source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/vnet?ref=main"
```

---

## 3. 태그 생성 절차

1. 변경 사항을 브랜치에 반영하고 코드 리뷰를 완료한다.
2. main(또는 기본 브랜치)에 머지한 뒤, **새 버전 태그**를 생성한다.
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
3. terraform-infra에서 해당 모듈을 사용하는 곳의 `ref`를 새 태그로 업데이트한 뒤, 별도 배포/검토 후 적용한다.

---

## 4. 정리

| 항목 | 내용 |
|------|------|
| 버전 표현 | Git Tag (`v*.*.*`) |
| terraform-infra 사용 | 항상 `?ref=<태그>` 지정 |
| 브랜치 직접 참조 | 사용하지 않음 |
| 변경 영향 | 태그 단위로 고정되어 예측 가능 |

이 정책을 지키면, 장기 운영 시 "어떤 코드 버전이 어떤 환경에 배포되었는지" 추적하고 롤백하기 쉬워집니다.
