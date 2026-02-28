# AWS VPC Terraform Configuration

This repository contains Terraform configuration files to create a comprehensive AWS VPC infrastructure using the popular `terraform-aws-modules/vpc/aws` public module.

## Features

This configuration creates the following AWS resources:

### VPC Components
- **VPC** with customizable CIDR block
- **Public Subnets** across multiple Availability Zones
- **Private Subnets** across multiple Availability Zones  
- **Database Subnets** for RDS instances
- **Internet Gateway** for public internet access
- **NAT Gateways** for private subnet internet access
- **Route Tables** with proper routing configurations

### Security Groups
- **Default Security Group** - Basic VPC-wide rules
- **Web Tier Security Group** - HTTP/HTTPS and SSH access
- **Application Tier Security Group** - App-specific ports with restricted access
- **Database Tier Security Group** - Database ports with app-tier access only
- **Bastion Host Security Group** - SSH jump host access

### Optional Components
- **VPC Flow Logs** for network traffic monitoring
- **VPC Endpoints** for S3 and EC2 services
- **Database Subnet Group** for RDS deployments

## File Structure

```
.
├── main.tf                    # Main Terraform configuration
├── variables.tf              # Variable definitions
├── outputs.tf               # Output definitions
├── terraform.tfvars.example # Example variables file
└── README.md                # This documentation
```

## Prerequisites

1. **Terraform** (>= 1.0)
2. **AWS CLI** configured with appropriate credentials
3. **AWS Account** with necessary permissions

## Usage

### 1. Clone and Setup

```bash
git clone <repository-url>
cd eksinstallrepo
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific requirements:

```bash
# Example customization
aws_region = "us-east-1"
vpc_name = "my-company-vpc"
vpc_cidr = "10.0.0.0/16"
allowed_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and Apply

```bash
# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

### 5. Clean Up

To destroy all resources when no longer needed:

```bash
terraform destroy
```

## Configuration Options

### VPC Settings
- `vpc_name`: Name tag for the VPC
- `vpc_cidr`: CIDR block for the entire VPC
- `az_count`: Number of Availability Zones to use

### Subnet Configuration
- `private_subnet_cidrs`: CIDR blocks for private subnets
- `public_subnet_cidrs`: CIDR blocks for public subnets  
- `database_subnet_cidrs`: CIDR blocks for database subnets

### NAT Gateway Options
- `enable_nat_gateway`: Enable NAT Gateways for private subnets
- `single_nat_gateway`: Use one NAT Gateway for all private subnets (cost-effective)
- `one_nat_gateway_per_az`: Create one NAT Gateway per AZ (high availability)

### Security Configuration
- `allowed_ssh_cidrs`: IP ranges allowed for SSH access

### Optional Features
- `enable_vpc_flow_logs`: Enable VPC Flow Logs
- `create_s3_endpoint`: Create S3 VPC endpoint
- `create_ec2_endpoint`: Create EC2 VPC endpoint

## Architecture

This configuration creates a three-tier architecture:

```
Internet Gateway
        |
    Public Subnets (Web Tier)
        |
    Private Subnets (App Tier)
        |
    Database Subnets (Data Tier)
```

### Security Group Flow
- **Internet** → **Web Security Group** (ports 80, 443)
- **Web Security Group** → **App Security Group** (port 8080)
- **App Security Group** → **Database Security Group** (ports 3306, 5432)
- **Bastion Security Group** → **Web/App Security Groups** (port 22)

## Outputs

The configuration provides useful outputs including:

- VPC ID and ARN
- Subnet IDs and CIDR blocks
- Security Group IDs
- NAT Gateway IDs and public IPs
- Route Table IDs
- Internet Gateway ID

## Best Practices

1. **Security**: Always restrict `allowed_ssh_cidrs` to your specific IP ranges
2. **Cost Optimization**: Use `single_nat_gateway = true` for development environments
3. **High Availability**: Use `one_nat_gateway_per_az = true` for production
4. **Tagging**: Customize `common_tags` for proper resource tracking
5. **Subnets**: Plan your CIDR blocks carefully to avoid conflicts

## Troubleshooting

### Common Issues

1. **Insufficient IP addresses**: Adjust subnet CIDR blocks to provide enough IPs
2. **AZ availability**: Some regions may have fewer than 3 AZs
3. **NAT Gateway costs**: Each NAT Gateway incurs hourly charges

### Useful Commands

```bash
# Check current AWS configuration
aws configure list

# Validate Terraform configuration
terraform validate

# Format Terraform files
terraform fmt

# Show current state
terraform show
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.