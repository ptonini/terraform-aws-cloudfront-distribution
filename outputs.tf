output "this" {
  value = aws_cloudfront_distribution.this
}

output "bucket" {
  value = module.bucket.this
}

output "bucket_policy_arn" {
  value = module.bucket.policy_arn
}

output "role_arn" {
  value = try(module.role[0].this.arn, null)
}