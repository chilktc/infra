/*
  modules/network/route.tf

  운영환경 HA 스펙:
  - NAT Gateway per AZ (2개)
  - Private Route Table per AZ (2개)
  - Public Route Table 1개
*/

####################################
# NAT Gateway per AZ (2)
####################################

/*
  NAT는 Public subnet에 위치해야 한다.
  EIP도 AZ별로 1개씩 필요하다.
*/
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = format("%s-nat-eip-%s", local.name_prefix, local.az_suffix[count.index])
  })
}

resource "aws_nat_gateway" "this" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = format("%s-nat-%s", local.name_prefix, local.az_suffix[count.index])
  })

  /*
    NAT는 IGW가 존재해야 정상 생성된다.
    (간헐적으로 race condition 방지)
  */
  depends_on = [aws_internet_gateway.this]
}

####################################
# Route Tables
####################################

/*
  Public RT: IGW로 Default Route
*/
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = format("%s-public-rt", local.name_prefix)
  })
}

/*
  Private RT per AZ: NAT로 Default Route
  - private-a-rt  → NAT-a
  - private-c-rt  → NAT-c
*/
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = format("%s-private-%s-rt", local.name_prefix, local.az_suffix[count.index])
  })
}

####################################
# Route Table Associations
####################################

/* Public subnets → Public RT */
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

/* Private App subnets → Private RT(AZ별) */
resource "aws_route_table_association" "private_app" {
  count = 2

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

/* Private DB subnets → Private RT(AZ별) */
resource "aws_route_table_association" "private_db" {
  count = 2

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}