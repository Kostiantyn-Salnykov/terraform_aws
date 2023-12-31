terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
    }
  }
}

locals {
  tags                = { "Terraform" : true, "Project" : var.project_name, "Environment" : var.env }
  name_prefix         = "${local.tags["Project"]}-${var.env}"
  availability_zones  = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  ecs_domain_name     = "${var.env}-service.${var.domain_name}" # <ENV>-service.<DOMAIN NAME>
  amplify_domain_name = "${var.env}-app.${var.domain_name}"     # <ENV>-app.<DOMAIN NAME>
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile_name
  default_tags {
    tags = local.tags
  }
}

#module "MyAWSBucket" {
#  source      = "./_modules/simple_storage_service"
#  bucket_name = "${local.name_suffix}-ksalnykov.com"
#}

module "MySiteBucket" {
  source      = "./_modules/s3_cloudfront"
  name_prefix = local.name_prefix
  env         = var.env
}

#module "MyDefaultVPC" {
#  source             = "./_modules/default_vpc"
#  availability_zones = local.availability_zones
#}

module "MyVPC" {
  source             = "./_modules/vpc"
  availability_zones = local.availability_zones
  tags               = local.tags
}

module "MyAWSECR" {
  source = "./_modules/ecr"
}

module "MyAWSECS" {
  source                       = "./_modules/ecs"
  name_prefix                  = local.name_prefix
  ecr_image_url                = module.MyAWSECR.image_url
  ecs_task_execution_role_name = "${local.name_prefix}-task-execution-role"
  ecs_task_role_name           = "${local.name_prefix}-task-role"
  vpc_id                       = module.MyVPC.id
  ecs_domain                   = local.ecs_domain_name
  domain                       = var.domain_name
  tasks_count                  = 0
}

module "MySES" {
  source          = "./_modules/ses"
  domain          = var.domain_name
  no_reply_domain = "no-reply.ksalnykov.com"
}

module "MyCognito" {
  source               = "./_modules/cognito"
  domain               = var.domain_name
  GOOGLE_CLIENT_ID     = var.GOOGLE_CLIENT_ID
  GOOGLE_CLIENT_SECRET = var.GOOGLE_CLIENT_SECRET
}

module "MySSM" {
  source       = "./_modules/ssm"
  env          = var.env
  cognito_data = module.MyCognito.MyData
}

module "MyLayers" {
  source = "./_modules/layers"
}

module "MyLambdas" {
  source       = "./_modules/lambda"
  env          = var.env
  environments = ["DEBUG", ]
}

module "MyAPIGateway" {
  source       = "./_modules/api_gateway"
  env          = var.env
  cognito_data = module.MyCognito.MyData
  name_prefix  = local.name_prefix
}

module "MySNS" {
  source = "./_modules/sns"
}

#module "MyCloudWatchAlarm" {
#  source = "./_modules/cloudwatch"
#  name_suffix = local.name_suffix
#}


module "MyAmplifyApp" {
  source         = "./_modules/amplify"
  env            = var.env
  name_suffix    = local.name_prefix
  domain_name    = local.amplify_domain_name
  access_token   = var.github_access_token
  repository_url = var.frontend_repository_url
}

module "MySQS" {
  source      = "./_modules/sqs"
  name        = "MyQueue"
  name_prefix = local.name_prefix
}

module "MyAPIGatewayWS" {
  source      = "./_modules/api_gateway_ws"
  name_prefix = local.name_prefix
  env         = var.env
}

module "MyRDSPostgreSQL" {
  source            = "./_modules/rds_postgresql"
  POSTGRES_DB       = var.POSTGRES_DB
  POSTGRES_USERNAME = var.POSTGRES_USERNAME
  POSTGRES_PASSWORD = var.POSTGRES_PASSWORD
  vpc_id            = module.MyVPC.id
  name_prefix       = local.name_prefix
  tags              = local.tags
}
