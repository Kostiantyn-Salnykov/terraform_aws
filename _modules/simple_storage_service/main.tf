variable "bucket_name" {
  description = "Name for the bucket."
  type        = string
  default     = "ksalnykov.com"
}

resource "aws_s3_bucket" "MyBucket" {
  bucket = var.bucket_name
}

output "arn" {
  description = "ARN of the bucket."
  value       = aws_s3_bucket.MyBucket.arn
}

output "region" {
  description = "Region of the bucket."
  value       = aws_s3_bucket.MyBucket.region
}
