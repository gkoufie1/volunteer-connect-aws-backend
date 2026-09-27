import json
import os
import time
import uuid
import boto3
from botocore.exceptions import ClientError

import sys
sys.path.append("/opt/python")
from response import respond, error

dynamodb = boto3.client("dynamodb")
OPPORTUNITIES_TABLE = os.environ["OPPORTUNITIES_TABLE"]
REGISTRATIONS_TABLE = os.environ["REGISTRATIONS_TABLE"]


def handler(event, context):
    opportunity_id = event["pathParameters"]["id"]

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return error(400, "Request body must be valid JSON")

    volunteer_name = body.get("volunteer_name")
    volunteer_email = body.get("volunteer_email")
    if not volunteer_name or not volunteer_email:
        return error(400, "volunteer_name and volunteer_email are required")

    registration_id = str(uuid.uuid4())

    # TransactWriteItems, not a plain get-then-update: without this, two
    # volunteers signing up for the last open spot at the same moment could
    # both read "1 spot left" before either write lands, and both get
    # registered — overbooking the opportunity. The condition expression
    # makes AWS itself reject the second write instead of trusting this
    # code to check first, the same reasoning as CuttiWorld's booking locks.
    try:
        dynamodb.transact_write_items(
            TransactItems=[
                {
                    "Update": {
                        "TableName": OPPORTUNITIES_TABLE,
                        "Key": {"opportunity_id": {"S": opportunity_id}},
                        "ConditionExpression": "attribute_exists(opportunity_id) AND volunteers_registered < volunteers_needed",
                        "UpdateExpression": "ADD volunteers_registered :one",
                        "ExpressionAttributeValues": {":one": {"N": "1"}},
                    }
                },
                {
                    "Put": {
                        "TableName": REGISTRATIONS_TABLE,
                        "Item": {
                            "registration_id": {"S": registration_id},
                            "opportunity_id": {"S": opportunity_id},
                            "volunteer_name": {"S": volunteer_name},
                            "volunteer_email": {"S": volunteer_email},
                            "registered_at": {"N": str(int(time.time()))},
                        },
                        "ConditionExpression": "attribute_not_exists(registration_id)",
                    }
                },
            ]
        )
    except ClientError as err:
        if err.response["Error"]["Code"] == "TransactionCanceledException":
            return error(409, "This opportunity is full or no longer exists")
        raise

    return respond(201, {
        "registration_id": registration_id,
        "opportunity_id": opportunity_id,
        "volunteer_name": volunteer_name,
        "volunteer_email": volunteer_email,
    })
