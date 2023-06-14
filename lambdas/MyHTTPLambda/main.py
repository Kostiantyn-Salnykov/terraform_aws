import json
import logging

logger = logging.getLogger(name=__name__)
logger.setLevel(level=logging.INFO)


def main(event, context):
    logger.info(event)
    logger.info(context)
    return {
        "isBase64Encoded": False,
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"Hello": "World!"}),
    }
