variable "cluster_name" {}
variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "subnet_ids" {
  type = list(string)
}
variable "tags" {
  type = map(string)
  default = {}
}

variable "vpc_cni_version" {
    description = "Version for the VPC CNI addon"
    type = string  
}

variable "coredns_version" {
    description = "Version for the Core DNS addon"
    type = string  
}

variable "kube_proxy_version" {
    description = "Version for kube proxy addon"
}

variable "ebs_csi_driver_version" {
  description = "Version for EBS CSI driver addon"
  type        = string
}
