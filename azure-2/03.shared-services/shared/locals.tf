# shared-services composite 모듈 제거 후,
# shared 리프는 log-analytics 집계/중계 역할만 수행한다.
locals {
  shared_leaf_enabled = var.enable
}
