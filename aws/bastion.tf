resource "aws_key_pair" "admin_key" {
  key_name   = "mindlog-admin-key"
  public_key = file("../mindlog-key.pub")
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name      = aws_key_pair.admin_key.key_name
  associate_public_ip_address = true
  tags = { Name = "mindlog-bastion" }
}

output "bastion_ssh_cmd" {
  value = "ssh -i ../mindlog-key ec2-user@${aws_instance.bastion.public_ip}"
}
