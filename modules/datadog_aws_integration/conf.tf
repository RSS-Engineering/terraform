terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "3.18.0"
    }
  }
}
