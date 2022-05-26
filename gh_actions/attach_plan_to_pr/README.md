# Terraform Plan action

This action creates a Terraform plan from the current repository. It will output text and can also post a message to a pull request and save the text and data plan files as artifacts.

## Inputs

### terraform_version

**Required** The terraform version to use.

### root
    
**Required** The root directory of the terraform repo (Passed to -chdir)

### validate_format

Validate the *.tf files format. (default: `true`)

### cache_providers

Should the action try to cache Terraform providers (default: `true`)

### add_plan_to_pr

For Pull Request events, add a plan comment to the current PR (default: `true`)

### text_artifact_name

Save the plan text as an artifact with the provided name.

### plan_artifact_name

Save the plan as an artifact with the provided name

### ignore_plan_phrase

If the terraform plan contains this phrase, then do not add a plan comment to the Pull Request (default: `'No changes. Your infrastructure matches the configuration.'`)

## Outputs

### text

The terraform plan in human-readable output

## Example usage

```yaml
      - name: Build Terraform Plan
        uses: RSS-Engineering/terraform/gh_actions/attach_plan_to_pr@v1.1.1
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
```

