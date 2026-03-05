# 운영 환경 고정값
project = "t7-mindlog"
env     = "prod"
region  = "ap-northeast-2"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.0.0/24",
  "10.0.1.0/24"
]

private_app_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.11.0/24"
]

private_db_subnet_cidrs = [
  "10.0.20.0/24",
  "10.0.21.0/24"
]

eks_cluster_name = "mindlog-cluster"