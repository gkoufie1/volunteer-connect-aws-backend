# Volunteer Connect — AWS Backend

Per Scholas cohort project: a platform connecting community organizations
posting volunteer opportunities with people looking to sign up. This repo
covers the AWS backend specifically — the frontend (React) is owned by
other teammates.

**Status:** ✅ Deployed to a live AWS account.

- API: `https://q2s6msjgr7.execute-api.us-east-1.amazonaws.com`
- Frontend bucket: `volunteer-connect-frontend-138420161398`
  (`volunteer-connect-frontend-138420161398.s3-website-us-east-1.amazonaws.com`)
- Tables: `volunteer-connect-opportunities`, `volunteer-connect-registrations`

## Architecture

```
React frontend (S3 static hosting)
        │
        ▼
   API Gateway (HTTP API)
        │
   ┌────┼────┬────────┬──────────────┐
   ▼    ▼    ▼         ▼              ▼
create list  get   register       list
oppty  oppty oppty  volunteer   registrations
   │    │    │         │              │
   └────┴────┴────┬────┘              │
                   ▼                  ▼
          Opportunities table   Registrations table
             (DynamoDB)             (DynamoDB)
```

Five Lambda functions, one per API route, sharing a single least-privilege
execution role scoped to just the two DynamoDB tables — not "dynamodb:\*"
on "\*".

## The one design decision worth explaining

**Signing up for an opportunity uses `TransactWriteItems`, not a plain
read-then-write.** If two volunteers hit the last open spot on an
opportunity at the same moment, a naive "check spots, then update" does
this:

1. Both requests read `volunteers_registered: 4` of `volunteers_needed: 5`
2. Both see "1 spot left" and both proceed
3. Both write — the opportunity is now overbooked

The transaction's `ConditionExpression` (`volunteers_registered <
volunteers_needed`) makes DynamoDB itself reject the second write
atomically — the code never has to trust its own check was still true by
the time it writes. Same reasoning as the slot-locking in the CuttiWorld
booking system.

**Write routes are authorized with a Cognito JWT authorizer on API
Gateway, not a header the Lambda trusts.** Posting an opportunity,
registering, and viewing an opportunity's registrant list all require a
valid access token from the `Volunteer_Connect_React` app client on the
`Volunteer_Connect_UserPool` pool. Handlers pull the caller's identity
from `event.requestContext.authorizer.jwt.claims.sub` — the verified
token — never from the request body, since the body is the one thing a
caller can forge. Browsing opportunities stays open (`GET
/opportunities`, `GET /opportunities/{id}`), since there's no
organization-owned data at stake in a read. The user pool itself is
created by hand outside this Terraform state; only its ID and app client
ID are referenced here (`variables.tf`), so it isn't reproducible from
`terraform apply` alone.

## What's real vs. simplified

- **Browsing/searching opportunities is a table `Scan`, not a `Query`** —
  reasonable at a class project's scale where there's no need to maintain
  an extra GSI just to sort a browse-everything page. Viewing an org's own
  postings *does* use a real GSI (`org-index`), since that's a genuine,
  repeated query pattern.
- **Registrations are queried by opportunity via a GSI** (`opportunity-index`)
  — this one earns its place, since "show this org who signed up" is the
  actual point of the table from the org's side.
- **One shared IAM role across all five functions**, not five separate
  ones — each function ends up with slightly more access than it
  individually uses, in exchange for one role to reason about. Worth
  splitting apart if this ever handles real organizations' data instead of
  a class demo.
- **CORS is scoped to the deployed frontend's S3 website origin**
  (`http://<frontend_website_url>`), not `*` — note the S3 static-website
  endpoint is HTTP-only, so this'll need revisiting if the frontend ever
  moves behind CloudFront/HTTPS.
- **SNS notifications** (from the original spec's optional features) are
  not built yet.

## Repository Structure

```
├── terraform/
│   ├── dynamodb.tf        # Opportunities + Registrations tables and GSIs
│   ├── iam.tf             # Shared least-privilege Lambda execution role
│   ├── lambda.tf          # Function packaging + the shared common/ layer
│   ├── api-gateway.tf     # HTTP API routes -> Lambda integrations
│   ├── s3-frontend.tf     # Static hosting bucket for the React build
│   └── outputs.tf
└── lambda/
    ├── common/response.py       # Shared response/CORS helper (packaged as a layer)
    ├── create_opportunity/
    ├── list_opportunities/
    ├── get_opportunity/
    ├── register_volunteer/      # The TransactWriteItems logic
    └── list_registrations/
```

## API

| Method | Path | Purpose | Auth |
|---|---|---|---|
| POST | `/opportunities` | Org posts a new opportunity | JWT required |
| GET | `/opportunities` | Browse/search (`?location=`, `?date=`) | open |
| GET | `/opportunities/{id}` | View one opportunity's details | open |
| POST | `/opportunities/{id}/registrations` | Volunteer signs up | JWT required |
| GET | `/opportunities/{id}/registrations` | Org views who's registered | JWT required |

## Deployment

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Then point the frontend at the `api_endpoint` output, and sync the React
build to the `frontend_bucket_name` output. For the write routes, the
frontend needs to attach the signed-in user's Cognito access token as
`Authorization: Bearer <token>` — sign-in itself is handled by the
frontend team against the `Volunteer_Connect_UserPool` pool.
