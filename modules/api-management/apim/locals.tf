#--------------------------------------------------------------
# Local Values
# locals { ... } 블록으로, 공통 prefix, naming convention, 태그 등을 변수처럼 정의
# 복잡한 네이밍 규칙이나 반복되는 tag 세트를 DRY하게 유지
#--------------------------------------------------------------

locals {
  # API Management 이름 (랜덤 suffix 포함)
  apim_name = "${var.apim_name}-${random_string.apim_suffix.result}"

  # 공통 태그 (variables.tf의 기본 태그와 병합)
  common_tags = merge(
    var.tags,
    {
      Service     = "API Management"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # API 경로 맵
  api_paths = { for k, v in var.apis : k => v.path }

  # 정책 파일 경로
  policy_files = var.policies != null ? var.policies : {
    global_policy = ""
    api_policies  = {}
  }
}
