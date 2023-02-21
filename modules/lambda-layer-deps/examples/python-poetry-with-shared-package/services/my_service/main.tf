provider "aws" {
  profile = "zamboni-development"
  region  = "us-west-1"
}

module "layer" {
  source                    = "../../../../../../"
  layer_name                = "python-poetry-with-shared-package"
  dependency_lock_file_path = "${path.module}/poetry.lock"
  dependency_manager        = "poetry"
}

module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "python-poetry-with-shared-package"
  description   = "Python poetry with shared package example"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  source_path   = "./src/"
  layers        = [module.layer.arn]
}