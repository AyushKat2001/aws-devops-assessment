#!/usr/bin/env bash
# CloudFront must work (200); direct S3 access must be denied (403).
set -euo pipefail
cd "$(dirname "$0")/../terraform"
echo "via CloudFront (expect 200):"
curl -s -o /dev/null -w "%{http_code}\n" "$(terraform output -raw cloudfront_url)/"
echo "direct S3 URL (expect 403):"
curl -s -o /dev/null -w "%{http_code}\n" "$(terraform output -raw bucket_url)/index.html"
echo "cache header (2nd request should say Hit from cloudfront):"
curl -sI "$(terraform output -raw cloudfront_url)/" >/dev/null
curl -sI "$(terraform output -raw cloudfront_url)/" | grep -i '^x-cache'
