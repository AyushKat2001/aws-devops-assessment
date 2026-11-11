output "cloudfront_url" {
  value = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.site[0].domain_name}" : "CloudFront disabled"
}

output "cloudfront_distribution_id" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.site[0].id : "CloudFront disabled"
}

output "bucket_url" {
  value = "https://${aws_s3_bucket.site.bucket_regional_domain_name}"
}

output "alb_url" {
  value = "http://${aws_lb.web.dns_name}"
}

output "target_group_arn" {
  value = aws_lb_target_group.web.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "github_role_arn" {
  value = aws_iam_role.github.arn
}
