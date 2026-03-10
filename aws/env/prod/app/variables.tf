variable "project" {
  type    = string
  default = "t7-mindlog"
}

variable "env" {
  type    = string
  default = "prod"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "instance_count" {
  type    = number
  default = 4
}

variable "gf_admin_password" {
  type      = string
  sensitive = true
}

variable "os_admin_password" {
  type      = string
  sensitive = true
}
