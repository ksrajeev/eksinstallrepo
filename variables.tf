# AWS Region
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
}

# VPC Configuration
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "my-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use"
  type        = number
  default     = 3
}

# Subnet Configuration
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

variable "create_database_subnet_group" {
  description = "Whether to create a database subnet group"
  type        = bool
  default     = true
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Create one NAT Gateway per Availability Zone"
  type        = bool
  default     = true
}

# VPC Flow Logs
variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

# Security Group Configuration
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change this to your IP range for better security
}

# VPC Endpoints
variable "create_s3_endpoint" {
  description = "Create S3 VPC endpoint"
  type        = bool
  default     = false
}

variable "create_ec2_endpoint" {
  description = "Create EC2 VPC endpoint"
  type        = bool
  default     = false
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "terraform-vpc"
    ManagedBy   = "terraform"
    Owner       = "devops-team"
  }
}