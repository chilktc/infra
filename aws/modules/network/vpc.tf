/*
  modules/network/vpc.tf
  - VPC + IGW 생성
  - 운영환경 기준: DNS support/hostname 활성화 (ALB/EKS/서비스 디스커버리 필수)
*/

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = local.name_vpc
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = local.name_igw
  })
}