/*
  main.tf

  실제 운영 네트워크를 생성
  module 호출만 담당
*/

module "network" {
  source = "../../../modules/network"

  project = var.project
  env     = var.env
  region  = var.region

  vpc_cidr = var.vpc_cidr

  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs

  enable_eks_subnet_tags = true
  eks_cluster_name       = var.eks_cluster_name

  tags = {
    Owner      = "infra-team"
    CostCenter = "core"
  }
}