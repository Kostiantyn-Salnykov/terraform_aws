variable "POSTGRES_DB" {
  description = "Database name for PostgreSQL."
  type        = string
}

variable "POSTGRES_USERNAME" {
  description = "Username for PostgreSQL."
  type        = string
}

variable "POSTGRES_PASSWORD" {
  description = "Password for PostgreSQL."
  type        = string
}

variable "POSTGRES_PORT" {
  description = "Port for PostgreSQL."
  type        = string
  default     = 5432
}

variable "POSTGRES_ENGINE_VERSION" {
  description = "Version for PostgreSQL engine."
  type        = string
  default     = "15.3"
}

variable "vpc_id" {
  description = "ID for VPC to link RDS with."
  type        = string
}

variable "name_prefix" {
  description = "Project with environment name."
  type        = string
}

variable "tags" {
  description = "Tags to set for the Subnet group."
  type        = map(string)
  default     = {}
}

resource "aws_db_instance" "postgresql" {
  identifier                 = lower(var.name_prefix)
  allocated_storage          = 20
  engine                     = "postgres"
  engine_version             = var.POSTGRES_ENGINE_VERSION
  instance_class             = "db.t4g.micro"
  db_name                    = var.POSTGRES_DB
  username                   = var.POSTGRES_USERNAME
  password                   = var.POSTGRES_PASSWORD
  storage_encrypted          = false
  publicly_accessible        = true
  apply_immediately          = true
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  vpc_security_group_ids = [
    aws_security_group.MyPostgreSQLSG.id
  ]
  db_subnet_group_name = aws_db_subnet_group.MyRDSSubnetGroup.name

  lifecycle {
    prevent_destroy = false # Don't use for real DB
  }
}

resource "aws_security_group" "MyPostgreSQLSG" {
  name        = "PostgreSQL SG"
  description = "Allow TLS traffic through the ${var.POSTGRES_PORT} port."
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow TCP ${var.POSTGRES_PORT}"
    from_port        = var.POSTGRES_PORT
    to_port          = var.POSTGRES_PORT
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_db_subnet_group" "MyRDSSubnetGroup" {
  name       = "my_rds_subnet_group"
  subnet_ids = tolist(data.aws_subnets.MyVPCSubnets.ids)

  tags = merge(var.tags, tomap({ "Name" : "my_rds_subnet_group" }))
}

data "aws_subnets" "MyVPCSubnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
