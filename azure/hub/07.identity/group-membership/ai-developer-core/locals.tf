locals {
  member_ids = toset([
    for id in var.member_object_ids :
    id if id != null && trimspace(id) != ""
  ])
}
