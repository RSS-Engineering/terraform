# Deploying with CI/CD

It is important to consider these CI/CD best practices and how using Terraform interacts with them.

1. All changes should be reviewed and approved prior to deployment.
2. The *master* branch should be strongly tied to what is deployed to production.

We have well-established patterns for code changes to be reviewed/approved via the pull request process.
However, a *terraform plan* exists in a gray area between code and state. It is possible for the plan to
need to change even if the code that drives it does not (for example if another branch is deployed between
the time a plan is created and when it is to be applied).

## Recommended Terraform State Approval Pattern

The recommended way for terraform plans to be approved is to attach them to the pull request so that
everything is considered at the same time. You will likely need to use branch protection rules in
order to ensure that the plan attached accurately reflects the state of the infrastructure.

This method is geared toward [Github Actions](cicd/deploying_with_github_actions.md). If you need a more
complicated deployment workflow or there are many competing feature branches in your project, you should
consider [CircleCI](cicd/deploying_with_circleci.md).

NOTE: [CircleCI](cicd/deploying_with_circleci.md) is the technically superior option but is quite a bit more expensive than [Github Actions](cicd/deploying_with_github_actions.md).
New projects should start using [Github Actions](cicd/deploying_with_github_actions.md) and only consider [CircleCI](cicd/deploying_with_circleci.md) if [Github Actions](cicd/deploying_with_github_actions.md) is not able
to provide the needed consistency.
