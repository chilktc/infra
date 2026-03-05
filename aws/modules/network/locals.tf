/*
  modules/network/locals.tf

  - 네이밍/태그를 중앙화해서 일관성을 보장
  - env별로 변경되더라도 규칙은 유지되도록 설계
*/

locals {
  name_prefix = format("%s-%s", var.project, var.env)

  name_vpc = format("%s-vpc", local.name_prefix)
  name_igw = format("%s-igw", local.name_prefix)

  /*
    az suffix는 화면 가독성용.
    local.azs가 ["ap-northeast-2a","ap-northeast-2c"]라면 suffix는 ["a","c"]
  */
  az_suffix = [for az in slice(data.aws_availability_zones.available.names, 0, 2) : substr(az, length(az) - 1, 1)]

  common_tags = merge({
    Project     = var.project
    Environment = var.env
    Owner       = "infra"
    ManagedBy   = "terraform"
    CostCenter  = "core"
  }, var.tags)
}