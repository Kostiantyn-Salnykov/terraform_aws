variable "project_name" {
  description = "Name of the project."
  type        = string
  default     = "MyAWS"
}

variable "domain_name" {
  description = "Base name of domain"
  type        = string
  default     = "ksalnykov.com"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile_name" {
  description = "Name of profile for AWS."
  type        = string
  default     = "default"
}

variable "env" {
  description = "Name of environment, one of: `dev`, `test`, `prod`."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "The `env` variable should be one of: `dev`, `test`, `prod`."
  }
}

variable "github_access_token" {
  description = "GitHub access token for repo. Used by AWS Amplify."
  type = string
}

variable "frontend_repository_url" {
  description = "GitHub repository URL for Front-end app."
  type = string
  default = "https://github.com/Kostiantyn-Salnykov/VueApp"
}
