import json
import names


def lambda_handler(event, context):
    return json.dumps({"name": names.get_full_name()})
