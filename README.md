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

### EKS Cluster
- **EKS Cluster** with public endpoint access
- **Managed Node Group** with single node (minimal configuration)
- **EKS Add-ons** (CoreDNS, kube-proxy, VPC-CNI, EBS CSI driver)
- **IRSA (IAM Roles for Service Accounts)** enabled
- **CloudWatch Logging** for cluster monitoring
- **Security Groups** for cluster and node access control

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
├── main.tf                    # Main Terraform configuration (VPC)
├── eks.tf                     # EKS cluster configuration
├── variables.tf              # Variable definitions
├── outputs.tf               # Output definitions
├── terraform.tfvars.example # Example variables file
├── Makefile                 # Convenience commands
├── .gitignore              # Git ignore rules
└── README.md               # This documentation
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

### EKS Configuration
- `eks_cluster_name`: Name for the EKS cluster
- `eks_cluster_version`: Kubernetes version (e.g., "1.28")
- `eks_public_access_cidrs`: IP ranges allowed for API access
- `eks_admin_access_cidrs`: IP ranges for administrative access

### Node Group Settings
- `eks_node_instance_type`: EC2 instance type (default: t3.small)
- `eks_node_min_size`: Minimum nodes (default: 1)
- `eks_node_max_size`: Maximum nodes (default: 3)
- `eks_node_desired_size`: Desired nodes (default: 1)
- `eks_node_disk_size`: Node disk size in GB (default: 20)

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

- **VPC**: VPC ID and ARN, subnet IDs, route table IDs
- **Security Groups**: Security Group IDs for all tiers
- **NAT Gateway**: IDs and public IPs
- **EKS Cluster**: Cluster endpoint, certificate, OIDC provider
- **EKS Node Groups**: Node group ARNs and status
- **kubectl**: Command to configure kubectl access

## Post-Deployment

### Accessing the EKS Cluster

After successful deployment, configure kubectl to access your cluster:

```bash
# Configure kubectl (command provided in terraform output)
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Verify cluster access
kubectl get nodes
kubectl get pods --all-namespaces
```

### Cluster Information

```bash
# View cluster info
kubectl cluster-info

# Check node status
kubectl get nodes -o wide

# View installed add-ons
kubectl get daemonset -n kube-system
```

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