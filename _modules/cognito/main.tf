variable "domain" {
  description = "Domain name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "cognito_user_pool_name" {
  description = "Name for Cognito user pool."
  default     = "MyUserPool"
}

variable "ses_configuration_set_name" {
  description = "Name of SES configuration set."
  default     = "default"
}

variable "GOOGLE_CLIENT_ID" {
  description = "OpenID Connect Google client ID."
  type        = string
}

variable "GOOGLE_CLIENT_SECRET" {
  description = "OpenID Connect Google client secret."
  type        = string
}

locals {
  cognito_domain = "auth.${var.domain}"
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

resource "aws_cognito_user_pool" "MyUserPool" {
  name = var.cognito_user_pool_name

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }

    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  username_attributes = ["email"]
  mfa_configuration   = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 14
  }

  sms_authentication_message = "Here is your code {####} from MyCognito."

  user_pool_add_ons {
    advanced_security_mode = "OFF"
  }

  username_configuration {
    case_sensitive = false
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
    invite_message_template {
      email_subject = "MyProject invitation!!!"
      email_message = "You invited to our service, your username: `{username}` and password: `{####}`."
      sms_message   = "Username: {username}, password: {####}"
    }
  }

  device_configuration {
    challenge_required_on_new_device      = false
    device_only_remembered_on_user_prompt = true
  }

  email_configuration {
    configuration_set      = data.aws_sesv2_configuration_set.MySESConfigurationSet.id
    email_sending_account  = "DEVELOPER"
    from_email_address     = "no-reply@ksalnykov.com"
    reply_to_email_address = "contact@ksalnykov.com"
    source_arn             = data.aws_ses_domain_identity.MyDomainIdentity.arn
  }

  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_message_by_link = "Click here {##Click Here##} to activate your account."
    email_subject_by_link = "Account activation"
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = 0
      max_length = 1024
    }
  }

  schema {
    attribute_data_type = "String"
    name                = "phone_number"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = 0
      max_length = 15
    }
  }
}

resource "aws_cognito_identity_provider" "MyGoogleIDP" {
  user_pool_id  = aws_cognito_user_pool.MyUserPool.id
  provider_name = "Google"
  provider_type = "Google"
  provider_details = {
    client_id        = var.GOOGLE_CLIENT_ID
    client_secret    = var.GOOGLE_CLIENT_SECRET
    authorize_scopes = "email profile openid https://www.googleapis.com/auth/user.phonenumbers.read"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

resource "aws_cognito_user_pool_client" "MyCognitoUserPoolClient" {
  name         = "client"
  user_pool_id = aws_cognito_user_pool.MyUserPool.id

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  access_token_validity  = 2
  id_token_validity      = 2
  refresh_token_validity = 30


  auth_session_validity   = 15
  enable_token_revocation = true
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_CUSTOM_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  allowed_oauth_flows_user_pool_client = true
  #  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_flows           = ["implicit"] # For testing
  allowed_oauth_scopes          = ["phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"]
  prevent_user_existence_errors = "ENABLED"
  #  callback_urls                        = ["https://auth.ksalnykov.com/oauth2/idpresponse"]
  callback_urls                = ["https://jwt.io"] # For testing
  supported_identity_providers = ["COGNITO", aws_cognito_identity_provider.MyGoogleIDP.provider_name]
  generate_secret              = true
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "ksalnykov"
  user_pool_id = aws_cognito_user_pool.MyUserPool.id
}

resource "aws_cognito_user_pool_domain" "MyCognitoUserPoolDomain" {
  domain          = local.cognito_domain
  user_pool_id    = aws_cognito_user_pool.MyUserPool.id
  certificate_arn = data.aws_acm_certificate.MyCertificate.arn
}

resource "aws_route53_record" "MyCognitoDomainRoute53Record" {
  name            = local.cognito_domain
  type            = "CNAME"
  zone_id         = data.aws_route53_zone.MyRoute53Zone.zone_id
  ttl             = 300
  records         = [aws_cognito_user_pool_domain.MyCognitoUserPoolDomain.cloudfront_distribution]
  allow_overwrite = true
}

data "aws_sesv2_configuration_set" "MySESConfigurationSet" {
  configuration_set_name = var.ses_configuration_set_name
}

data "aws_ses_domain_identity" "MyDomainIdentity" {
  domain = var.domain
}

data "aws_acm_certificate" "MyCertificate" {
  domain = "*.${var.domain}"
  types  = ["AMAZON_ISSUED"]

  provider = aws.east
}

data "aws_route53_zone" "MyRoute53Zone" {
  name = var.domain
}

output "MyData" {
  value = tomap({ "user_pool" : aws_cognito_user_pool.MyUserPool })
}
