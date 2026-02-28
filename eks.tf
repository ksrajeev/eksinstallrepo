# Data source for EKS cluster service account
data "aws_iam_policy_document" "eks_cluster_service_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# EKS Module - Using public terraform-aws-modules/eks/aws
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Cluster Configuration
  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  # VPC Configuration - Using VPC from main.tf
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  control_plane_subnet_ids        = module.vpc.private_subnets

  # Public cluster configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs

  # Cluster Security Group
  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
    ingress_all_cidr = {
      description = "Allow all ingress traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_nodes_443 = {
      description                = "Cluster API to node groups"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Node Security Group
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    minimal_node_group = {
      name = "${var.eks_cluster_name}-nodes"

      # Instance Configuration
      instance_types = [var.eks_node_instance_type]
      capacity_type  = "ON_DEMAND"

      # Scaling Configuration
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      # Subnet Configuration
      subnet_ids = module.vpc.private_subnets

      # Disk Configuration
      disk_size = var.eks_node_disk_size
      disk_type = "gp3"

      # AMI Configuration
      ami_type = "AL2_x86_64"

      # Node Group Configuration
      capacity_type        = "ON_DEMAND"
      force_update_version = false

      # Taints
      taints = []

      # Labels
      labels = {
        Environment = var.common_tags.Environment
        NodeGroup   = "minimal"
        Purpose     = "general-workload"
      }

      # Tags
      tags = merge(var.common_tags, {
        Name = "${var.eks_cluster_name}-node-group"
        Purpose = "EKS Managed Node Group"
        NodeGroupType = "Minimal"
        InstanceType = var.eks_node_instance_type
        ScalingPolicy = "Manual"
        Component = "Compute"
        Tier = "Worker Nodes"
      })
    }
  }

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 1
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI = "true"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
      configuration_values = jsonencode({
        defaultStorageClass = {
          enabled = true
        }
      })
    }
  }

  # Enable IRSA
  enable_irsa = true

  # Cluster IAM Role
  create_cluster_security_group = true
  create_node_security_group    = true

  # CloudWatch Logging
  cluster_enabled_log_types = var.eks_cluster_log_types

  # Cluster Tags
  tags = merge(var.common_tags, {
    Name = var.eks_cluster_name
    Purpose = "EKS Cluster"
    ClusterType = "Public"
    KubernetesVersion = var.eks_cluster_version
    Component = "Container Orchestration"
    Tier = "Platform"
    ManagedBy = "Terraform"
    NetworkType = "Private Subnets"
    EndpointAccess = "Public"
  })

  # Cluster Security Group Tags
  cluster_security_group_tags = merge(var.common_tags, {
    Name = "${var.eks_cluster_name}-cluster-security-group"
    Purpose = "EKS Cluster Security"
    Component = "Cluster Security"
    SecurityLevel = "High"
  })

  # Node Security Group Tags
  node_security_group_tags = merge(var.common_tags, {
    Name = "${var.eks_cluster_name}-node-security-group"
    Purpose = "EKS Node Security"
    Component = "Node Security"
    SecurityLevel = "High"
  })
}

# Additional Security Group for EKS Administrative Access
resource "aws_security_group" "eks_admin_access" {
  name        = "${var.eks_cluster_name}-admin-sg"
  description = "Security group for EKS administrative access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS Admin Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.eks_admin_access_cidrs
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.eks_cluster_name}-admin-sg"
    Purpose = "EKS Administrative Access"
    Component = "Access Control"
    SecurityLevel = "Critical"
    AccessType = "Admin"
    NetworkRestriction = "CIDR-Based"
  })
}

# IAM Role for EKS Node Groups (if additional customization needed)
resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.eks_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = merge(var.common_tags, {
    Name = "${var.eks_cluster_name}-node-role"
    Purpose = "EKS Node Group IAM Role"
    Component = "IAM"
    ServiceType = "EC2"
    ClusterName = var.eks_cluster_name
  })
}

# IAM Role Policy Attachments for Node Groups
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# EBS CSI Driver IAM Policy for Node Groups
resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "${var.eks_cluster_name}-ebs-csi"
  description = "IAM policy for EBS CSI driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeAttribute",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeVolumesModifications",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.eks_cluster_name}-ebs-csi"
    Purpose = "EBS CSI Driver Policy"
    Component = "Storage"
    ServiceType = "EBS"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment" {
  policy_arn = aws_iam_policy.ebs_csi_policy.arn
  role       = aws_iam_role.eks_node_group_role.name
}