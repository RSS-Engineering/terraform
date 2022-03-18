provider "aws" {
  profile = "zamboni-development"
  region  = "us-west-1"
}

module "layer" {
  source                    = "../../"
  layer_name                = "basic-nodejs-npm"
  dependency_lock_file_path = "${path.module}/package-lock.json"
  dependency_manager        = "npm"
}

module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "basic-nodejs-npm"
  description   = "Basic nodejs npm example"
  handler       = "index.lambda_handler"
  runtime       = "nodejs12.x"
  source_path   = "./src/"
  layers        = [module.layer.arn]
}