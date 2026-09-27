resource "aws_dynamodb_table" "opportunities" {
  name         = "${var.project_name}-opportunities"
  billing_mode = "PAY_PER_REQUEST" # on-demand — no capacity to plan for a class project's traffic
  hash_key     = "opportunity_id"

  attribute {
    name = "opportunity_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  # Only real query pattern beyond the primary key: "show this org its own
  # postings." Everything else (browse/search) is a table-scale scan,
  # which is fine at this project's size — see list_opportunities' handler.
  global_secondary_index {
    name            = "org-index"
    hash_key        = "org_id"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "registrations" {
  name         = "${var.project_name}-registrations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "registration_id"

  attribute {
    name = "registration_id"
    type = "S"
  }

  attribute {
    name = "opportunity_id"
    type = "S"
  }

  # Required for "organizations can view registrations" — querying by
  # opportunity_id is the whole point of this table from the org's side.
  global_secondary_index {
    name            = "opportunity-index"
    hash_key        = "opportunity_id"
    projection_type = "ALL"
  }
}
