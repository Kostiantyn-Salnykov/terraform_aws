variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "domain" {
  description = "Domain for SES"
  type        = string
}

variable "no_reply_domain" {
  description = "No-reply Domain for SES"
  type        = string
}

resource "aws_sesv2_email_identity" "MyEmailIdentity" {
  email_identity         = "kostiantyn.salnykov@gmail.com"
  configuration_set_name = aws_sesv2_configuration_set.MyConfigurationSet.configuration_set_name
}

resource "aws_ses_domain_identity" "MyDomainIdentity" {
  domain = var.domain
}

resource "aws_ses_domain_identity_verification" "MyDomainIdentityVerification" {
  domain = aws_ses_domain_identity.MyDomainIdentity.domain
}

resource "aws_ses_domain_dkim" "MyDomainDKIM" {
  domain = aws_ses_domain_identity.MyDomainIdentity.domain
}

data "aws_route53_zone" "MyRoute53Zone" {
  name = var.domain
}

resource "aws_route53_record" "MyDomainDKIMRecords" {
  name    = "${aws_ses_domain_dkim.MyDomainDKIM.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  zone_id = data.aws_route53_zone.MyRoute53Zone.zone_id
  records = ["${aws_ses_domain_dkim.MyDomainDKIM.dkim_tokens[count.index]}.dkim.amazonses.com"]

  count = 3
}

resource "aws_sesv2_email_identity_mail_from_attributes" "MyNoReplyIdentity" {
  email_identity         = aws_ses_domain_identity.MyDomainIdentity.domain
  behavior_on_mx_failure = "REJECT_MESSAGE"
  mail_from_domain       = "no-reply.${aws_ses_domain_identity.MyDomainIdentity.domain}"
}

resource "aws_route53_record" "MyNoReplyMXRecord" {
  zone_id = data.aws_route53_zone.MyRoute53Zone.zone_id
  name    = var.no_reply_domain
  type    = "MX"
  ttl     = "300"
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "MyNoReplyTXTRecord" {
  zone_id = data.aws_route53_zone.MyRoute53Zone.zone_id
  name    = var.no_reply_domain
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_sesv2_configuration_set" "MyConfigurationSet" {
  configuration_set_name = "default"

  delivery_options {
    tls_policy = "REQUIRE"
  }

  reputation_options {
    reputation_metrics_enabled = false
  }
}
