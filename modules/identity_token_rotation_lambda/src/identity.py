import arrow
import requests
from aws_lambda_powertools.utilities import parameters

from common import constants
from common.logger import setup_logging

logger = setup_logging()


class RackspaceIdentity:
    def __init__(self, username, password, domain=None):
        self.url = _get_base_url_for_stage()
        self.username = username
        self.password = password
        self.domain = domain
        self._token = None
        self.expires_at = 0
        self.expiration_padding = 3600

    def authenticate(self):
        body = {
            "auth": {
                "passwordCredentials": {
                    "username": self.username,
                    "password": self.password,
                }
            }
        }

        if self.domain:
            body["auth"]["RAX-AUTH:domain"] = {"name": self.domain}

        resp = requests.post(
            f"{self.url}/v2.0/tokens", json=body, timeout=constants.DEFAULT_TIMEOUT
        )

        if not resp.ok:
            logger.error(f"Identity authentication failed - {resp.status_code}")
            resp.raise_for_status()

        auth = resp.json()["access"]["token"]

        self._token = auth["id"]
        self.expires_at = (
                arrow.get(auth["expires"]).int_timestamp - self.expiration_padding
        )
        logger.info("Refreshed Identity Token...")
        return self.token

    @property
    def is_expired(self):
        return arrow.utcnow().int_timestamp >= self.expires_at

    @property
    def token(self):
        if self._token and not self.is_expired:
            return self._token
        return self.authenticate()


class RackImpersonationIdentity:
    def __init__(self, username, password):
        self.url = _get_base_url_for_stage()
        self.username = username
        self.password = password
        self._token = None
        self.expires_at = 0
        self.expiration_padding = 3600

    def authenticate(self):
        body = {
            "auth": {
                "RAX-AUTH:domain": {"name": "Rackspace"},
                "passwordCredentials": {
                    "username": self.username,
                    "password": self.password,
                },
            }
        }

        resp = requests.post(
            f"{self.url}/v2.0/tokens", json=body, timeout=constants.DEFAULT_TIMEOUT
        )

        if not resp.ok:
            logger.error(f"Identity authentication failed - {resp.status_code}")
            resp.raise_for_status()

        auth = resp.json()["access"]["token"]

        self._token = auth["id"]
        self.expires_at = (
                arrow.get(auth["expires"]).int_timestamp - self.expiration_padding
        )
        logger.info("Refreshed Identity Token...")
        return self.token

    @property
    def is_expired(self):
        return arrow.utcnow().int_timestamp >= self.expires_at

    @property
    def token(self):
        if self._token and not self.is_expired:
            return self._token
        return self.authenticate()

    def _get_admin_user(self, tenant_id):
        headers = {"x-auth-token": self.token}
        params = {"tenant_id": tenant_id, "admin_only": True}
        resp = requests.get(
            f"{self.url}/v2.0/users",
            headers=headers,
            params=params,
            timeout=constants.DEFAULT_TIMEOUT,
        )

        if not resp.ok:
            logger.error(
                f"Could not get admin username - {resp.status_code}: {resp.text}"
            )
            resp.raise_for_status()

        logger.debug(resp.json())
        return resp.json()["users"][0]["username"]

    def get_impersonation_token(self, tenant_id):
        admin_user = self._get_admin_user(tenant_id)
        headers = {"x-auth-token": self.token}
        body = {
            "RAX-AUTH:impersonation": {
                "expire-in-seconds": 10800,
                "user": {"username": admin_user},
            }
        }
        resp = requests.post(
            f"{self.url}/v2.0/RAX-AUTH/impersonation-tokens",
            headers=headers,
            json=body,
            timeout=constants.DEFAULT_TIMEOUT,
        )

        if not resp.ok:
            logger.error(
                f"Failed to get impersonation token - {resp.status_code}: {resp.text}"
            )
            resp.raise_for_status()

        return resp.json()["access"]["token"]["id"]


def _get_base_url_for_stage():
    if constants.USE_JANUS_PROXY:
        return "https://proxy.api.manage.rackspace.com/identity"
    return "https://identity-internal.api.rackspacecloud.com"


def validate(token):
    url = _get_base_url_for_stage()
    resp = requests.get(
        f"{url}/v2.0/tokens/{token}",
        headers={"x-auth-token": token},
        timeout=constants.DEFAULT_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()


def racker_identity() -> RackspaceIdentity:
    secret = parameters.get_secret(
        name=f"{constants.STAGE}/observability/service-account", transform="json"
    )
    identity = RackspaceIdentity(
        secret["username"],  # type:ignore
        secret["password"],  # type:ignore
        domain="Rackspace",
    )
    return identity
