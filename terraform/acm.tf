# Certificate for the custom domain (volunteer-connect.com, no Route 53 —
# DNS lives at GoDaddy). This only requests the certificate and asks ACM
# for the DNS records needed to prove ownership; it does NOT wait for
# validation and does NOT wire the cert into CloudFront yet. Those come in
# a second pass, once the validation CNAME has actually been added at
# GoDaddy and had time to propagate — ACM can't validate a record that
# doesn't exist yet, so doing it all in one step would just hang.
#
# CloudFront only accepts certificates from us-east-1, which is already
# this project's region (see variables.tf), so no second provider alias
# is needed here.
resource "aws_acm_certificate" "frontend" {
  domain_name               = "volunteer-connect.com"
  subject_alternative_names = ["www.volunteer-connect.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# The DNS records are live at GoDaddy and ACM has already validated them
# (checked by hand before adding this). This resource just makes that
# validated state visible to Terraform, so cloudfront.tf can depend on a
# cert that's actually ready to use.
resource "aws_acm_certificate_validation" "frontend" {
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for o in aws_acm_certificate.frontend.domain_validation_options : o.resource_record_name]
}

output "acm_validation_records" {
  description = "Add each of these as a CNAME record in GoDaddy's DNS panel, then wait for them to propagate before the next step"
  value = [
    for o in aws_acm_certificate.frontend.domain_validation_options : {
      domain = o.domain_name
      name   = o.resource_record_name
      type   = o.resource_record_type
      value  = o.resource_record_value
    }
  ]
}
