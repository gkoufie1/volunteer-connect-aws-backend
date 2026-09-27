resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# One shared role across all five functions, scoped to exactly these two
# tables and their indexes — not "dynamodb:*" on "*". Each function ends up
# with a little more access than it individually uses (e.g. create_opportunity
# can technically Scan, though its code never does) in exchange for one
# role to reason about instead of five. Worth splitting into per-function
# roles if this grows past a class project into something handling real
# organizations' data.
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.project_name}-dynamodb-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:TransactWriteItems",
      ]
      Resource = [
        aws_dynamodb_table.opportunities.arn,
        "${aws_dynamodb_table.opportunities.arn}/index/*",
        aws_dynamodb_table.registrations.arn,
        "${aws_dynamodb_table.registrations.arn}/index/*",
      ]
    }]
  })
}
