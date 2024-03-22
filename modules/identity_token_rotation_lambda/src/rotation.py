# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
# https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas/blob/master/SecretsManagerRotationTemplate/lambda_function.py
import json
import os

import boto3
from aws_lambda_powertools import Logger
from aws_lambda_powertools.tracing import Tracer

import identity

logger = Logger()
trace = Tracer()

SERVICE_ACCOUNT_SECRET_ARN = os.environ["SERVICE_ACCOUNT_SECRET_ARN"]


@trace.capture_lambda_handler(capture_response=False)
@logger.inject_lambda_context()
def handler(event, _context):
    """Secrets Manager Rotation Template
    This is a template for creating an AWS Secrets Manager rotation lambda
    Args:
        event (dict): Lambda dictionary of event parameters. These keys must include the following:
            - SecretId: The secret ARN or identifier
            - ClientRequestToken: The ClientRequestToken of the secret version
            - Step: The rotation step (one of createSecret, setSecret, testSecret, or finishSecret)
        _context (LambdaContext): The Lambda runtime information
    Raises:
        ResourceNotFoundException: If the secret with the specified arn and stage does not exist
        ValueError: If the secret is not properly configured for rotation
        KeyError: If the event parameters do not contain the expected keys
    """
    arn = event["SecretId"]
    request_token = event["ClientRequestToken"]
    step = event["Step"]

    # Setup the client
    service_client = boto3.client("secretsmanager")

    # Make sure the version is staged correctly
    metadata = service_client.describe_secret(SecretId=arn)
    if not metadata["RotationEnabled"]:
        msg = f"Secret {arn} is not enabled for rotation"
        logger.error(msg)
        raise ValueError(msg)

    versions = metadata["VersionIdsToStages"]

    if request_token not in versions:
        msg = (
            f"Secret version {request_token} has no stage for rotation of secret {arn}."
        )
        logger.error(msg)
        raise ValueError(msg)

    if "AWSCURRENT" in versions[request_token]:
        logger.info(
            f"Secret version {request_token} already set as AWSCURRENT for secret {arn}"
        )
        return

    if "AWSPENDING" not in versions[request_token]:
        msg = f"Secret version {request_token} not set as AWSPENDING for rotation of secret {request_token}"
        logger.error(msg)
        raise ValueError(msg)

    if step == "createSecret":
        create_secret(service_client, arn, request_token)

    elif step == "setSecret":
        set_secret(service_client, arn, request_token)

    elif step == "testSecret":
        test_secret(service_client, arn, request_token)

    elif step == "finishSecret":
        finish_secret(service_client, arn, request_token)

    else:
        raise ValueError("Invalid step parameter")


def create_secret(service_client, arn, request_token):
    """Create the secret
    This method first checks for the existence of a secret for the passed in request_token.
    If one does not exist, it will generate a new secret and put it with the passed in
    request_token.
    Args:
        service_client (client): The secrets manager service client
        arn (string): The secret ARN or other identifier
        request_token (string): The ClientRequestToken associated with the secret version
    Raises:
        ResourceNotFoundException: If the secret with the specified arn and stage does not exist
    """
    # Make sure the current secret exists
    service_client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")

    # Now try to get the secret version, if that fails, put a new secret
    try:
        service_client.get_secret_value(
            SecretId=arn, VersionId=request_token, VersionStage="AWSPENDING"
        )
        logger.info(f"CreateSecret: Successfully retrieved secret for {arn}")
    except service_client.exceptions.ResourceNotFoundException as exc:
        # Create a new API token
        service_account = json.loads(
            service_client.get_secret_value(
                SecretId=SERVICE_ACCOUNT_SECRET_ARN, VersionStage="AWSCURRENT"
            )["SecretString"]
        )

        if not service_account["username"] or not service_account["password"]:
            raise KeyError(
                f"Service account username and password must be set in secret ARN: {SERVICE_ACCOUNT_SECRET_ARN}"
            ) from exc

        ri = identity.RackspaceIdentity(
            username=service_account["username"],
            password=service_account["password"],
            domain="Rackspace",
        )
        token = ri.token

        # Put the secret
        service_client.put_secret_value(
            SecretId=arn,
            ClientRequestToken=request_token,
            SecretString=token,
            VersionStages=["AWSPENDING"],
        )
        logger.info(
            f"CreateSecret: Successfully put secret for ARN {arn} and version {request_token}"
        )


def set_secret(service_client, arn, request_token):
    """Set the secret
    This method should set the AWSPENDING secret in the service that the secret belongs to.
    For example, if the secret is a database credential, this method should take the value of
    the AWSPENDING secret and set the user's password to this value in the database.
    Args:
        service_client (client): The secrets manager service client
        arn (string): The secret ARN or other identifier
        request_token (string): The ClientRequestToken associated with the secret version
    """

    # as this is just getting a token, we dont need to set anything.
    _ = request_token
    _ = service_client
    _ = arn


def test_secret(service_client, arn, request_token):
    """Test the secret
    This method should validate that the AWSPENDING secret works in the service that the secret
    belongs to. For example, if the secret is a database credential, this method should validate
    that the user can login with the password in AWSPENDING and that the user has all of the
    expected permissions against the database.
    Args:
        service_client (client): The secrets manager service client
        arn (string): The secret ARN or other identifier
        request_token (string): The ClientRequestToken associated with the secret version
    """
    secret = service_client.get_secret_value(SecretId=arn, VersionId=request_token)
    token = secret["SecretString"]
    try:
        identity.validate(token)
    except Exception as exc:
        raise ValueError(f"Secret is not valid: {str(exc)}") from exc


def finish_secret(service_client, arn, request_token):
    """Finish the secret
    This method finalizes the rotation process by marking the secret version passed in as the
    AWSCURRENT secret.
    Args:
        service_client (client): The secrets manager service client
        arn (string): The secret ARN or other identifier
        request_token (string): The ClientRequestToken associated with the secret version
    Raises:
        ResourceNotFoundException: If the secret with the specified arn does not exist
    """
    # First describe the secret to get the current version
    metadata = service_client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            if version == request_token:
                # The correct version is already marked as current, return
                logger.info(
                    f"FinishSecret: version {version} already marked as AWSCURRENT for {arn}"
                )
                return
            current_version = version
            break

    # Finalize by staging the secret version current
    service_client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=request_token,
        RemoveFromVersionId=current_version,
    )
    logger.info(
        f"FinishSecret: Successfully set AWSCURRENT stage to version {request_token} for secret {arn}"
    )
