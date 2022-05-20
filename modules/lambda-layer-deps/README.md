# lambda-layer-deps

This terraform module allows you to package all of your project's dependencies into a lambda layer, leaving your lambda nice and lean (just your application code).
Currently it supports the following dependency managers:

* poetry (python)
* npm (nodejs)
* yarn (nodejs)

However, in general we can expand this module to support any dependency manager that generates a dependency lock file [gradle (java), bundler (ruby)].

Examples are located in the examples/ directory

## Requirements

python3

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_external"></a> [external](#provider\_external) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_lambda_layer_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [external_data_source.build](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_compatible_architectures"></a> [compatible\_architectures](#input\_compatible\_architectures) | (Optional) List of Architectures this layer is compatible with. Currently x86\_64 and arm64 can be specified. | `list(string)` | `null` | no |
| <a name="input_dependency_lock_file_path"></a> [dependency\_lock\_file\_path](#input\_dependency\_lock\_file\_path) | (Required) The relative path to the package manager lock file:<br>poetry: poetry.lock<br>yarn:   yarn.lock<br>npm:    package-lock.json | `string` | n/a | yes |
| <a name="input_dependency_manager"></a> [dependency\_manager](#input\_dependency\_manager) | (Required) Package manager to build dependencies (poetry, npm, or yarn) | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | (Optional) Description of what your Lambda Layer does. | `string` | `""` | no |
| <a name="input_layer_name"></a> [layer\_name](#input\_layer\_name) | (Required) Unique name for your Lambda Layer | `string` | n/a | yes |
| <a name="input_license_info"></a> [license\_info](#input\_license\_info) | (Optional) License info for your Lambda Layer. See License Info. | `string` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | (Required) Lambda layer runtime. | `string` | `"python3.8"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | n/a |
