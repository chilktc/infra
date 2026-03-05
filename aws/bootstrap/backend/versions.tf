/*
  Terraform 및 Provider 버전 고정 설정

  - required_version: 팀 전체가 동일한 Terraform 버전을 사용하도록 강제
  - aws provider version 고정: 예기치 않은 breaking change 방지

  운영환경에서는 반드시 버전 고정 필요
*/

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}