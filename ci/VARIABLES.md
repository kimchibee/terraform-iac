# GitLab CI/CD Variables

GitLab 프로젝트 **Settings → CI/CD → Variables**에 등록해야 하는 변수 목록입니다.

## Azure 인증 (Service Principal)

Terraform `azurerm` provider가 자동으로 읽어 Azure API 인증에 사용합니다.

| Variable | Masked | 설명 |
|----------|--------|------|
| `ARM_CLIENT_ID` | Yes | Azure Service Principal의 Application (Client) ID |
| `ARM_CLIENT_SECRET` | Yes | Service Principal의 Client Secret (비밀번호) |
| `ARM_TENANT_ID` | Yes | Azure AD Tenant (디렉터리) ID |

### Service Principal 생성 방법

```bash
az ad sp create-for-rbac \
  --name "gitlab-terraform-ci" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

출력되는 `appId`, `password`, `tenant`를 각각 `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`에 등록합니다.

## 구독 (Subscription)

각 leaf의 `provider.tf`에서 Hub/Spoke 구독을 구분하여 리소스를 배포합니다.

| Variable | Masked | 설명 |
|----------|--------|------|
| `HUB_SUBSCRIPTION_ID` | No | Hub 구독 ID — 네트워크, 보안, 모니터링, state backend가 위치하는 구독 |
| `SPOKE_SUBSCRIPTION_ID` | No | Spoke 구독 ID — APIM, OpenAI, ML 등 워크로드가 위치하는 구독 |

## 프로젝트 (Terraform 공통 변수)

각 leaf의 `variables.tf`에 선언된 공통 변수입니다. 리소스 이름 생성 및 태깅에 사용됩니다.

| Variable | Masked | 설명 |
|----------|--------|------|
| `PROJECT_NAME` | No | 프로젝트 이름 (예: `test`) — 리소스 네이밍 프리픽스로 사용 |
| `ENVIRONMENT_NAME` | No | 환경 이름 (예: `dev`, `prod`) — 태그 및 네이밍에 사용 |
| `NAME_PREFIX` | No | 리소스 이름 접두사 (예: `test-x-x`) — 일부 스택에서 사용 |

## Backend (Terraform State 저장소)

Bootstrap에서 생성한 state 백엔드 인프라를 가리킵니다. 모든 leaf의 `backend.hcl`에서 이 값을 사용하여 Terraform state를 원격 저장합니다.

| Variable | Masked | 설명 |
|----------|--------|------|
| `BACKEND_RG` | No | Terraform state를 저장하는 Azure Resource Group 이름 |
| `BACKEND_SA` | No | State 파일을 저장하는 Azure Storage Account 이름 (전역 고유, 소문자+숫자 3~24자) |
| `BACKEND_CONTAINER` | No | Storage Account 내 Blob Container 이름 |
| `BACKEND_LOCATION` | No | Resource Group / Storage Account의 Azure 리전 (예: `Korea Central`) |
