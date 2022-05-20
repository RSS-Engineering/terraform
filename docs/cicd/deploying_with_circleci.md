# Deploying with CircleCI

Deploying with CircleCI involves 2 workflows.

## PR Testing and Static Analysis

The first will handle all of the automated validation required to merge a pull request.

```mermaid
graph TB
    code[PR Created] --> sa[Static Analysis]
    code --> ut[Unit Tests]
    sa --Succeeds--> testdeployapproval[CircleCI pauses for approval to deploy to test environment]
    ut --Pass--> testdeployapproval
    testdeployapproval --> testdeploy[CircleCI deploys to test environment]
    testdeploy --Success--> acceptance[CircleCI runs acceptance tests]
    acceptance --Succeeds--> gmu[PR Merge Unlocked]
```

## Deployment to production

The second will handle deploying to production.

```mermaid
graph TB
    prm[PR merged to master branch] --> tfplan[CircleCI generates a Terraform plan]
    tfplan --> pause[CircleCI pauses for Plan Approval]
    pause --Approved--> apply[CircleCI applies approved Plan]
```

## More details

At this time, CircleCI should be reserved for large or complicated projects with special cases due to budget reasons.
