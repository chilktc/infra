/*
  variables.tf

  prod 환경에서 사용하는 변수 정의
  (terraform.tfvars에서 명시적으로 주입)
*/

variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}

variable "eks_cluster_name" {
  type = string
}