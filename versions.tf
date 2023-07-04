terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.45.0"
      configuration_aliases = [
        aws.current,
        aws.dns
      ]
    }
  }
}