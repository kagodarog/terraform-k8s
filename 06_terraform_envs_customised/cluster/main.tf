provider "aws" {
  region = "eu-west-1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  #version                = "~> 1.11"
}

data "aws_availability_zones" "available" {
}

variable "cluster_name" {
  default = "my-cluster"
}

variable "name" {
  default = "k8s-vpc"
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  #version = "2.47.0"

  name                 = "${var.name}"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "14.0.0"

  cluster_name    = "${var.cluster_name}"
  cluster_version = "1.19"
  subnets         = module.vpc.private_subnets
  enable_irsa     = true
  vpc_id = module.vpc.vpc_id

  node_groups = {
    first = {
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 1
      instance_types = [var.instance_types]
      capacity_type  = "SPOT"
    }
  }

  write_kubeconfig   = true
  config_output_path = "./"
  workers_additional_policies = [aws_iam_policy.worker_policy.arn]
}

variable "instance_types" {
  default = "t2.micro"
}

resource "aws_iam_policy" "worker_policy" {
  name      = "worker_policy-${var.cluster_name}"
  description  = "worker policy for ALB Ingres"
  policy  = file("cluster/iam_policy.json")
  } 

resource "aws_iam_policy" "eks_policy_externaldns" {
  name      = "eks_sa_policy_external_dns-${var.cluster_name}"
  description  = "service accpount policy for external dns"
  policy  = file("cluster/iam_policy_external_dns.json")
  }  

# https://brennerm.github.io/posts/setting-up-eks-with-irsa-using-terraform.html

module "iam_assumable_role_with_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 3.0"

  create_role = true

  role_name = "k8-external_dns-with-oidc_${var.cluster_name}"

  tags = {
    Role = "k8-external_dns_role-with-oidc"
  }

  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = ["system:serviceaccount:default:external-dns"]

  role_policy_arns = [aws_iam_policy.eks_policy_externaldns.arn]
  number_of_role_policy_arns = 1
}  
