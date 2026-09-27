import os
import boto3

import sys
sys.path.append("/opt/python")
from response import respond

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["REGISTRATIONS_TABLE"])


def handler(event, context):
    opportunity_id = event["pathParameters"]["id"]

    # Query, not scan — unlike browsing opportunities, "show me who signed
    # up for this specific posting" is exactly the access pattern a GSI is
    # for for. Scanning every registration in the table and filtering in
    # Python would get slower as sign-ups grow across every opportunity,
    # not just this one.
    response = table.query(
        IndexName="opportunity-index",
        KeyConditionExpression=boto3.dynamodb.conditions.Key("opportunity_id").eq(opportunity_id),
    )

    return respond(200, {"registrations": response.get("Items", [])})
