cluster_name = "my-dev-eks-cluster"
cluster_version = "1.30"
support_type = "STANDARD"
region       = "us-east-1"
vpc_cidr     = "10.0.0.0/16"
azs          = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
vpc_cni_version         = "v1.16.2-eksbuild.1"
coredns_version         = "v1.11.1-eksbuild.2"
kube_proxy_version      = "v1.30.0-eksbuild.1"
ebs_csi_driver_version  = "v1.27.1-eksbuild.1"

