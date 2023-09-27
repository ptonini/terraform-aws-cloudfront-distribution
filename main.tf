module "bucket" {
  source        = "ptonini/s3-bucket/aws"
  version       = "~> 2.0.0"
  name          = var.bucket
  create_policy = true
  force_destroy = var.force_destroy_bucket
  providers = {
    aws = aws.current
  }
}

module "certificate" {
  source                    = "ptonini/acm-certificate/aws"
  version                   = "~> 1.0.0"
  domain_name               = var.domain
  subject_alternative_names = var.alternative_domain_names
  route53_zone              = var.route53_zone
  providers = {
    aws.current = aws.current
    aws.dns     = aws.dns
  }
}

resource "aws_cloudfront_distribution" "this" {
  provider            = aws.current
  enabled             = var.cloudfront_enabled
  default_root_object = var.default_root_object
  is_ipv6_enabled     = true
  aliases             = concat([var.domain], var.alternative_domain_names)
  custom_error_response {
    error_caching_min_ttl = 60
    error_code            = 403
    response_code         = 200
    response_page_path    = coalesce(var.error_response_page_path, "/${var.default_root_object}")
  }
  logging_config {
    include_cookies = false
    bucket          = module.bucket.this.bucket_domain_name
    prefix          = var.logging_config_prefix
  }
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
    target_origin_id       = "s3-${module.bucket.this.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      headers                 = []
      query_string            = false
      query_string_cache_keys = []
      cookies {
        forward           = "none"
        whitelisted_names = []
      }
    }
  }
  dynamic "origin" {
    for_each = toset(var.origin_paths)
    content {
      origin_path = origin.value
      domain_name = module.bucket.this.bucket_domain_name
      origin_id   = "s3-${module.bucket.this.bucket}"

    }
  }
  restrictions {
    geo_restriction {
      locations        = var.geo_restriction.locations
      restriction_type = var.geo_restriction.type
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = module.certificate.this.arn
    minimum_protocol_version       = "TLSv1.2_2019"
    ssl_support_method             = "sni-only"
  }
}

module "policy" {
  source  = "ptonini/iam-policy/aws"
  version = "~> 1.0.0"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(module.bucket.access_policy_statements, [
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
  })
  providers = {
    aws = aws.current
  }
}

module "dns_record" {
  source       = "ptonini/route53-record/aws"
  version      = "~> 1.0.0"
  for_each     = toset(var.cloudfront_enabled ? concat([var.domain], var.alternative_domain_names) : [])
  name         = each.key
  route53_zone = var.route53_zone
  type         = "CNAME"
  records = [
    aws_cloudfront_distribution.this.domain_name
  ]
  providers = {
    aws = aws.dns
  }
}

