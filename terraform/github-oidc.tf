# Lets GitHub Actions (in the frontend repo) deploy the frontend without
# any long-lived AWS access keys stored as a GitHub secret. GitHub's OIDC
# token proves "this run really is volunteer-connect-frontend, on main" and
# AWS trusts that directly — no secret to leak, rotate, or accidentally
# commit.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Verified directly against the live cert chain (openssl s_client against
  # token.actions.githubusercontent.com), not copied from a tutorial — GitHub
  # serves Let's Encrypt certs now, not the older DigiCert chain many older
  # guides still reference. AWS no longer actually validates against this
  # value for well-known CAs, but the field still requires a syntactically
  # valid 40-char SHA1 hex thumbprint.
  thumbprint_list = ["ab9d0263244dd0326eb67015705a667e79cfe998"]
}

# Trust is scoped tightly on purpose: only this one repo, only the main
# branch. A workflow run on a fork or a feature branch can't assume this
# role, even though the OIDC provider itself is account-wide.
resource "aws_iam_role" "github_actions_frontend_deploy" {
  name = "${var.project_name}-frontend-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:gkoufie1/volunteer-connect-frontend:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Exactly two things this role can do: sync files to the one frontend
# bucket, and invalidate the one CloudFront distribution. Nothing else in
# this account is reachable through it.
resource "aws_iam_role_policy" "github_actions_frontend_deploy" {
  name = "${var.project_name}-frontend-deploy-policy"
  role = aws_iam_role.github_actions_frontend_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = aws_cloudfront_distribution.frontend.arn
      }
    ]
  })
}

output "github_actions_deploy_role_arn" {
  description = "Give this to whoever owns volunteer-connect-frontend, for the GitHub Actions workflow"
  value       = aws_iam_role.github_actions_frontend_deploy.arn
}
