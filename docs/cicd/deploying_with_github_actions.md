# Deploying with Github Actions

The deployment flow for Github Actions is such that when a Pull Request is created/changed an action will generate a Terraform plan and attach it as a comment to the Pull Request. In order to ensure the consistency of the plan, branch protections should be added to the master branch such that a pull request can only be merged against the latest master commit 

## Github Repository Settings

Apply these settings to your repository and default branch:

- Settings -> Pull Requests
  - Check **Allow merge commits**
  - Uncheck **Allow Squash merging** and **Allow rebase merging**
- Settings -> Branches -> Branch protection Rules -> Edit (for your default branch)
  - Check **Require a pull request before merging**
  - Check **Dismiss stale pull request approvals when new commits are pushed**
  - Uncheck **Allow specified actors to bypass required pull requests**
  - Check **Require status checks to pass before merging**
  - Check **Require branches to be up to date before merging**
  - Add the name of your GH Actions workflow to *Status checks that are required*
  - Check **Include administrators**

## Actions

There several workflows that you can add to properly manage your project.

*NOTE:* These workflows require that credentials be added to your repo to access
your infrastructure. While these examples assume an AWS environment, it is not a
requirement. Any cloud provider that can be configured via environment variables
will be compatible.

### Code Validation and Terraform Planning

This workflow uses a standard action for validating terraform code and generating
a terraform plan. The documentation for this action is available [here](https://github.com/RSS-Engineering/terraform/blob/main/gh_actions/attach_plan_to_pr/README.md).
This is also a good place to add additional static analysis to your project. It
can be manually invoked to apply to any branch or a number of environments.

```yaml
name: Validate Pull Request

on:
  pull_request:
  paths-ignore:
    - 'docs/**'
    - 'README.md'
  workflow_dispatch:
    inputs:
      env:
        description: 'Plan for Environment'
        required: true
        default: 'staging'
        type: choice
        options:
        - prod
        - staging

jobs:
  terraform:
    name: "Build Terraform Plan"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2

      # This step is only necessary to switch between multiple environments.
      - name: Build Credentials
        id: creds
        run: |
          if [ "$ENV" = "staging" ]
          then
              echo "::set-output name=access_key::$STAGING_ACCESS_KEY"
              echo "::set-output name=secret_key::$STAGING_SECRET_KEY"
              echo "::set-output name=env::$ENV"
          else
              echo "::set-output name=access_key::$PROD_ACCESS_KEY"
              echo "::set-output name=secret_key::$PROD_SECRET_KEY"
              echo "::set-output name=env::prod"
          fi
        env:
          ENV: ${{ github.event.inputs.env || 'prod' }}
          PROD_ACCESS_KEY: ${{ secrets.PROD_AWS_ACCESS_KEY_ID }}
          PROD_SECRET_KEY: ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}
          STAGING_ACCESS_KEY: ${{ secrets.STAGING_AWS_ACCESS_KEY_ID }}
          STAGING_SECRET_KEY: ${{ secrets.STAGING_AWS_SECRET_ACCESS_KEY }}

      - name: Build Terraform Plan
        uses: RSS-Engineering/terraform/gh_actions/attach_plan_to_pr@v1.1.3
        id: plan
        env:
          ENV: ${{ steps.creds.outputs.env }}
          AWS_DEFAULT_REGION: "us-west-2"
          AWS_ACCESS_KEY_ID: ${{ steps.creds.outputs.access_key }}
          AWS_SECRET_ACCESS_KEY: ${{ steps.creds.outputs.secret_key }}
        with:
          terraform_version: 1.0.1
          root: infrastructure/environments/${{ steps.creds.outputs.env }}
          text_artifact_name: tf-plan-${{ github.sha }}.txt
          plan_artifact_name: tf-plan-${{ github.sha }}

      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
```

### Deployment

This workflow applies terraform changes to your infrastructure. It is invoked
automatically when a Pull Request is merged to the master branch (change this if
your default branch is named differently). It can also be invoked manually to
deploy to lower environments.

```yaml
name: Deploy

on:
  push:
    branches:
      - master
    paths-ignore:
      - 'docs/**'
      - 'README.md'
  workflow_dispatch:
    inputs:
      env:
        description: 'Deploy to Environment'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        # Uncomment the line below if you want to be able to manually deploy to production (not recommended)
        # - prod

jobs:
  terraform:
    name: "Apply Terraform changes"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.0.1

      - name: Build Credentials
        id: creds
        run: |
          if [ "$ENV" = "staging" ]
          then
              echo "::set-output name=access_key::$STAGING_ACCESS_KEY"
              echo "::set-output name=secret_key::$STAGING_SECRET_KEY"
              echo "::set-output name=env::$ENV"
          else
              echo "::set-output name=access_key::$PROD_ACCESS_KEY"
              echo "::set-output name=secret_key::$PROD_SECRET_KEY"
              echo "::set-output name=env::prod"
          fi
        env:
          # github.event.inputs.env will be empty when invoked via master push thus defaulting to 'prod'
          ENV: ${{ github.event.inputs.env || 'prod' }}
          PROD_ACCESS_KEY: ${{ secrets.PROD_AWS_ACCESS_KEY_ID }}
          PROD_SECRET_KEY: ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}
          STAGING_ACCESS_KEY: ${{ secrets.STAGING_AWS_ACCESS_KEY_ID }}
          STAGING_SECRET_KEY: ${{ secrets.STAGING_AWS_SECRET_ACCESS_KEY }}

      - name: Get Lockfile path
        id: lockfile_path
        run: echo "infrastructure/environments/${{ steps.creds.outputs.env }}/.terraform.lock.hcl"

      - name: Load cached Terraform Providers
        uses: actions/cache@v3
        with:
          path: infrastructure/environments/${{ steps.creds.outputs.env }}/.terraform
          key: tf-providers-${{ hashFiles(steps.lockfile_path.output.stdout) }}

      - name: Initialize Terraform
        env:
          ENV: ${{ steps.creds.outputs.env }}
          AWS_DEFAULT_REGION: "us-west-2"
          AWS_ACCESS_KEY_ID: ${{ steps.creds.outputs.access_key }}
          AWS_SECRET_ACCESS_KEY: ${{ steps.creds.outputs.secret_key }}
        run: terraform -chdir=infrastructure/environments/${{ steps.creds.outputs.env }} init

      - name: Validate Terraform
        env:
          ENV: ${{ steps.creds.outputs.env }}
          AWS_DEFAULT_REGION: "us-west-2"
          AWS_ACCESS_KEY_ID: ${{ steps.creds.outputs.access_key }}
          AWS_SECRET_ACCESS_KEY: ${{ steps.creds.outputs.secret_key }}
        run: |
          terraform fmt -check -recursive -diff infrastructure
          terraform -chdir=infrastructure/environments/${{ steps.creds.outputs.env }} validate

      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

      - name: Terraform Apply
        env:
          ENV: ${{ steps.creds.outputs.env }}
          AWS_DEFAULT_REGION: "us-west-2"
          AWS_ACCESS_KEY_ID: ${{ steps.creds.outputs.access_key }}
          AWS_SECRET_ACCESS_KEY: ${{ steps.creds.outputs.secret_key }}
        run: terraform -chdir=infrastructure/environments/${{ steps.creds.outputs.env }} apply --auto-approve
```
