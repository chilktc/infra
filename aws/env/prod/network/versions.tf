/*
  versions.tf

  운영환경은 항상 버전을 명시적으로 고정한다.
  팀원 간 Terraform 버전 차이로 인한 state drift 방지 목적
*/

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}