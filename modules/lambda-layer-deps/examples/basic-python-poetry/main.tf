provider "aws" {
  region  = "us-west-1"
}

module "layer" {
  source                    = "../../"
  layer_name                = "basic-python-poetry"
  dependency_lock_file_path = "${path.module}/poetry.lock"
  dependency_manager        = "poetry"
}

module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "basic-python-poetry"
  description   = "Basic python poetry example"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  source_path   = "./src/"
  layers        = [module.layer.arn]
}