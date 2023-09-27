output "this" {
  value = aws_cloudfront_distribution.this
}

output "bucket" {
  value = module.bucket.this.bucket
}

output "policy_arn" {
  value = module.policy.this.arn
}

