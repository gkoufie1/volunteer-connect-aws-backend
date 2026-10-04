locals {
  functions = {
    create_opportunity = { route = "POST /opportunities", auth_required = true }
    list_opportunities = { route = "GET /opportunities", auth_required = false }
    get_opportunity    = { route = "GET /opportunities/{id}", auth_required = false }
    register_volunteer = { route = "POST /opportunities/{id}/registrations", auth_required = true }
    list_registrations = { route = "GET /opportunities/{id}/registrations", auth_required = true }
  }
}

# Shared response/CORS helper, packaged once as a layer instead of copy-pasted
# into all five function zips.
data "archive_file" "common_layer" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/common"
  output_path = "${path.module}/build/common-layer.zip"
}

resource "aws_lambda_layer_version" "common" {
  layer_name          = "${var.project_name}-common"
  filename            = data.archive_file.common_layer.output_path
  source_code_hash    = data.archive_file.common_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

data "archive_file" "function" {
  for_each    = local.functions
  type        = "zip"
  source_dir  = "${path.module}/../lambda/${each.key}"
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_lambda_function" "this" {
  for_each         = local.functions
  function_name    = "${var.project_name}-${each.key}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.function[each.key].output_path
  source_code_hash = data.archive_file.function[each.key].output_base64sha256
  layers           = [aws_lambda_layer_version.common.arn]
  timeout          = 10

  environment {
    variables = {
      OPPORTUNITIES_TABLE = aws_dynamodb_table.opportunities.name
      REGISTRATIONS_TABLE = aws_dynamodb_table.registrations.name
    }
  }
}

resource "aws_lambda_permission" "apigw" {
  for_each      = local.functions
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
