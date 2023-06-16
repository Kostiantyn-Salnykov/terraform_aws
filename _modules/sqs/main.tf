variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "name" {
  description = "Name for the queue."
  type        = string
}

variable "name_suffix" {
  description = "Name for Project and environment together."
}

locals {
  name = "${var.name_suffix}${var.name}"
}

resource "aws_sqs_queue" "MyQueue" {
  name = "${local.name}.fifo"

  # Options
  fifo_queue                  = true
  sqs_managed_sse_enabled     = false
  visibility_timeout_seconds  = 10 # seconds to reads by 1 consumer (message unavailable for other).
  message_retention_seconds   = 60 # TTL to message
  delay_seconds               = 0  # seconds delay before message will be pushed
  content_based_deduplication = true
  deduplication_scope         = "messageGroup" # "messageGroup" | "queue" (default)
}
