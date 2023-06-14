# ==Variables==
variable "ecr_name" {
  description = "ECR repository name."
  type        = string
  default     = "my_aws_ecr"
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "my_ecr_image_count_number" {
  type    = number
  default = 2
}
# =====

# ==Data==
data "aws_caller_identity" "MyCalledIdentity" {}

data "template_file" "MyDockerBuilder" {
  template = file("${path.module}/ecr_docker_builder.sh")

  vars = {
    aws_region      = var.aws_region
    repository_url  = aws_ecr_repository.MyECRRepository.repository_url
    account_id      = data.aws_caller_identity.MyCalledIdentity.account_id
    dockerfile_path = "${path.cwd}/Dockerfile"
  }
}
# =====

# ==Resources==
# Creates ECR repository.
resource "aws_ecr_repository" "MyECRRepository" {
  name         = var.ecr_name
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_lifecycle_policy" "MyECRLifecyclePolicy" {
  policy = jsonencode(
    {
      "rules" : [
        {
          "rulePriority" : 1,
          "description" : "Keep last ${var.my_ecr_image_count_number} images.",
          "selection" : {
            "tagStatus" : "any",
            "countType" : "imageCountMoreThan",
            "countNumber" : var.my_ecr_image_count_number
          },
          "action" : {
            "type" : "expire"
          }
        }
      ]
    }
  )
  repository = aws_ecr_repository.MyECRRepository.name
}

resource "null_resource" "MyECRPusher" {
  provisioner "local-exec" {
    command = data.template_file.MyDockerBuilder.rendered
  }

  triggers = {
    #    "run_at" = timestamp() # Should build all the time because of unique value.
    "run_at" = filemd5("${path.cwd}/Dockerfile")
  }

  depends_on = [
    aws_ecr_repository.MyECRRepository,
  ]
}
# =====

# ==Outputs==
output "image_url" {
  value = aws_ecr_repository.MyECRRepository.repository_url
}
# =====