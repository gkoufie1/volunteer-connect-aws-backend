import os
import boto3

import sys
sys.path.append("/opt/python")
from response import respond, error

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["OPPORTUNITIES_TABLE"])


def handler(event, context):
    opportunity_id = event["pathParameters"]["id"]
    result = table.get_item(Key={"opportunity_id": opportunity_id})

    item = result.get("Item")
    if not item:
        return error(404, "Opportunity not found")

    return respond(200, item)
