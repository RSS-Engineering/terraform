resource aws_lambda_layer_version this {
  layer_name               = var.layer_name
  description              = var.description
  license_info             = var.license_info
  filename                 = data.external.build.result["output_path"]
  compatible_runtimes      = [var.runtime]
  compatible_architectures = var.compatible_architectures
  source_code_hash         = filebase64sha256(data.external.build.result["output_path"])
}

data external build {
  program = ["python3", "${path.module}/package.py"]
  query   = {
    dependency_manager   = var.dependency_manager
    runtime              = var.runtime
    dependency_lock_file = var.dependency_lock_file_path
    pre_package_commands = jsonencode(var.pre_package_commands)
  }
}
