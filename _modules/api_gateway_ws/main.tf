variable "env" {
  description = "Name for environment."
  type        = string
}

variable "domain_name" {
  description = "Base name of domain"
  type        = string
  default     = "ksalnykov.com"
}

variable "name_prefix" {
  description = "Project with environment name."
  type        = string
}

variable "name" {
  description = "Name for WebSocket API."
  type        = string
  default     = "MyAPIGatewayWS"
}

locals {
  name = "${var.name_prefix}-${var.name}"
}

resource "aws_api_gateway_account" "MyAPIGatewaySettings" {
  cloudwatch_role_arn = aws_iam_role.MyCloudWatchRole.arn
}

resource "aws_iam_role" "MyCloudWatchRole" {
  name               = "MyCloudWatchRole"
  assume_role_policy = data.aws_iam_policy_document.MyAPIGatewayPolicyDocument.json
}

resource "aws_iam_role_policy" "MyCloudWatchRolePolicy" {
  name   = "MyCloudWatchRolePolicy"
  role   = aws_iam_role.MyCloudWatchRole.id
  policy = data.aws_iam_policy_document.MyCloudWatchPolicyDocument.json
}

resource "aws_apigatewayv2_deployment" "MyAPIDeployment" {
  api_id      = aws_apigatewayv2_api.MyWSAPIGateway.id
  description = "Built from Terraform at ${formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())}."

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_apigatewayv2_route.MyWSRouteDefault,
    aws_apigatewayv2_route.MyWSRouteConnect,
    aws_apigatewayv2_route.MyWSRouteDisconnect,
  ]
}

resource "aws_apigatewayv2_stage" "MyWSAPIStage" {
  api_id = aws_apigatewayv2_api.MyWSAPIGateway.id
  name   = var.env

  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.MyWSAPILogGroup.arn
    format = jsonencode({
      # https://docs.aws.amazon.com/apigateway/latest/developerguide/websocket-api-logging.html
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
      # Connection context
      connectedAt  = "$context.connectedAt"
      connectionId = "$context.connectionId"
      # WS related context
      eventType = "$context.eventType"
      messageId = "$context.messageId"
    })
  }
}

resource "aws_apigatewayv2_domain_name" "MyAPIGatewayDomainName" {
  domain_name = "${var.env}-ws.${var.domain_name}"

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
  api_id          = aws_apigatewayv2_api.MyWSAPIGateway.id
  domain_name     = aws_apigatewayv2_domain_name.MyAPIGatewayDomainName.domain_name
  stage           = aws_apigatewayv2_stage.MyWSAPIStage.name
  api_mapping_key = ""

  depends_on = [
    aws_apigatewayv2_domain_name.MyAPIGatewayDomainName
  ]
}

resource "aws_apigatewayv2_api" "MyWSAPIGateway" {
  name                       = local.name
  description                = "My WebSocket API for `${var.env}` environment."
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_route" "MyWSRouteDefault" {
  api_id    = aws_apigatewayv2_api.MyWSAPIGateway.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.MyWSLambdaIntegration.id}"
}

resource "aws_apigatewayv2_route" "MyWSRouteConnect" {
  api_id    = aws_apigatewayv2_api.MyWSAPIGateway.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.MyWSLambdaIntegration.id}"

  authorizer_id      = aws_apigatewayv2_authorizer.MyWSAPIGatewayAuthorizer.id
  authorization_type = "CUSTOM"
}

resource "aws_apigatewayv2_route" "MyWSRouteDisconnect" {
  api_id    = aws_apigatewayv2_api.MyWSAPIGateway.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.MyWSLambdaIntegration.id}"
}

resource "aws_apigatewayv2_integration_response" "MyWSRouteDefaultResponseIntegration" {
  api_id                        = aws_apigatewayv2_api.MyWSAPIGateway.id
  integration_id                = aws_apigatewayv2_integration.MyWSLambdaIntegration.id
  integration_response_key      = "$default"
  template_selection_expression = "\\$default"
}

resource "aws_apigatewayv2_route_response" "MyWSRouteDefaultResponse" {
  api_id             = aws_apigatewayv2_api.MyWSAPIGateway.id
  route_id           = aws_apigatewayv2_route.MyWSRouteDefault.id
  route_response_key = "$default"
}

resource "aws_cloudwatch_log_group" "MyWSAPILogGroup" {
  name = "/aws/apigateway/${aws_apigatewayv2_api.MyWSAPIGateway.id}"

  retention_in_days = 14
}

resource "aws_lambda_permission" "MyAPIGatewayLambdaPermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.MyWSLambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.MyWSAPIGateway.execution_arn}/*/*"
}

module "MyWSLambda" {
  source             = "../lambda"
  env                = var.env
  lambda_folder_name = "MyWSLambda"
  lambda_name        = "MyWSLambda"
}

resource "aws_apigatewayv2_integration" "MyWSLambdaIntegration" {
  api_id = aws_apigatewayv2_api.MyWSAPIGateway.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = module.MyWSLambda.invoke_arn
}

data "aws_acm_certificate" "MyCertificate" {
  domain = "*.${var.domain_name}"
  types  = ["AMAZON_ISSUED"]
}

data "aws_route53_zone" "MyRoute53Zone" {
  name = var.domain_name
}

data "aws_iam_policy_document" "MyCloudWatchPolicyDocument" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "MyAPIGatewayPolicyDocument" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# === Authorizer ===
module "MyWSAuthLambda" {
  source             = "../lambda"
  env                = var.env
  lambda_folder_name = "MyWSAuthLambda"
  lambda_name        = "MyWSAuthLambda"
}

# WORKING!!!
resource "aws_lambda_permission" "AllowExecutionFromAPIGatewayAuth" {
  statement_id  = "AllowExecutionFromAPIGatewayAuth"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = module.MyWSAuthLambda.function_name
  source_arn    = "${aws_apigatewayv2_api.MyWSAPIGateway.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.MyWSAPIGatewayAuthorizer.id}"
}

resource "aws_apigatewayv2_authorizer" "MyWSAPIGatewayAuthorizer" {
  name            = "MyWSAPIGatewayAuthorizer"
  api_id          = aws_apigatewayv2_api.MyWSAPIGateway.id
  authorizer_type = "REQUEST"
  authorizer_uri  = module.MyWSAuthLambda.invoke_arn
  identity_sources = [
    "route.request.header.Authorization",
  ]
}

resource "aws_apigatewayv2_integration" "MyWSAuthLambdaIntegration" {
  api_id = aws_apigatewayv2_api.MyWSAPIGateway.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = module.MyWSAuthLambda.invoke_arn
}
