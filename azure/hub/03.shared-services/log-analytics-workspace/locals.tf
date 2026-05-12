#--------------------------------------------------------------
# Legacy local shim.
# New shared-service leaves should call the Git shared module directly.
# This wrapper remains only for compatibility while older refs are cleaned up.
#--------------------------------------------------------------
locals {
  name = "${var.name_prefix}-${var.name_suffix}"
}
