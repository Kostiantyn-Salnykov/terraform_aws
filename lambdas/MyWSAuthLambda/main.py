
def main(event, context):
    # Extract the necessary information from the event
    connection_id = event['requestContext']['connectionId']
    route_key = event['requestContext']['routeKey']
    headers = event['headers']
    authorization_token = headers.get('Authorization')
    print(event)
    print(context)

    # Perform your authorization logic here
    # For example, you can validate the authorization token and check if the requester has access rights

    # If authorization is successful, return an "Allow" policy
    if authorize_request(authorization_token, route_key):
        policy = generate_policy('Allow', connection_id)
    else:
        # If authorization fails, return a "Deny" policy
        policy = generate_policy('Deny')

    print(policy)
    return policy


def authorize_request(authorization_token, route_key):
    # Implement your authorization logic here
    # Return True if the requester is authorized, otherwise False
    if authorization_token == 'test' and route_key == '$connect':
        return True
    return False


def generate_policy(effect, connection_id=None):
    policy = {
        'principalId': 'user',
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': '*'
                }
            ]
        },
    }
    if connection_id:
        policy['context'] = {
            'ConnectionId': connection_id
        }
    return policy
