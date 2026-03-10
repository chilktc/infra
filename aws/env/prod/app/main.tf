data "terraform_remote_state" "network" { backend = "s3" config = { bucket = "t7-mindlog-tfstate-apne2-prod" key = "network/terraform.tfstate" region = "ap-northeast-2" } }
