output "api_endpoint" {
  description = "Base URL the React frontend should call"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "frontend_bucket_name" {
  description = "Sync the React build here: aws s3 sync build/ s3://<this>"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_url" {
  description = "The real frontend origin — no Route 53, so this is CloudFront's own domain"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "opportunities_table_name" {
  value = aws_dynamodb_table.opportunities.name
}

output "registrations_table_name" {
  value = aws_dynamodb_table.registrations.name
}
