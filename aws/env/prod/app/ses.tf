###############################
# Route 53 Hosted Zone
###############################
resource "aws_route53_zone" "main" {
  name = "bloom-chil.com"
  
  tags = var.default_tags
}

###############################
# SES Domain Identity
###############################
resource "aws_ses_domain_identity" "main" {
  domain = "bloom-chil.com"
}

###############################
# SES DKIM Verification
###############################
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = aws_route53_zone.main.zone_id
  name    = "${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

###############################
# SPF Record
###############################
resource "aws_route53_record" "ses_spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "bloom-chil.com"
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com ~all"]
}

###############################
# Outputs
###############################
output "nameservers" {
  value       = aws_route53_zone.main.name_servers
  description = "도메인 관리 화면(Registered Domains)에 입력해야 할 이름 서버 목록입니다."
}

output "ses_status" {
  value       = aws_ses_domain_identity.main.verification_token
  description = "SES 인증 토큰입니다."
}
