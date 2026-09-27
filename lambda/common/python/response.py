import json
import decimal


class DecimalEncoder(json.JSONEncoder):
    """DynamoDB returns numbers as Decimal — plain json.dumps can't serialize those."""
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def respond(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            # Frontend is hosted on S3, a different origin than the API —
            # CORS has to be explicit or the browser blocks every request.
            "Access-Control-Allow-Origin": "*",
            # Authorization has to be explicitly allowed too, or the
            # browser's CORS preflight blocks every authenticated request
            # before it ever reaches the JWT authorizer.
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "OPTIONS,GET,POST",
        },
        "body": json.dumps(body, cls=DecimalEncoder),
    }


def error(status_code, message):
    return respond(status_code, {"error": message})
