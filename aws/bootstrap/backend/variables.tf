/*
  bootstrap backend용 변수 정의
  ⚠️ state bucket 이름은 반드시 전세계 유니크
*/

variable "region" {
  description = "AWS region where backend resources will be created"
  type        = string
  default     = "ap-northeast-2"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state (must be globally unique)"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking"
  type        = string
}