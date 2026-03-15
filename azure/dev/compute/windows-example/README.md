# windows-example (모듈)

compute **루트**에서 `module { source = "./windows-example"; ... }` 로 호출하는 **모듈**입니다.  
단독으로 `terraform apply` 하지 않고, **compute 루트**에서만 배포합니다.

- 루트에서 전달받는 변수: `resource_group_name`, `subnet_id`, `location`, `vm_name`, `vm_size`, `admin_username`, `admin_password`, `tags`, `vm_extensions`, `enable_vm`
