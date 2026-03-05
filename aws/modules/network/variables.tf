/*
  modules/network/variables.tf
  env 별로 바뀌는 값은 env/-/terraform.tfvars에서 주입
  이 모듈은 provider/backend를 갖지 않는다 (env 레이어에서만 선언)
*/

variable "project" {
  description = "프로젝트 식별자 (리소스 네이밍/태그에 사용)"
  type        = string
  default     = "mindlog"
}

variable "env" {
  description = "환경 이름 (dev/staging/prod)"
  type        = string
}

variable "region" {
  description = "AWS Region. AZ 자동 선택을 위해 사용"
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

/*
  서브넷 CIDR은 운영 표준에 맞게 env에서 주입
  (계층/가독성 확보를 위해 명시적으로 받는다)
*/
variable "public_subnet_cidrs" {
  description = "Public subnet CIDR list (2AZ)"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "Private App subnet CIDR list (2AZ)"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "Private DB subnet CIDR list (2AZ)"
  type        = list(string)
}

variable "enable_eks_subnet_tags" {
  description = "EKS 사용 시 kubernetes subnet tag 자동 부여 여부"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "EKS 클러스터 이름 (enable_eks_subnet_tags=true일 때만 사용)"
  type        = string
  default     = null
}

variable "tags" {
  description = "추가 태그 (팀/비용센터 등). 공통 태그에 merge됨"
  type        = map(string)
  default     = {}
}