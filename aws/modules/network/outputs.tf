/*
  modules/network/outputs.tf

  다른 모듈(bastion/security/flow-logs/siem 등)과
  다른 팀이 소비할 "계약 인터페이스"만 export
*/

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (2AZ)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private App subnet IDs (2AZ)"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "Private DB subnet IDs (2AZ)"
  value       = aws_subnet.private_db[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (per AZ)"
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs (per AZ)"
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "Selected AZs (2AZ)"
  value       = local.azs
}