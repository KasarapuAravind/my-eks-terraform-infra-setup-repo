resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = var.subnet_ids
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
    resolve_conflicts_on_create = "OVERWRITE"
    service_account_role_arn = null

    depends_on = [ aws_eks_cluster.this ]  
}

## Add-on: CoreDNS
resource "aws_eks_addon" "coredns" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "coredns"
    addon_version = var.coredns_version
    resolve_conflicts_on_create = "OVERWRITE"

    depends_on = [ aws_eks_cluster.this ]
}

## Add-on Kube-Proxy
resource "aws_eks_addon" "kube_proxy" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "kube-proxy"
    addon_version = var.kube_proxy_version
    resolve_conflicts_on_create = "OVERWRITE"
    
    depends_on = [ aws_eks_cluster.this ]
}

## Add-on EBS CSI Driver
resource "aws_eks_addon" "ebs_csi_driver" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "aws-ebs-csi-driver"
    addon_version = var.ebs_csi_driver_version
    resolve_conflicts_on_create = "OVERWRITE"
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
