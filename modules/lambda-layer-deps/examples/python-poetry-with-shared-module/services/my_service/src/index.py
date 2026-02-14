from shared import myip

def lambda_handler(event, context):
    return myip.get()
