variable "env" {
  description = "Name for environment."
  type        = string
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

variable "cognito_data" {
  description = "Proxy data from cognito module."
  type        = map(any)
}

locals {
  authorizer_type = "JWT"
}


resource "aws_apigatewayv2_deployment" "MyAPIDeployment" {
  api_id      = aws_apigatewayv2_api.MyAPI.id
  description = "Built from Terraform at ${formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())}."

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_apigatewayv2_route.MyHTTPRoute
  ]
}

resource "aws_apigatewayv2_api" "MyAPI" {
  name                         = "MyAPI-${var.env}"
  description                  = "My HTTP API for `${var.env}` environment."
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true # use `true` when custom domain enabled
  version                      = "1"
  #  route_key                    = ""

  cors_configuration {
    #    allow_credentials = true
    allow_headers  = ["*"]
    allow_methods  = ["*"]
    allow_origins  = ["*"]
    expose_headers = ["*"]
    max_age        = 60
  }
}

resource "aws_apigatewayv2_domain_name" "MyAPIGatewayDomainName" {
  domain_name = "${var.env}-api.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.MyCertificate.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "MyAPIGatewayRoute53Record" {
  name    = aws_apigatewayv2_domain_name.MyAPIGatewayDomainName.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.MyRoute53Zone.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.MyAPIGatewayDomainName.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.MyAPIGatewayDomainName.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_api_mapping" "MyAPIGatewayDomainMapping" {
  api_id          = aws_apigatewayv2_api.MyAPI.id
  domain_name     = aws_apigatewayv2_domain_name.MyAPIGatewayDomainName.domain_name
  stage           = aws_apigatewayv2_stage.MyAPIStage.name
  api_mapping_key = ""

  depends_on = [
    aws_apigatewayv2_domain_name.MyAPIGatewayDomainName
  ]
}

module "MyHTTPLambda" {
  source             = "../lambda"
  env                = var.env
  lambda_folder_name = "MyHTTPLambda"
  lambda_name        = "MyHTTPLambda"
}

resource "aws_iam_role" "MyAPIGatewayAuthorizerRole" {
  name = "MyAPIGatewayAuthorizerRole"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "apigateway.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_policy" "MyAPIGatewayAuthorizerPolicy" {
  name        = "MyAPIGatewayAuthorizerPolicy"
  description = "IAM policy for API Gateway Cognito authorizer."

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "cognito-idp:AdminGetUser",
            "cognito-idp:InitiateAuth",
            "cognito-idp:RespondToAuthChallenge"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "api_gateway_authorizer_policy_attachment" {
  role       = aws_iam_role.MyAPIGatewayAuthorizerRole.name
  policy_arn = aws_iam_policy.MyAPIGatewayAuthorizerPolicy.arn
}

resource "aws_apigatewayv2_authorizer" "MyAPIGatewayCognitoAuthorizer" {
  api_id                     = aws_apigatewayv2_api.MyAPI.id
  authorizer_type            = local.authorizer_type
  identity_sources           = ["$request.header.Authorization"]
  authorizer_uri             = var.cognito_data.user_pool.endpoint
  authorizer_credentials_arn = aws_iam_role.MyAPIGatewayAuthorizerRole.arn
  name                       = "MyCognitoAuthorizer"
  jwt_configuration {
    audience = [data.aws_cognito_user_pool_client.MyCognitoUserPoolClient.id]
    issuer   = "https://${var.cognito_data.user_pool.endpoint}"
  }
}

resource "aws_apigatewayv2_integration" "MyHTTPLambdaIntegration" {
  api_id = aws_apigatewayv2_api.MyAPI.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = module.MyHTTPLambda.invoke_arn
}

resource "aws_apigatewayv2_route" "MyHTTPRoute" {
  api_id    = aws_apigatewayv2_api.MyAPI.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.MyHTTPLambdaIntegration.id}"

  authorizer_id      = aws_apigatewayv2_authorizer.MyAPIGatewayCognitoAuthorizer.id
  authorization_type = local.authorizer_type
}

resource "aws_apigatewayv2_stage" "MyAPIStage" {
  api_id = aws_apigatewayv2_api.MyAPI.id
  name   = var.env

  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.MyAPILogGroup.arn
    format = jsonencode({
      # Account context
      accountId = "$context.accountId"
      apiId     = "$context.apiId"
      stage     = "$context.stage"
      # Identity context
      sourceIp         = "$context.identity.sourceIp"
      identityProvider = "$context.identity.cognitoAuthenticationProvider"
      identityId       = "$context.identity.cognitoIdentityId"
      identityPoolId   = "$context.identity.cognitoIdentityPoolId"
      # Request context
      requestId        = "$context.requestId"
      domainName       = "$context.domainName"
      protocol         = "$context.protocol"
      httpMethod       = "$context.httpMethod"
      resourcePath     = "$context.resourcePath"
      fullPath         = "$context.path"
      requestTime      = "$context.requestTime"
      requestTimeEpoch = "$context.requestTimeEpoch"
      # Extra context
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_lambda_permission" "MyAPIGatewayLambdaPermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.MyHTTPLambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.MyAPI.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "MyAPILogGroup" {
  name = "/aws/api-gw/${aws_apigatewayv2_api.MyAPI.name}"

  retention_in_days = 14
}

data "aws_acm_certificate" "MyCertificate" {
  domain = "*.${var.domain_name}"
  types  = ["AMAZON_ISSUED"]
}

data "aws_route53_zone" "MyRoute53Zone" {
  name = var.domain_name
}

data "aws_cognito_user_pool_client" "MyCognitoUserPoolClient" {
  # Since I have only 1 client in Cognito, I can use [0] index for it.
  client_id    = tolist(data.aws_cognito_user_pool_clients.MyCognitoUserPoolClients.client_ids)[0]
  user_pool_id = var.cognito_data.user_pool.id
}

data "aws_cognito_user_pool_clients" "MyCognitoUserPoolClients" {
  user_pool_id = var.cognito_data.user_pool.id
}
