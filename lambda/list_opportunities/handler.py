import os
import boto3

import sys
sys.path.append("/opt/python")
from response import respond

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["OPPORTUNITIES_TABLE"])


def handler(event, context):
    # A full scan is fine at this project's scale (a class demo, not
    # thousands of live postings) — it keeps the table simple with no
    # extra GSI to maintain just for a "browse everything" page. If org_id
    # filtering needs to be fast later, that's the one query pattern
    # that'd actually justify adding a GSI.
    response = table.scan()
    items = response.get("Items", [])

    params = (event.get("queryStringParameters") or {})
    location_filter = (params.get("location") or "").strip().lower()
    date_filter = (params.get("date") or "").strip()

    if location_filter:
        items = [i for i in items if location_filter in i.get("location", "").lower()]
    if date_filter:
        items = [i for i in items if i.get("date") == date_filter]

    # Only show opportunities that still have open spots by default.
    if params.get("include_full") != "true":
        items = [i for i in items if i["volunteers_registered"] < i["volunteers_needed"]]

    items.sort(key=lambda i: i.get("date", ""))
    return respond(200, {"opportunities": items})
