resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version = var.cluster_version

  access_config {
    authentication_mode = "API"
  }

  kubernetes_network_config {
    ip_family = "ipv4" # we'll discuss separately below
  }

  upgrade_policy {
    support_type = var.support_type
    }

  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_control_plane.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

## Add-on: VPC-CNI
resource "aws_eks_addon" "vpc_cni" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "vpc-cni"
    addon_version = var.vpc_cni_version
    resolve_conflicts_on_update = "OVERWRITE"
    service_account_role_arn = null

    depends_on = [ aws_eks_cluster.this ]  
}

## Add-on: CoreDNS
resource "aws_eks_addon" "coredns" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "coredns"
    addon_version = var.coredns_version
    resolve_conflicts_on_update = "OVERWRITE"

    depends_on = [ aws_eks_cluster.this ]
}

## Add-on Kube-Proxy
resource "aws_eks_addon" "kube_proxy" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "kube-proxy"
    addon_version = var.kube_proxy_version
    resolve_conflicts_on_update = "OVERWRITE"
    
    depends_on = [ aws_eks_cluster.this ]
}

## Add-on EBS CSI Driver
resource "aws_eks_addon" "ebs_csi_driver" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "aws-ebs-csi-driver"
    addon_version = var.ebs_csi_driver_version
    resolve_conflicts_on_update = "OVERWRITE"
    service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

    depends_on = [ aws_eks_cluster.this ]
}

# IAM Role for EBS CSI driver (IRSA)
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_eks_cluster.this.identity[0].oidc[0].issuer
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

## EKs Cluster SG for communication between eks controlplane and nodes
resource "aws_security_group" "eks_control_plane" {
  name        = "${var.cluster_name}-control-plane-sg"
  description = "Security group for EKS control plane communication"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow worker nodes to communicate with control plane"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.worker_node_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-eks-control-plane"
  }
}

# Zero-Size Managed Node Group (Bootstrap Node Group)
resource "aws_eks_node_group" "bootstrap_ng" {
  cluster_name    = aws_eks_cluster.this.name
  node_role_arn   = aws_iam_role.eks_worker_node_role.arn
  node_group_name = "${var.cluster_name}-bootstrap-ng"

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  instance_types = ["t3.medium"]  # A small instance just for bootstrap
  disk_size      = 20
  ami_type       = "AL2_x86_64"   # Amazon Linux 2

  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.cluster_name}-bootstrap-ng"
    Environment = var.environment
  }

  depends_on = [aws_eks_cluster.this]
}

# Karpenter IRSA (IAM Role for Service Account)
resource "aws_iam_role" "karpenter_controller_role" {
  name = "${var.cluster_name}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_eks_cluster.this.identity[0].oidc[0].issuer
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name = "${var.cluster_name}-karpenter-controller-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:CreateLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "autoscaling:CreateOrUpdateTags",
          "autoscaling:DescribeAutoScalingGroups",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy_attach" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

resource "aws_iam_role" "karpenter_ec2_node_role" {
  name = "${var.cluster_name}-karpenter-ec2-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_ec2_worker_node_policy" {
  role       = aws_iam_role.karpenter_ec2_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_ec2_ecr_read_policy" {
  role       = aws_iam_role.karpenter_ec2_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# # this is to handle spot instance gracefull termination in karpenter
# resource "aws_sqs_queue" "karpenter_interruption_queue" {
#   name = "${var.cluster_name}-karpenter-interruption-queue"
# }
