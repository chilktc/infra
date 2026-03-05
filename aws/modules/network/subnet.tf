/*
  modules/network/subnet.tf

  운영환경 고정 스펙:
  - 2AZ
  - Public(2) / Private-App(2) / Private-DB(2)
  - EKS 사용 가능하도록 subnet tag(옵션) 자동 부여

  AZ는 고정 문자열(ap-northeast-2a 등) 하드코딩 금지
     data.aws_availability_zones로 "현재 region에서 사용 가능한 AZ"를 받아서 2개만 사용
*/

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  /*
    2AZ 고정
    region 내 AZ가 더 많더라도 앞의 2개만 사용
    (운영에서 3AZ로 확장할 때는 변수/설계 변경으로 확장 가능)
  */
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  /*
    EKS subnet tag는 enable_eks_subnet_tags=true이고 cluster_name이 있을 때만 생성
  */
  eks_tags_public = (
    var.enable_eks_subnet_tags && var.eks_cluster_name != null
    ? {
        "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
        "kubernetes.io/role/elb"                        = "1"
      }
    : {}
  )

  eks_tags_private = (
    var.enable_eks_subnet_tags && var.eks_cluster_name != null
    ? {
        "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
        "kubernetes.io/role/internal-elb"               = "1"
      }
    : {}
  )
}

####################################
# Public Subnets (2)
####################################
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, local.eks_tags_public, {
    Name = format("%s-public-%s", local.name_prefix, local.az_suffix[count.index])
    Tier = "public"
  })
}

####################################
# Private App Subnets (2)
####################################
resource "aws_subnet" "private_app" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, local.eks_tags_private, {
    Name = format("%s-private-app-%s", local.name_prefix, local.az_suffix[count.index])
    Tier = "private-app"
  })
}

####################################
# Private DB Subnets (2)
####################################
resource "aws_subnet" "private_db" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = format("%s-private-db-%s", local.name_prefix, local.az_suffix[count.index])
    Tier = "private-db"
  })
}