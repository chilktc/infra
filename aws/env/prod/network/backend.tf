/*
  backend.tf

  운영환경 state는 반드시 Remote Backend 사용.
  - S3: state 저장
  - DynamoDB: state locking (동시 apply 방지)
  이 bucket과 dynamodb 테이블은 bootstrap 단계에서 생성되어 있어야 한다.
*/

terraform {
  backend "s3" {
    bucket         = "t7-mindlog-tfstate-apne2-prod"
    key            = "network/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "t7-mindlog-terraform-lock-prod"
    encrypt        = true
  }
}