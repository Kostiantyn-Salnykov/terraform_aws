

def main(event, context):
    print(event)
    print(context)

    # Handle WebSocket events here
    connection_id = event['requestContext']['connectionId']
    event_type = event['requestContext']['eventType']
    result = {"statusCode": 200}

    if event_type == 'CONNECT':
        # Handle CONNECT event
        result.update({"body": f"Connecting... ({event_type=}, {connection_id=})"})
    elif event_type == 'DISCONNECT':
        # Handle DISCONNECT event
        result.update({"body": f"Disconnecting... ({event_type=}, {connection_id=})"})
    elif event_type == 'MESSAGE':
        # Handle MESSAGE event
        body = event['body']
        result.update({"body": f"Hello from {event_type=}, {connection_id=}"})

    return result
