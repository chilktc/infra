/*
  환경에 맞는 값 정의

  버킷 이름은 반드시 고유해야 함
  운영환경에서는 이 파일을 Git에 커밋해도 무방
*/

region            = "ap-northeast-2"
state_bucket_name = "t7-mindlog-tfstate-apne2-prod"
lock_table_name   = "t7-mindlog-terraform-lock-prod"