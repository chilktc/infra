data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  name_prefix = "${var.project}-${var.env}"
}

variable "project" {}
variable "env" {}
variable "instance_type" {}
variable "instance_count" {}
variable "subnet_ids" {}
variable "private_ips" {}
variable "security_group_ids" {}
variable "instance_profile_name" {}
variable "user_data" {}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  private_ip                  = length(var.private_ips) > 0 ? var.private_ips[count.index] : null
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.instance_profile_name
  user_data                   = var.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-${count.index + 1}"
  })
}

output "instance_ids" {
  value = aws_instance.this[*].id
}
