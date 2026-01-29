# -------------------------------------------------------------------
# 1. VPC (가장 큰 네트워크 단위)
# -------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # EKS 필수
  enable_dns_support   = true

  tags = { Name = "mindlog-vpc" }
}

# Internet Gateway (외부 통신 대문)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "mindlog-igw" }
}

# -------------------------------------------------------------------
# 2. Subnets (공간 나누기)
# -------------------------------------------------------------------

# Public Subnets (ALB, Bastion, NAT)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name                                    = "mindlog-public-a"
    "kubernetes.io/cluster/mindlog-cluster" = "shared"
    "kubernetes.io/role/elb"                = "1" # AWS LB Controller용 태그
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name                                    = "mindlog-public-c"
    "kubernetes.io/cluster/mindlog-cluster" = "shared"
    "kubernetes.io/role/elb"                = "1"
  }
}

# Private App Subnets (EKS - IP 많이 필요하므로 /20 할당)
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name                                    = "mindlog-private-app-a"
    "kubernetes.io/cluster/mindlog-cluster" = "shared"
    "kubernetes.io/role/internal-elb"       = "1" # 내부 LB용 태그
  }
}

resource "aws_subnet" "private_app_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/20"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name                                    = "mindlog-private-app-c"
    "kubernetes.io/cluster/mindlog-cluster" = "shared"
    "kubernetes.io/role/internal-elb"       = "1"
  }
}

# Private DB Subnets (RDS - 100번대 대역으로 격리)
resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "mindlog-private-db-a" }
}

resource "aws_subnet" "private_db_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "ap-northeast-2c"
  tags              = { Name = "mindlog-private-db-c" }
}

# -------------------------------------------------------------------
# 3. NAT Gateway (비용 절감을 위해 1개만 생성)
# -------------------------------------------------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "mindlog-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id # Public A에 배치

  tags       = { Name = "mindlog-nat" }
  depends_on = [aws_internet_gateway.igw]
}

# -------------------------------------------------------------------
# 4. Routing Tables (길 안내 표지판)
# -------------------------------------------------------------------

# Public Route Table (IGW로 직행)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "mindlog-public-rt" }
}

# Private Route Table (NAT로 우회)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "mindlog-private-rt" }
}

# 라우팅 테이블 연결
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_app_c" {
  subnet_id      = aws_subnet.private_app_c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db_a" {
  subnet_id      = aws_subnet.private_db_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_db_c" {
  subnet_id      = aws_subnet.private_db_c.id
  route_table_id = aws_route_table.private.id
}