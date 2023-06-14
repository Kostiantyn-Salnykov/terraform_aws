# ==Variables==
variable "tags" {
  description = "Tags to set for the VPC."
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "Subnet availability zones."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "List of availability zones should be more than 2."
  }
}
# =====

# ==Resources==
# Creates VPC (mark it as default)
resource "aws_default_vpc" "MyDefaultVPC" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, tomap({ "Name" : "Default" }))
  force_destroy        = true # Allow terraform to destroy this VPC
}

resource "aws_default_subnet" "MyDefaultSubnet" {
  availability_zone = var.availability_zones[count.index]
  tags              = merge(var.tags, tomap({ "Name" : "Default - ${count.index}" }))
  force_destroy     = true

  count      = 3
  depends_on = [aws_default_vpc.MyDefaultVPC]
}

resource "aws_default_security_group" "MyDefaultSG" {
  vpc_id = aws_default_vpc.MyDefaultVPC.id
  tags   = merge(var.tags, tomap({ "Name" : "Default" }))
}

resource "aws_default_route_table" "MyDefaultRouteTable" {
  default_route_table_id = aws_default_vpc.MyDefaultVPC.default_route_table_id
  tags                   = merge(var.tags, tomap({ "Name" : "Default" }))
}

resource "aws_default_network_acl" "MyDefaultNetworkACL" {
  default_network_acl_id = aws_default_vpc.MyDefaultVPC.default_network_acl_id
  tags                   = merge(var.tags, tomap({ "Name" : "Default" }))
}
# =====

# ==Outputs==
output "id" {
  description = "VPC id"
  value       = aws_default_vpc.MyDefaultVPC.id
}

output "arn" {
  description = "VPC arn"
  value       = aws_default_vpc.MyDefaultVPC.arn
}

output "tags" {
  description = "VPC tags"
  value       = aws_default_vpc.MyDefaultVPC.tags
}
# =====
