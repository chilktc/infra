/*
  이 파일은 Terraform Remote State를 위한 인프라를 생성한다.

  생성 대상:
  - S3 Bucket (Terraform state 저장소)
  - DynamoDB Table (State Lock 용도)

  !! 이 스택은 반드시 최초 1회만 apply 한다.
  !! 이후 다른 스택들은 이 bucket을 backend로 사용한다.
*/

provider "aws" {
  region = var.region
}

###############################
# S3 Bucket - Terraform State
###############################

# Terraform state 파일을 저장할 S3 bucket 생성

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name
}

# S3 Versioning 활성화

/*
  state 파일 버전 관리 활성화
  실수로 state가 덮어써져도 복구 가능
*/
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

###############################
# S3 암호화 설정
###############################

/*
  S3에 저장되는 state 파일 암호화

  기본 AES256 사용
  (향후 KMS key로 교체 가능)
*/
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

###############################
# Public Access 완전 차단
###############################

/*
  Terraform state는 절대 외부 공개 금지

  - public ACL 차단
  - public policy 차단
  - 모든 공개 접근 차단
*/
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################
# Ownership Controls
###############################

/*
  BucketOwnerEnforced:
  - ACL 완전 비활성화
  - 객체는 항상 버킷 소유자가 소유
  - 권한 혼선 방지 (운영 표준)
*/

resource "aws_s3_bucket_ownership_controls" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


###############################
# Multipart 업로드 정리 정책
###############################

/*
  업로드 실패 시 남는 불완전 multipart 파일 정리
  비용 최적화 목적
*/
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "abort-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

###############################
# DynamoDB Lock Table 생성
###############################

/*
  Terraform state locking 용 DynamoDB 테이블

  - 동시 apply 방지
  - 충돌 방지

  PAY_PER_REQUEST 사용 → 트래픽 적으므로 비용 낮음
*/
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

###############################
# Outputs
###############################

/*
  다른 팀원이 bucket 및 lock table 이름을 쉽게 확인하도록 출력
*/

output "state_bucket_name" {
  description = "Terraform remote state bucket name"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "Terraform state lock DynamoDB table name"
  value       = aws_dynamodb_table.tf_lock.name
}