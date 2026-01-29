# -------------------------------------------------------------------
# 보안 그룹 설정
# -------------------------------------------------------------------

# 1. Bastion Host SG
resource "aws_security_group" "bastion" {
  name        = "mindlog-bastion-sg"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.main.id

  # Inbound: SSH (22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실무에선 본인 IP로 제한 권장
  }

  # Outbound: All
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mindlog-bastion-sg" }
}

# 2. ALB (Load Balancer) SG
resource "aws_security_group" "alb" {
  name        = "mindlog-alb-sg"
  description = "Allow HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mindlog-alb-sg" }
}

# 3. EKS Worker Nodes SG
resource "aws_security_group" "eks_nodes" {
  name        = "mindlog-eks-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  # Bastion -> Node (SSH/Management)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # ALB -> Node (Traffic)
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Node <-> Node (Self)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                    = "mindlog-eks-node-sg"
    "kubernetes.io/cluster/mindlog-cluster" = "owned"
  }
}

# 4. RDS (DB) SG
resource "aws_security_group" "db" {
  name        = "mindlog-db-sg"
  description = "Allow DB access from EKS only"
  vpc_id      = aws_vpc.main.id

  # EKS Node -> DB (3306)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = { Name = "mindlog-db-sg" }
}