module "bucket" {
  source        = "ptonini/s3-bucket/aws"
  version       = "~> 2.1.0"
  count         = var.bucket == null ? 0 : 1
  name          = var.bucket.name
  create_policy = var.bucket.create_policy
  force_destroy = var.bucket.force_destroy
}

module "certificate" {
  source                    = "ptonini/acm-certificate/aws"
  version                   = "~> 2.0.0"
  count                     = var.route53_zone == null ? 0 : 1
  domain_name               = one(var.aliases)
  subject_alternative_names = [for i, a in var.aliases : a if i != 0]
  route53_zone              = var.route53_zone
}

resource "aws_cloudfront_distribution" "this" {
  aliases             = var.aliases
  enabled             = var.cloudfront_enabled
  default_root_object = var.default_root_object
  is_ipv6_enabled     = var.is_ipv6_enabled

  dynamic "origin" {
    for_each = var.origins
    content {
      origin_path = origin.value.path
      domain_name = coalesce(origin.value.domain_name, module.bucket[0].this.bucket_domain_name)
      origin_id   = coalesce(origin.value.origin_id, "s3-${module.bucket[0].this.bucket}")
    }
  }

  custom_error_response {
    error_caching_min_ttl = var.custom_error_response.error_caching_min_ttl
    error_code            = var.custom_error_response.error_code
    response_code         = var.custom_error_response.response_code
    response_page_path    = coalesce(var.custom_error_response.response_page_path, "/${var.default_root_object}")
  }

  dynamic "logging_config" {
    for_each = var.logging_config == null ? [] : [0]
    content {
      include_cookies = var.logging_config.include_cookies
      bucket          = coalesce(var.logging_config.bucket, module.bucket[0].this.bucket_domain_name)
      prefix          = var.logging_config.prefix
    }
  }

  default_cache_behavior {
    allowed_methods        = var.default_cache_behavior.allowed_methods
    cached_methods         = var.default_cache_behavior.cached_methods
    default_ttl            = var.default_cache_behavior.default_ttl
    max_ttl                = var.default_cache_behavior.max_ttl
    min_ttl                = var.default_cache_behavior.min_ttl
    target_origin_id       = coalesce(var.default_cache_behavior.target_origin_id, "s3-${module.bucket[0].this.bucket}")
    viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy
    compress               = var.default_cache_behavior.compress

    forwarded_values {
      headers                 = var.default_cache_behavior.forwarded_values.headers
      query_string            = var.default_cache_behavior.forwarded_values.query_string
      query_string_cache_keys = var.default_cache_behavior.forwarded_values.query_string_cache_keys

      cookies {
        forward           = var.default_cache_behavior.forwarded_values.cookies.forward
        whitelisted_names = var.default_cache_behavior.forwarded_values.cookies.whitelisted_names
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.viewer_certificate.cloudfront_default_certificate
    acm_certificate_arn            = coalesce(var.viewer_certificate.acm_certificate_arn, module.certificate[0].this.arn)
    minimum_protocol_version       = var.viewer_certificate.minimum_protocol_version
    ssl_support_method             = var.viewer_certificate.ssl_support_method
  }

  restrictions {

    dynamic "geo_restriction" {
      for_each = var.geo_restriction == null ? [] : [0]
      content {
        locations        = var.geo_restriction.locations
        restriction_type = var.geo_restriction.type
      }
    }
  }
}

module "policy" {
  source  = "ptonini/iam-policy/aws"
  version = "~> 2.0.0"
  name    = "cloudfront-policy-${aws_cloudfront_distribution.this.id}"
  statement = concat(one(module.bucket[*].policy_statement), [
    {
      Effect   = "Allow"
      Action   = ["cloudfront:ListDistributions"]
      Resource = ["*"]
    },
    {
      Effect   = "Allow"
      Action   = ["cloudfront:CreateInvalidation"]
      Resource = [aws_cloudfront_distribution.this.arn]
    }
  ])
}

module "dns_record" {
  source       = "ptonini/route53-record/aws"
  version      = "~> 1.0.0"
  for_each     = var.cloudfront_enabled && var.route53_zone != null ? toset(var.aliases) : []
  name         = each.key
  route53_zone = var.route53_zone
  type         = "CNAME"
  records = [
    aws_cloudfront_distribution.this.domain_name
  ]
}




