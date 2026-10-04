resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "https://${aws_cloudfront_distribution.frontend.domain_name}",
      "https://volunteer-connect.com",
      "https://www.volunteer-connect.com",
      "http://localhost:5173", # local frontend dev server
    ]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_apigatewayv2_integration" "this" {
  for_each               = local.functions
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this[each.key].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-cognito-authorizer"

  jwt_configuration {
    audience = [var.cognito_app_client_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

resource "aws_apigatewayv2_route" "this" {
  for_each  = local.functions
  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value.route
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"

  authorization_type = each.value.auth_required ? "JWT" : "NONE"
  authorizer_id      = each.value.auth_required ? aws_apigatewayv2_authorizer.cognito.id : null
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }
}
