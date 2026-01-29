# -------------------------------------------------------------------
# Bastion Host & Key Pair
# -------------------------------------------------------------------

# 1. 키 페어 등록 (1단계에서 만든 공개키 파일 사용)
resource "aws_key_pair" "admin_key" {
  key_name   = "mindlog-admin-key"
  public_key = file("./mindlog-key.pub")
}

# 2. 최신 Amazon Linux 2023 AMI 조회
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 3. EC2 Instance 생성
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro" # 프리티어 가능

  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.admin_key.key_name
  associate_public_ip_address = true # 외부 접속용 IP 할당

  tags = {
    Name = "mindlog-bastion"
  }
}

# 4. 접속 명령어 출력 (Apply 완료 시 표시됨)
output "bastion_ssh_cmd" {
  value       = "ssh -i mindlog-key ec2-user@${aws_instance.bastion.public_ip}"
  description = "Connect to Bastion"
}