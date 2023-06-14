variable "env" {
  description = "Name for environment."
  type        = string
}

resource "aws_ssm_parameter" "MyEnvParameter" {
  name           = "/${var.env}/DEBUG"
  description    = "DEBUG parameter"
  type           = "String" # StringList, SecureString
  insecure_value = "True"
  #  value = "True"
  # Add validation with regex: allowed only True, False, true, false
  allowed_pattern = "^(?:Tru|Fals|tru|fals)e$"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}
