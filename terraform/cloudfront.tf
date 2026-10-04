# CloudFront in front of the frontend bucket. No Route 53 / custom domain —
# the site is served from CloudFront's own *.cloudfront.net domain, using
# CloudFront's default TLS certificate.
#
# The bucket is private (see s3-frontend.tf); CloudFront reaches it through
# Origin Access Control (OAC), not the old public-website-hosting pattern.
# That's also why the custom error responses below exist: a private S3
# origin just serves plain object requests, it doesn't have S3 website
# hosting's index/error-document behavior — so React Router's client-side
# routes (anything that isn't a real object in the bucket) have to be
# mapped back to index.html here instead.
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # cheapest tier: North America + Europe edge locations only
  aliases             = ["volunteer-connect.com", "www.volunteer-connect.com"]

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # A private bucket returns 403 (not 404) for a path that isn't a real
  # object — both cases mean "let React Router handle this client-side".
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.frontend.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
