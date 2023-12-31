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

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}
# =====

# ==Locals==
locals {
  any_protocol = "-1"
  any_ipv4     = "0.0.0.0/0"
  any_vpv6     = "::/0"
  any_port     = 0
  http_port    = 80
  https_port   = 443
}
# =====


# ==Resources==
resource "aws_vpc" "MyVPC" {
  cidr_block           = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, tomap({ "Name" : "Custom VPC" }))

}


resource "aws_vpc_ipam" "MyVPCIPAM" {
  operating_regions {
    region_name = var.aws_region
  }
}

resource "aws_vpc_ipam_pool" "MyVPCIPAMPool" {
  address_family = "ipv6"
  ipam_scope_id  = aws_vpc_ipam.MyVPCIPAM.public_default_scope_id
  locale = var.aws_region

}



resource "aws_internet_gateway" "MyIG" {
  vpc_id = aws_vpc.MyVPC.id
  tags   = merge(var.tags, tomap({ "Name" : "Custom IG" }))
}

resource "aws_default_route_table" "MyDefaultRouteTable" {
  default_route_table_id = aws_vpc.MyVPC.default_route_table_id
  tags                   = merge(var.tags, tomap({ "Name" : "Custom RT" }))
}

resource "aws_route" "MyRouteTableWithIG" {
  route_table_id         = aws_default_route_table.MyDefaultRouteTable.id
  destination_cidr_block = local.any_ipv4 # Open
  gateway_id             = aws_internet_gateway.MyIG.id
}

resource "aws_route_table_association" "MyRouteTableAssociation" {
  route_table_id = aws_default_route_table.MyDefaultRouteTable.id
  subnet_id      = element(aws_subnet.MyPublicSubnet.*.id, count.index)

  count = length(var.availability_zones)
}

resource "aws_subnet" "MyPublicSubnet" {
  vpc_id                  = aws_vpc.MyVPC.id
  cidr_block = cidrsubnet(aws_vpc.MyVPC.cidr_block, 4, count.index + 1)
  ipv6_cidr_block = cidrsubnet(aws_vpc.MyVPC.ipv6_cidr_block, 8, count.index + 1)
  availability_zone       = var.availability_zones[count.index]
  tags                    = merge(var.tags, tomap({ "Name" : "Custom - ${count.index}" }))

  count      = length(var.availability_zones)
  depends_on = [aws_vpc.MyVPC]
}

resource "aws_security_group" "MySG" {
  name        = "MySG"
  description = "Security Group for ALB"
  vpc_id      = aws_vpc.MyVPC.id
  tags        = merge(var.tags, tomap({ "Name" : "Custom SG" }))

  ingress {
    description      = "Allow TCP ${local.http_port}"
    protocol         = "tcp"
    from_port        = local.http_port
    to_port          = local.http_port
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_vpv6]
  }

  ingress {
    description      = "Allow TCP ${local.https_port}"
    protocol         = "tcp"
    from_port        = local.https_port
    to_port          = local.https_port
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_vpv6]
  }

  egress {
    protocol         = local.any_protocol
    from_port        = local.any_port
    to_port          = local.any_port
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_vpv6]
  }
}
# =====

# ==Outputs==
output "id" {
  value = aws_vpc.MyVPC.id
}
output "arn" {
  value = aws_vpc.MyVPC.arn
}
# =====
