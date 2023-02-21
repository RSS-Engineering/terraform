import requests

def get():
    return requests.get('http://ifconfig.co', headers={'User-Agent': 'curl/7.79.1'})
