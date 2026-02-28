#!/bin/bash

# EKS Node Bootstrap Script for Amazon Linux 2023
# This script configures the node to join the EKS cluster

set -o xtrace

# Variables passed from Terraform
CLUSTER_NAME="${cluster_name}"
NODE_GROUP_NAME="${node_group_name}"
KUBERNETES_VERSION="${kubernetes_version}"
CLUSTER_SERVICE_CIDR="${cluster_service_cidr}"

# Set hostname
/bin/hostname $(curl -s http://169.254.169.254/latest/meta-data/local-hostname)

# Update system packages
dnf update -y

# Install required packages
dnf install -y aws-cli

# Configure kubelet for the specific Kubernetes version
mkdir -p /etc/kubernetes/kubelet
mkdir -p /etc/systemd/system/kubelet.service.d

# Create kubelet configuration
cat > /etc/kubernetes/kubelet/kubelet-config.json <<EOF
{
  "kind": "KubeletConfiguration",
  "apiVersion": "kubelet.config.k8s.io/v1beta1",
  "address": "0.0.0.0",
  "authentication": {
    "anonymous": {
      "enabled": false
    },
    "webhook": {
      "cacheTTL": "2m0s",
      "enabled": true
    },
    "x509": {
      "clientCAFile": "/etc/kubernetes/pki/ca.crt"
    }
  },
  "authorization": {
    "mode": "Webhook",
    "webhook": {
      "cacheAuthorizedTTL": "300s",
      "cacheUnauthorizedTTL": "30s"
    }
  },
  "clusterDomain": "cluster.local",
  "hairpinMode": "hairpin-veth",
  "readOnlyPort": 0,
  "cgroupDriver": "systemd",
  "cgroupRoot": "/",
  "featureGates": {
    "RotateKubeletServerCertificate": true
  },
  "protectKernelDefaults": true,
  "serializeImagePulls": false,
  "serverTLSBootstrap": true,
  "tlsCipherSuites": [
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
  ],
  "clusterDNS": [
    "172.20.0.10"
  ],
  "resolvConf": "/run/systemd/resolve/resolv.conf",
  "runtimeRequestTimeout": "15m",
  "kubeReserved": {
    "cpu": "100m",
    "ephemeral-storage": "1Gi",
    "memory": "100Mi"
  },
  "systemReserved": {
    "cpu": "100m",
    "ephemeral-storage": "1Gi", 
    "memory": "100Mi"
  }
}
EOF

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AVAILABILITY_ZONE | sed 's/[a-z]$//')

# Get node IP
NODE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Configure AWS CLI
aws configure set region $REGION

# Wait for cluster to be available
echo "Waiting for EKS cluster to be ready..."
while ! aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; do
  sleep 30
  echo "Still waiting for cluster..."
done

# Get cluster information
CLUSTER_INFO=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION)
CLUSTER_ENDPOINT=$(echo $CLUSTER_INFO | jq -r '.cluster.endpoint')
CLUSTER_CA_DATA=$(echo $CLUSTER_INFO | jq -r '.cluster.certificateAuthority.data')

# Create certificates directory
mkdir -p /etc/kubernetes/pki

# Write cluster CA certificate
echo $CLUSTER_CA_DATA | base64 -d > /etc/kubernetes/pki/ca.crt

# Configure kubelet environment
cat > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf <<EOF
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/etc/kubernetes/kubelet/kubelet-config.json"
Environment="KUBELET_KUBEADM_ARGS=--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock"
Environment="KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP --provider-id=aws:///$AVAILABILITY_ZONE/$INSTANCE_ID"
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

# Create bootstrap kubeconfig
cat > /etc/kubernetes/bootstrap-kubelet.conf <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: $CLUSTER_ENDPOINT
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
      - eks
      - get-token
      - --cluster-name
      - $CLUSTER_NAME
      - --region 
      - $REGION
EOF

# Configure containerd for EKS
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml <<EOF
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
address = "/run/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri"]
sandbox_image = "602401143452.dkr.ecr.$REGION.amazonaws.com/eks/pause:3.5"

[plugins."io.containerd.grpc.v1.cri".containerd]
default_runtime_name = "runc"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".cni]
bin_dir = "/opt/cni/bin"
conf_dir = "/etc/cni/net.d"

[plugins."io.containerd.grpc.v1.cri".registry]
config_path = "/etc/containerd/certs.d"

[plugins."io.containerd.grpc.v1.cri".registry.mirrors."public.ecr.aws"]
endpoint = ["https://public.ecr.aws"]
EOF

# Enable and start containerd
systemctl daemon-reload
systemctl enable containerd
systemctl start containerd

# Install and configure kubelet
if [ ! -f /usr/bin/kubelet ]; then
  curl -L "https://dl.k8s.io/release/v$KUBERNETES_VERSION.0/bin/linux/amd64/kubelet" -o /usr/bin/kubelet
  chmod +x /usr/bin/kubelet
fi

# Enable and start kubelet
systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

# Install kubectl for debugging
if [ ! -f /usr/local/bin/kubectl ]; then
  curl -L "https://dl.k8s.io/release/v$KUBERNETES_VERSION.0/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
  chmod +x /usr/local/bin/kubectl
fi

# Add labels to the node
sleep 60
/usr/local/bin/kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node $(hostname) \
  node.kubernetes.io/instance-type=$INSTANCE_TYPE \
  eks.amazonaws.com/nodegroup=$NODE_GROUP_NAME \
  --overwrite || true

# Log successful completion
echo "Node bootstrap completed successfully" > /var/log/eks-bootstrap.log
echo "Cluster: $CLUSTER_NAME" >> /var/log/eks-bootstrap.log
echo "Node Group: $NODE_GROUP_NAME" >> /var/log/eks-bootstrap.log
echo "Kubernetes Version: $KUBERNETES_VERSION" >> /var/log/eks-bootstrap.log
echo "Instance ID: $INSTANCE_ID" >> /var/log/eks-bootstrap.log
echo "Instance Type: $INSTANCE_TYPE" >> /var/log/eks-bootstrap.log
echo "Availability Zone: $AVAILABILITY_ZONE" >> /var/log/eks-bootstrap.log

# Signal success to CloudFormation if applicable
/opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource NodeGroup --region $REGION || true

echo "EKS Node bootstrap completed"