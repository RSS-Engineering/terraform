import requests

def get():
    return requests.get('https://api.ipify.org?format=json').json()
