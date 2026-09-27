variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "volunteer-connect"
}

variable "cognito_user_pool_id" {
  description = "Manually-created Cognito User Pool (Volunteer_Connect_UserPool) — not managed by this Terraform state"
  type        = string
  default     = "us-east-1_RemUnMfvl"
}

variable "cognito_app_client_id" {
  description = "The real frontend's app client — confirmed live with the frontend teammate as Volunteer_Connect_React, not the stray 'My SPA app - cv-ahl' client also present on this pool"
  type        = string
  default     = "5uroae59ph7d694hrti0ipul20"
}
