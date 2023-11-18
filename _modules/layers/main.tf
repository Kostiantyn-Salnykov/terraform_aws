# ==Variables==
variable "layer_folder_name" {
  description = "Name for folder"
  default     = "pydantic_with_env"
  type        = string
}

variable "layer_name" {
  description = "Name for the layer."
  default     = "MyLayer"
  type        = string
}

variable "layer_description" {
  description = "Description for the layer."
  default     = "MyLayer"
  type        = string
}

variable "layer_license" {
  description = "License for the layer."
  default     = "MIT"
  type        = string
}

variable "layer_runtimes" {
  description = "List of runtimes for the layer."
  default     = ["python3.8", "python3.9", "python3.10"]
  type        = list(string)
}

variable "layer_architectures" {
  description = "List of architecture for the layer."
  default     = ["x86_64"]
  type        = list(string)
}
# =====

# ==Locals==
locals {
  py_folder_name     = "python"
  layers_folder_name = ".layers" # add this to .gitignore
  layer_filepath     = "${path.root}/${local.layers_folder_name}/${var.layer_folder_name}/${local.py_folder_name}.zip"
}
# =====


# ==Resources==
resource "aws_lambda_layer_version" "MyLambdaLayer" {
  layer_name               = var.layer_name
  description              = var.layer_description
  license_info             = var.layer_license
  filename                 = local.layer_filepath
  compatible_architectures = var.layer_architectures
  compatible_runtimes      = var.layer_runtimes
  #  skip_destroy             = true # force recreate layer.
  source_code_hash = try(filebase64sha256(local.layer_filepath), null) # Ignore 1st deploy error

  depends_on = [
    null_resource.MyLambdaCreator,
  ]
}

resource "null_resource" "MyLambdaCreator" {
  provisioner "local-exec" {
    command = templatefile(
      "${path.module}/layer_builder.sh",
      {
        "python_folder_name" : local.py_folder_name,
        "layers_folder_name" : local.layers_folder_name,
        "layer_folder_name" : var.layer_folder_name,
        "libraries" : [
          { "name" : "pydantic[email,dotenv]", "version" : "" },
        ]
      }
    )
  }

  triggers = {
    #    "run_at" = timestamp() # Should build all the time because of unique value.
    "run_at" = try(filebase64sha256(local.layer_filepath), timestamp())
  }
}
# =====

# ==Outputs==
output "arn_version" {
  value = aws_lambda_layer_version.MyLambdaLayer.arn
}

output "arn" {
  value = aws_lambda_layer_version.MyLambdaLayer.layer_arn
}

output "version" {
  value = aws_lambda_layer_version.MyLambdaLayer.version
}

output "layer_name" {
  value = aws_lambda_layer_version.MyLambdaLayer.layer_name
}
# =====
