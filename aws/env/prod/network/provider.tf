/*
  provider.tf

  env 레이어에서 provider 선언
  modules 안에는 provider 선언 X
*/

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Environment = var.env
    }
  }
}