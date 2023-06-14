variable "env" {
  description = "Name for environment."
  type        = string
}

variable "environments" {
  description = "List of names for SSM parameters, that will be passed as a environment to the lambda."
  type        = list(string)
  default     = []
}

variable "lambda_name" {
  description = "Name for the lambda function."
  default     = "MyLambda"
  type        = string
}

variable "lambdas_source_dir_name" {
  description = "Name for directory where is all lambdas folders exists."
  default     = "lambdas"
  type        = string
}

variable "lambda_folder_name" {
  description = "Name of folder with lambda code in it."
  default     = "MyLambda"
  type        = string
}

variable "layers" {
  description = "Names for the layers that should be connected with lambda."
  type = list(object({
    layer_name    = string
    layer_version = string
  }))
  default = [{ "layer_name" : "MyLayer", "layer_version" : "" }]
  validation {
    condition     = length(var.layers) < 6
    error_message = "Maximum number of layers for Lambda function is 5."
  }
}


locals {
  archive_type           = "zip"
  lambda_folder_name     = var.lambda_folder_name
  lambda_source_dir_name = var.lambdas_source_dir_name
  lambda_source_dir_path = "${path.root}/${local.lambda_source_dir_name}/${local.lambda_folder_name}/"
  output_path            = "${path.root}/${local.lambda_source_dir_name}/${local.lambda_folder_name}.${local.archive_type}"
}


resource "aws_iam_role" "MyLambdaRole" {
  name = "${var.lambda_name}Role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        },
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "MyLambdaRolePolicyAttachment" {
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
  role       = aws_iam_role.MyLambdaRole.name
}

resource "aws_lambda_function" "MyLambda" {
  function_name = var.lambda_name
  description   = "My lambda description"
  role          = aws_iam_role.MyLambdaRole.arn
  handler       = "main.main"

  source_code_hash = data.archive_file.MyLambda.output_base64sha256
  architectures    = ["x86_64"]
  runtime          = "python3.10"
  package_type     = "Zip"
  filename         = local.output_path
  timeout          = 3   # seconds, default = 3
  memory_size      = 128 # default = 128

  environment {
    variables = {
      for envar in var.environments : envar => data.aws_ssm_parameter.ENVIRONMENTS[envar].value
    }
  }

  # Retrieve layer.arn (without version) from every layers.
  layers = [for layer in data.aws_lambda_layer_version.MyLayers : layer.arn]

  depends_on = [
    aws_iam_role_policy_attachment.MyLambdaRolePolicyAttachment,
    aws_cloudwatch_log_group.MyLambdaLogGroup,
  ]
}

resource "aws_cloudwatch_log_group" "MyLambdaLogGroup" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}


data "aws_ssm_parameter" "ENVIRONMENTS" {
  for_each = toset(var.environments)

  name = "/${var.env}/${each.value}"
}

data "aws_lambda_layer_version" "MyLayers" {
  # Build `layer_name` depends on layer_name and layer_version from layers list of objects.
  for_each = toset(
    [for layer_map in var.layers : "${layer_map.layer_name}%{if layer_map.layer_version != ""}:${layer_map.layer_version}%{endif}"]
  )

  layer_name = each.key
}

data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  name = "AWSLambdaBasicExecutionRole"
}

data "archive_file" "MyLambda" {
  type        = local.archive_type
  source_dir  = local.lambda_source_dir_path
  output_path = local.output_path
}


output "invoke_arn" {
  value = aws_lambda_function.MyLambda.invoke_arn
}

output "function_name" {
  value = aws_lambda_function.MyLambda.function_name
}