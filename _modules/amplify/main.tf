# ==Variables==
variable "name_suffix" {
  default = "Project with environment name."
  type    = string
}

variable "env" {
  description = "Name for environment."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "domain_name" {
  description = "Domain for the app."
  type        = string
}

variable "repository_url" {
  description = "GitHub repository URL for Front-end app."
  type        = string
}

variable "access_token" {
  default = "GitHub access token for repo. Used by AWS Amplify."
  type    = string
}
# =====


# ==Locals==
locals {
  basic_username = "Admin"
  basic_password = "admin123"
  branch_name    = var.env
}
# =====


resource "aws_amplify_app" "MyAmplifyApp" {
  name        = "${var.name_suffix}-app"
  description = "Vue.js application."

  repository                  = var.repository_url
  access_token                = var.access_token
  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true

  enable_basic_auth      = true
  basic_auth_credentials = base64encode("${local.basic_username}:${local.basic_password}")

  build_spec = file("${path.module}/buildspec.yaml")

  custom_rule {
    source = "/*"
    status = "404"
    target = "/index.html"
  }

  environment_variables = {
    ENV = var.env
  }
}

resource "aws_amplify_branch" "MyAmplifyBranch" {
  app_id      = aws_amplify_app.MyAmplifyApp.id
  branch_name = local.branch_name

  framework                   = "vue"
  stage                       = "DEVELOPMENT" # "PRODUCTION", "BETA", "DEVELOPMENT", "EXPERIMENTAL", "PULL_REQUEST"
  enable_auto_build           = true
  enable_pull_request_preview = true
}

resource "aws_amplify_domain_association" "MyAmplifyDomain" {
  app_id      = aws_amplify_app.MyAmplifyApp.id
  domain_name = var.domain_name

  sub_domain {
    branch_name = aws_amplify_branch.MyAmplifyBranch.branch_name
    prefix      = ""
  }

  sub_domain {
    branch_name = aws_amplify_branch.MyAmplifyBranch.branch_name
    prefix      = "www"
  }
}
