#--------------------------------------------------------------
# Local Values
# locals { ... } 블록으로, 공통 prefix, naming convention, 태그 등을 변수처럼 정의
# 복잡한 네이밍 규칙이나 반복되는 tag 세트를 DRY하게 유지
#--------------------------------------------------------------

locals {
  # Storage Account 이름 (글로벌 유니크, 하이픈 제거)
  storage_account_name = "${replace(var.ai_foundry_name, "-", "")}st${random_string.ai_foundry_suffix.result}"

  # Container Registry 이름 (글로벌 유니크, 하이픈 제거)
  acr_name = "${replace(var.ai_foundry_name, "-", "")}acr${random_string.ai_foundry_suffix.result}"

  # Compute Cluster 이름 맵
  compute_cluster_names = { for k, v in var.compute_clusters : k => "${var.ai_foundry_name}-${k}" }

  # 공통 태그 (variables.tf의 기본 태그와 병합)
  common_tags = merge(
    var.tags,
    {
      Service     = "AI Foundry"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # 환경 파일 경로
  environment_files = {
    for k, v in var.environments : k => v.conda_file != "" ? v.conda_file : null
  }
}
