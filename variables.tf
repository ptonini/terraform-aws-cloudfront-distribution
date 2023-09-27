variable "name" {}

variable "bucket" {}

variable "domain" {}

variable "alternative_domain_names" {
  type    = list(string)
  default = []
}

variable "route53_zone" {}

variable "default_root_object" {
  default = "index.html"
}

variable "error_response_page_path" {
  default = null
}

variable "origin_paths" {
  default = ["/www"]
  type    = list(string)
}

variable "logging_config_prefix" {
  default = "access_logs"
}

variable "cloudfront_enabled" {
  default = true
}

variable "geo_restriction" {
  type = object({
    locations = list(string)
    type      = string
  })
  default = {
    locations = []
    type      = "none"
  }
}

variable "force_destroy_bucket" {
  default = false
}