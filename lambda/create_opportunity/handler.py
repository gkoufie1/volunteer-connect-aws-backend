import json
import os
import time
import uuid
import boto3

import sys
sys.path.append("/opt/python")  # common/ layer, wired up in Terraform
from response import respond, error

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["OPPORTUNITIES_TABLE"])

REQUIRED_FIELDS = ["org_name", "title", "date", "location", "volunteers_needed"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return error(400, "Request body must be valid JSON")

    # org_id comes from the verified JWT's `sub` claim, never from the
    # request body — the access token is the one thing a caller can't
    # forge, so it's the only safe source of "who actually owns this."
    # org_name has no such requirement; it's a display label, not an
    # authorization decision, so the client-supplied value is fine.
    claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
    org_id = claims["sub"]

    missing = [f for f in REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return error(400, f"Missing required field(s): {', '.join(missing)}")

    volunteers_needed = body["volunteers_needed"]
    if not isinstance(volunteers_needed, int) or volunteers_needed < 1:
        return error(400, "volunteers_needed must be a positive integer")

    opportunity_id = str(uuid.uuid4())
    item = {
        "opportunity_id": opportunity_id,
        "org_id": org_id,
        "org_name": body["org_name"],
        "title": body["title"],
        "category": body.get("category", ""),
        "description": body.get("description", ""),
        "location_type": body.get("location_type", ""),
        "date": body["date"],
        "start_time": body.get("start_time", ""),
        "end_time": body.get("end_time", ""),
        "location": body["location"],
        "volunteers_needed": volunteers_needed,
        "volunteers_registered": 0,
        "minimum_age": body.get("minimum_age", 0),
        "requirements": body.get("requirements", ""),
        "contact_email": body.get("contact_email", ""),
        "contact_phone": body.get("contact_phone", ""),
        "registration_deadline": body.get("registration_deadline", ""),
        "created_at": int(time.time()),
    }

    table.put_item(Item=item)
    return respond(201, item)
