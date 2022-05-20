# Deploying with Github Actions

The deployment flow for Github Actions is such that when a Pull Request is created/changed an action will generate a Terraform plan and attach it as a comment to the Pull Request. In order to ensure the consistency of the plan, branch protections should be added to the master branch such that a pull request can only be merged against the latest master commit 

These settings are (at least):

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

Once these settings are applied to your repo. Add a workflow file to your code.
This example shows how to automatically add plan comments to your pull requests.
This uses a standard Github action for generating a terraform plan. The documentation for this action is available [here](https://github.com/RSS-Engineering/terraform/blob/main/gh_actions/attach_plan_to_pr/README.md)

```yaml
name: Validate Pull Request

on:
  pull_request:
  paths-ignore:
    - 'docs/**'
    - 'README.md'

jobs:
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
          AWS_DEFAULT_REGION: "us-west-2"
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
