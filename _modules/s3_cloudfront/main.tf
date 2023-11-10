variable "domain_name" {
  description = "Base name of domain"
  type        = string
  default     = "ksalnykov.com"
}

variable "name_prefix" {
  description = "Project with environment name."
  type        = string
}

variable "env" {
  description = "Name for environment."
  type        = string
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

variable "content_types" {
  description = "Map of file extensions to content types"
  type        = map(string)
  default = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "jpg"  = "image/jpeg"
    "png"  = "image/png"
    "svg"  = "image/svg+xml"
  }
}

locals {
  bucket_path       = "${path.module}/bucket/"
  domain            = "${var.env}-s3.${var.domain_name}"
  name_prefix_lower = lower(var.name_prefix)
}

resource "aws_s3_bucket" "MyBucket" {
  bucket = "${local.name_prefix_lower}-bucket"
}

resource "aws_s3_bucket_website_configuration" "MyBucketWebSite" {
  bucket = aws_s3_bucket.MyBucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }


}

resource "aws_s3_object" "MySite" {
  for_each = fileset(local.bucket_path, "**/**") # Grab all files and files in subdirectories.

  bucket       = aws_s3_bucket.MyBucket.id
  key          = each.value
  source       = "${local.bucket_path}${each.value}"
  etag         = filemd5("${local.bucket_path}${each.value}")
  content_type = lookup(var.content_types, split(".", each.value)[1], "application/octet-stream")
}

resource "aws_cloudfront_distribution" "MyS3Distribution" {
  retain_on_delete    = true  # Don't delete distribution, just deactivate it (needs to delete it manually)
  wait_for_deployment = false # Skip waiting for deployment

  origin {
    domain_name = aws_s3_bucket.MyBucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.MyBucket.id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.MyCloudFrontOAI.cloudfront_access_identity_path
    }
  }

  aliases             = [local.domain]
  comment             = "MyS3 Distribution"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.MyBucket.id
    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = 3600
    min_ttl                = 60
    max_ttl                = 3600 * 12
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      headers      = ["Content-Type"]
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.MyCertificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "my_domain" {
  zone_id = data.aws_route53_zone.MyRoute53Zone.zone_id
  name    = local.domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.MyS3Distribution.domain_name
    zone_id                = aws_cloudfront_distribution.MyS3Distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_origin_access_identity" "MyCloudFrontOAI" {
  comment = "CloudFront OAI for private S3 bucket."
}

resource "aws_s3_bucket_policy" "my_bucket_policy" {
  bucket = aws_s3_bucket.MyBucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : aws_cloudfront_origin_access_identity.MyCloudFrontOAI.iam_arn
        },
        "Action" : "s3:GetObject",
        "Resource" : "${aws_s3_bucket.MyBucket.arn}/*"
      }
    ]
  })
}

data "aws_acm_certificate" "MyCertificate" {
  domain = "*.${var.domain_name}"
  types  = ["AMAZON_ISSUED"]

  provider = aws.east
}

data "aws_route53_zone" "MyRoute53Zone" {
  name = var.domain_name
}
