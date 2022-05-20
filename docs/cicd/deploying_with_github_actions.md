# Deploying with Github Actions

The deployment flow for Github Actions is such that when a Pull Request is created/changed an action will generate a Terraform plan and attach it as a comment to the Pull Request. In order to ensure the consistency of the plan, branch protections should be added to the master branch such that a pull request can only be merged against the latest master commit 

```yaml
name: Validate Pull Request

on:
  pull_request:

jobs:
  check-backend:
  terraform:
    name: "Build Terraform Plan"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2

      - name: Build Terraform Plan
        uses: RSS-Engineering/terraform/gh_actions/attach_plan_to_pr@v1
        id: plan
        env:
          ENV: prod
          AWS_REGION: "us-west-2"
          AWS_ACCESS_KEY_ID: ${{ secrets.PROD_AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}
        with:
          terraform_version: 1.0.1
          root: infrastructure/environments/prod
          text_artifact_name: tf-plan-${{ github.event.after }}.txt
          plan_artifact_name: tf-plan-${{ github.event.after }}

      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
```
