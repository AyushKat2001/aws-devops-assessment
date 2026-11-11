# ---------- Task 2: CloudFront in front of a PRIVATE S3 static site ----------

locals {
  bucket_name = "static-site-${data.aws_caller_identity.current.account_id}-${var.region}"
  site_dir    = "${path.module}/../site"
  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    svg  = "image/svg+xml"
  }
}

resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = true
}

# Restrict direct S3 access: block ALL public access
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "site" {
  for_each     = fileset(local.site_dir, "**")
  bucket       = aws_s3_bucket.site.id
  key          = each.value
  source       = "${local.site_dir}/${each.value}"
  etag         = filemd5("${local.site_dir}/${each.value}")
  content_type = lookup(local.mime_types, regex("[^.]+$", each.value), "application/octet-stream")
}

# Origin Access Control: CloudFront signs its requests to S3
resource "aws_cloudfront_origin_access_control" "site" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "oac-${local.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "optimized" {
  count = var.enable_cloudfront ? 1 : 0

  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "site" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  comment             = "S3 static site behind CloudFront"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-private-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.site[0].id
  }

  default_cache_behavior {
    target_origin_id       = "s3-private-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized[0].id
  }

  # Private bucket returns 403 for missing keys; show a friendly 404 instead
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Only THIS distribution may read objects from the bucket
data "aws_iam_policy_document" "site_bucket" {
  count = var.enable_cloudfront ? 1 : 0

  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  count = var.enable_cloudfront ? 1 : 0

  bucket     = aws_s3_bucket.site.id
  policy     = data.aws_iam_policy_document.site_bucket[0].json
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# Cache invalidation: runs whenever any file in site/ changes
resource "terraform_data" "invalidate_cache" {
  count = var.enable_cloudfront ? 1 : 0

  triggers_replace = [sha1(join("", [for o in aws_s3_object.site : o.etag]))]

  provisioner "local-exec" {
    command = <<-EOT
      ID=$(aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.site[0].id} --paths "/*" --query Invalidation.Id --output text)
      aws cloudfront wait invalidation-completed --distribution-id ${aws_cloudfront_distribution.site[0].id} --id "$ID"
      echo "Invalidation $ID completed"
    EOT
  }

  depends_on = [aws_s3_bucket_policy.site]
}
