This repo containes all EKS terraform infra code to deploy EKs cluster and other components in AWS.

# EKS Infrastructure Repository (`my-eks-terraform-infra-setup-repo`)

## 📋 Overview

This repository manages the provisioning of a secure, production-grade Amazon EKS cluster, along with the underlying AWS infrastructure components, using Terraform.

The infrastructure created by this repository includes:
- Custom-built VPC with public and private subnets
- Internet Gateway, NAT Gateway, Elastic IPs, Route Tables
- Security Groups for EKS control plane and nodes
- IAM Roles and Policies
- EKS Control Plane with cluster-specific configuration
- EKS Add-ons deployed automatically:
  - AWS VPC CNI (vpc-cni)
  - CoreDNS (coredns)
  - Kube Proxy (kube-proxy)
  - Amazon EBS CSI Driver (ebs-csi-driver) with IRSA

This repository is built to follow production-grade best practices including modular code, OIDC authentication for GitHub Actions, and GitOps-friendly workflows.

---

## 📂 Repository Structure

```plaintext
.eks-infra-repo/
├── .github/
│   └── workflows/
│       └── terraform-plan.yaml
│       └── terraform-apply.yaml
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── providers.tf
│   │       ├── backend.tf
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── dev.tfvars
│   └── modules/
│       ├── vpc/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── eks/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
