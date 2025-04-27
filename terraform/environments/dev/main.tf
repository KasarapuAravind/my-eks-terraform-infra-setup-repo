module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                 = var.azs
  cluster_name        = var.cluster_name
  tags = {
    "Environment" = "dev"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "eks" {
  source = "../../modules/eks"
  cluster_name = var.cluster_name
  cluster_version = var.cluster_version
  support_type            = var.support_type
  subnet_ids   = module.vpc.private_subnet_ids
  worker_node_cidr_blocks = module.vpc.private_subnet_cidrs
  vpc_id         = module.vpc.vpc_id

  vpc_cni_version = var.vpc_cni_version
  coredns_version = var.coredns_version
  kube_proxy_version = var.kube_proxy_version
  ebs_csi_driver_version = var.ebs_csi_driver_version

  tags = {
    "Environment" = "dev"
  }
}
