terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 3.19.0"
      configuration_aliases = [
        aws.current,
        aws.dns
      ]
    }
  }
}