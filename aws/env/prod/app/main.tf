data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "t7-mindlog-tfstate-apne2-prod"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

###############################
# Security (SG, IAM)
###############################
module "security" {
  source = "../../../modules/security"

  project = var.project
  env     = var.env
  vpc_id  = data.terraform_remote_state.network.outputs.vpc_id
  tags    = var.default_tags
}

###############################
# Compute (EC2)
###############################
module "compute" {
  source = "../../../modules/compute"

  project               = var.project
  env                   = var.env
  instance_type         = var.instance_type
  instance_count        = var.instance_count
  subnet_ids            = data.terraform_remote_state.network.outputs.private_app_subnet_ids
  private_ips           = ["10.7.10.10", "10.7.11.10", "10.7.10.20", "10.7.11.20", "10.7.10.30", "10.7.11.30"]
  security_group_ids    = [module.security.app_sg_id]
  instance_profile_name = module.security.instance_profile_name
  user_data             = templatefile("${path.module}/scripts/init-app.sh", {
    gf_admin_password = var.gf_admin_password
    os_admin_password = var.os_admin_password
    target_ips        = join(",", ["10.7.10.10", "10.7.11.10", "10.7.10.20", "10.7.11.20", "10.7.10.30", "10.7.11.30"])
  })
  tags                  = var.default_tags
}

###############################
# ALB
###############################
module "alb" {
  source = "../../../modules/alb"

  project            = var.project
  env                = var.env
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  security_group_ids = [module.security.alb_sg_id]
  tags               = var.default_tags

  # backend gateway: app-3
  instance_ids = {
    "app-3" = module.compute.instance_ids[2]
  }

  # management: app-1 for Grafana/OpenSearch
  management_instance_ids = {
    "app-1" = module.compute.instance_ids[0]
  }

  # frontend no longer needed, passing empty list to avoid errors if required, or simply comment it out if it was optional. Wait, frontend_instance_ids was a variable.
  frontend_instance_ids = {}
}
