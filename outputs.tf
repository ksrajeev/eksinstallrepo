# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_main_route_table_id" {
  description = "ID of the main route table associated with this VPC"
  value       = module.vpc.vpc_main_route_table_id
}

# Subnet Outputs
output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "database_subnet_cidrs" {
  description = "CIDR blocks of the database subnets"
  value       = module.vpc.database_subnets_cidr_blocks
}

# Internet Gateway
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "internet_gateway_arn" {
  description = "ARN of the Internet Gateway"
  value       = module.vpc.igw_arn
}

# NAT Gateway
output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "nat_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = module.vpc.nat_public_ips
}

# Route Tables
output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = module.vpc.private_route_table_ids
}

output "public_route_table_ids" {
  description = "IDs of the public route tables"
  value       = module.vpc.public_route_table_ids
}

output "database_route_table_ids" {
  description = "IDs of the database route tables"
  value       = module.vpc.database_route_table_ids
}

# Security Group Outputs
output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_security_group.default.id
}

output "web_security_group_id" {
  description = "ID of the web tier security group"
  value       = aws_security_group.web.id
}

output "app_security_group_id" {
  description = "ID of the application tier security group"
  value       = aws_security_group.app.id
}

output "database_security_group_id" {
  description = "ID of the database tier security group"
  value       = aws_security_group.db.id
}

output "bastion_security_group_id" {
  description = "ID of the bastion host security group"
  value       = aws_security_group.bastion.id
}

# Availability Zones
output "availability_zones" {
  description = "List of availability zones used"
  value       = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# VPC Endpoints
output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = var.create_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "ec2_vpc_endpoint_id" {
  description = "ID of the EC2 VPC endpoint" 
  value       = var.create_ec2_endpoint ? aws_vpc_endpoint.ec2[0].id : null
}