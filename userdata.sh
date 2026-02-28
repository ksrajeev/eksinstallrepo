#!/bin/bash

# EKS Node Bootstrap Script for Amazon Linux 2023 and Kubernetes 1.33
# This script configures the node to join the EKS cluster

set -o xtrace

# Variables passed from Terraform
CLUSTER_NAME="${cluster_name}"
NODE_GROUP_NAME="${node_group_name}"
KUBERNETES_VERSION="${kubernetes_version}"
CLUSTER_SERVICE_CIDR="${cluster_service_cidr}"

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AVAILABILITY_ZONE | sed 's/[a-z]$//')

echo "Starting EKS node bootstrap for cluster: $CLUSTER_NAME"
echo "Node Group: $NODE_GROUP_NAME"
echo "Kubernetes Version: $KUBERNETES_VERSION"
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

# Update system packages
dnf update -y

# Install essential packages
dnf install -y \
    aws-cli \
    jq \
    curl \
    wget \
    unzip

# Configure AWS CLI
aws configure set region $REGION

# Wait for the EKS cluster to be ready
echo "Waiting for EKS cluster to be available..."
for i in {1..30}; do
  if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
    echo "Cluster is ready"
    break
  fi
  echo "Attempt $i: Cluster not ready, waiting 30 seconds..."
  sleep 30
done

# Get cluster endpoint and CA certificate
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.endpoint' --output text)
CLUSTER_CA=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.certificateAuthority.data' --output text)

echo "Cluster Endpoint: $CLUSTER_ENDPOINT"

# Use the official EKS bootstrap script
/etc/eks/bootstrap.sh $CLUSTER_NAME \
  --container-runtime containerd \
  --kubelet-extra-args "--max-pods=110 --node-labels=nodegroup=$NODE_GROUP_NAME,instance-type=$INSTANCE_TYPE" \
  --b64-cluster-ca "$CLUSTER_CA" \
  --apiserver-endpoint "$CLUSTER_ENDPOINT"

# Log completion
echo "EKS Node bootstrap completed successfully" > /var/log/eks-bootstrap.log
echo "Cluster: $CLUSTER_NAME" >> /var/log/eks-bootstrap.log
echo "Node Group: $NODE_GROUP_NAME" >> /var/log/eks-bootstrap.log
echo "Kubernetes Version: $KUBERNETES_VERSION" >> /var/log/eks-bootstrap.log
echo "Instance ID: $INSTANCE_ID" >> /var/log/eks-bootstrap.log
echo "Timestamp: $(date)" >> /var/log/eks-bootstrap.log

echo "EKS Node bootstrap script completed"