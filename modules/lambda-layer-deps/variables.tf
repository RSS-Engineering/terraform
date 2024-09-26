variable "layer_name" {
  description = "(Required) Unique name for your Lambda Layer"
  type        = string
}

variable "dependency_lock_file_path" {
  description = <<EOT
(Required) The relative path to the package manager lock file:
poetry: poetry.lock
yarn:   yarn.lock
npm:    package-lock.json
EOT
  type        = string
}

variable "runtime" {
  description = "(Required) Lambda layer runtime."
  default     = "python3.8"
  type        = string
}

variable "dependency_manager" {
  description = "(Required) Package manager to build dependencies (poetry, npm, or yarn)"
  type        = string
  validation {
    condition = contains(
      ["poetry", "npm", "yarn"],
      var.dependency_manager
    )
    error_message = "Error: invalid package manager."
  }
}

variable "description" {
  description = "(Optional) Description of what your Lambda Layer does."
  default     = ""
  type        = string
}

variable "compatible_architectures" {
  description = "(Optional) List of Architectures this layer is compatible with. Currently x86_64 and arm64 can be specified."
  type        = list(string)
  default     = null
}

variable "license_info" {
  description = "(Optional) License info for your Lambda Layer. See License Info."
  type        = string
  default     = null
}

variable "pre_package_commands" {
  description = "Command to run on docker image before packaging step"
  type        = list(string)
  default     = []
}

variable "docker_image" {
  description = "Docker image to be passed for running the image with dependencies"
  type        = string
  default     = null
}