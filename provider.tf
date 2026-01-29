# -------------------------------------------------------------------
# Provider 설정
# - AWS 서울 리전(ap-northeast-2)을 타겟으로 합니다.
# -------------------------------------------------------------------
provider "aws" {
  region = "ap-northeast-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}