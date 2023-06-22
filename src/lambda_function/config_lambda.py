import datetime


def lambda_handler(event, context):
    prefix_name = str(event["PrefixName"])
    date = datetime.datetime.utcnow().strftime("%Y%m%d%H%M%S")
    return f"{prefix_name}-{date}"
