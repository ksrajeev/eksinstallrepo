# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Using public terraform-aws-modules/vpc/aws
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # VPC Configuration
  name = var.vpc_name
  cidr = var.vpc_cidr

  # Availability Zones
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Subnets
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # Database subnets (optional)
  database_subnets = var.database_subnet_cidrs
  create_database_subnet_group = var.create_database_subnet_group

  # Internet Gateway
  create_igw = true

  # NAT Gateway
  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway
  single_nat_gateway = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Flow Logs (optional)
  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_vpc_flow_logs

  # Tags
  tags = var.common_tags

  # VPC tags
  vpc_tags = {
    Name = var.vpc_name
  }

  # Public subnet tags
  public_subnet_tags = {
    Type = "Public"
    "kubernetes.io/role/elb" = "1"
  }

  # Private subnet tags
  private_subnet_tags = {
    Type = "Private"
    "kubernetes.io/role/internal-elb" = "1"
  }

  # Database subnet tags
  database_subnet_tags = {
    Type = "Database"
  }

  # Internet Gateway tags
  igw_tags = {
    Name = "${var.vpc_name}-igw"
  }

  # NAT Gateway tags
  nat_gateway_tags = {
    Name = "${var.vpc_name}-nat"
  }

  # NAT EIP tags
  nat_eip_tags = {
    Name = "${var.vpc_name}-nat-eip"
  }
}

# Security Groups
# Default security group for the VPC
resource "aws_security_group" "default" {
  name        = "${var.vpc_name}-default-security-group"
  description = "Default security group for ${var.vpc_name} VPC with basic access rules"
  vpc_id      = module.vpc.vpc_id

  # Ingress rules
  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rules
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-default-security-group"
    Purpose = "Default VPC Security Group"
    Tier = "Infrastructure"
    SecurityLevel = "Medium"
    CreatedBy = "Terraform"
    Component = "Networking"
  })
}

# Web tier security group
resource "aws_security_group" "web" {
  name        = "${var.vpc_name}-web-tier-security-group"
  description = "Security group for web tier with HTTP/HTTPS access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-web-tier-security-group"
    Purpose = "Web Tier Security"
    Tier = "Web"
    SecurityLevel = "High"
    AllowsInternet = "true"
    Component = "Frontend"
    Layer = "Presentation"
  })
}

# Application tier security group
resource "aws_security_group" "app" {
  name        = "${var.vpc_name}-application-tier-security-group"
  description = "Security group for application tier with restricted access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "App port from web tier"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-application-tier-security-group"
    Purpose = "Application Tier Security"
    Tier = "Application"
    SecurityLevel = "High"
    AllowsInternet = "false"
    Component = "Backend"
    Layer = "Business Logic"
  })
}

# Database tier security group
resource "aws_security_group" "db" {
  name        = "${var.vpc_name}-database-tier-security-group"
  description = "Security group for database tier with strict access controls"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "MySQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-database-tier-security-group"
    Purpose = "Database Security"
    Tier = "Database"
    SecurityLevel = "Critical"
    AllowsInternet = "false"
    Component = "Database"
    Layer = "Data Persistence"
    DataClassification = "Sensitive"
  })
}

# Bastion host security group
resource "aws_security_group" "bastion" {
  name        = "${var.vpc_name}-bastion-host-security-group"
  description = "Security group for bastion host with SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-bastion-host-security-group"
    Purpose = "SSH Jump Host Access"
    Tier = "Management"
    SecurityLevel = "High"
    AllowsInternet = "true"
    Component = "Access Control"
    Role = "Jump Host"
    AccessType = "SSH"
  })
}

# VPC Endpoints (optional)
resource "aws_vpc_endpoint" "s3" {
  count = var.create_s3_endpoint ? 1 : 0
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-s3-vpc-endpoint"
    Purpose = "S3 Gateway Endpoint"
    ServiceType = "S3"
    EndpointType = "Gateway"
    CostOptimization = "true"
    Component = "Storage Access"
    NetworkOptimization = "true"
  })
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.create_ec2_endpoint ? 1 : 0
  
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-ec2-vpc-endpoint"
    Purpose = "EC2 Interface Endpoint"
    ServiceType = "EC2"
    EndpointType = "Interface"
    CostOptimization = "true"
    Component = "Compute Access"
    NetworkOptimization = "true"
  })
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.create_ec2_endpoint ? 1 : 0
  
  name        = "${var.vpc_name}-vpc-endpoints-security-group"
  description = "Security group for VPC endpoints with HTTPS access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-vpc-endpoints-security-group"
    Purpose = "VPC Endpoints Security"
    Tier = "Infrastructure"
    SecurityLevel = "Medium"
    Component = "VPC Endpoints"
    AccessType = "HTTPS"
    NetworkOptimization = "true"
  })
}