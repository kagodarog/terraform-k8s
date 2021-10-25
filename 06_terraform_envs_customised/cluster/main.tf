provider "aws" {
  region = local.region
  profile = "mp"
}


data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

variable "cluster_name" {
  default = "monkeypesa-init-cluster"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      userarn  = "arn:aws:iam::291470148046:user/UmarK"
      username = "UmarK"
      groups   = ["system:masters"]
    },
  ]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  name                 = "k8s-${var.cluster_name}-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  private_subnet_suffix = "private"

  public_subnet_tags = {
    "kubernetes.io/cluster/eks-${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/eks-${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.22.0"

  cluster_name    = "eks-${var.cluster_name}"
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 50
  }
  enable_irsa = true
  write_kubeconfig   = true
  kubeconfig_output_path = "./"
  #cluster_enabled_log_types = ["api","authenticator", "audit"]
  map_users   = var.map_users
  manage_aws_auth       = true
  cluster_endpoint_private_access = "true"
  cluster_endpoint_public_access  = "true"
  kubeconfig_aws_authenticator_command = "aws"
  kubeconfig_aws_authenticator_command_args = ["eks", "get-token", "--cluster-name", var.cluster_name]
  kubeconfig_aws_authenticator_env_variables = {AWS_PROFILE = "mp"}
  workers_additional_policies = [aws_iam_policy.worker_policy.arn, data.aws_iam_policy.EC2RoleforSSM.arn]

  worker_groups_launch_template = [
    {
      name                    = join("-", ["eks-on-demand", var.cluster_name])
      override_instance_types = ["t3.medium", "t3.large"]
     # spot_instance_pools     = 2 // how many spot pools per az, len matches instances types len
      asg_max_size            = 1
      asg_max_size            = 5
      asg_desired_capacity    = 2
    #  ami_id                     = "ami-0b97f860a851277b3"
    #  kubelet_extra_args      = "--node-labels=kubernetes.io/lifecycle=spot"
      autoscaling_enabled     = true
      bootstrap_extra_args    = "--use-max-pods false --container-runtime containerd"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      additional_userdata           = <<EOF
               cd /tmp 
               sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
               sudo systemctl enable amazon-ssm-agent 
               sudo systemctl start amazon-ssm-agent
               INSTANCEID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
               REGION=`curl http://169.254.169.254/latest/dynamic/instance-identity/document | grep region|awk -F\" '{print $4}'`
               aws ec2 modify-instance-attribute --instance-id $INSTANCEID --no-source-dest-check --region $REGION
               EOF
      update_config = {
         max_unavailable_percentage = 50 # or set `max_unavailable`
         }
      protect_from_scale_in   = false
      tags = [
      {
        "key"                 = "tier"
        "propagate_at_launch" = "true"
        "value"               = "apps"
      }
    ]
    },
  ]



  # worker_groups = [
  #     {
  #       name                          = "worker-group-1"
  #       instance_type                 = "t3.medium"
  #       additional_userdata           = <<EOF
  #             cd /tmp 
  #             sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  #             sudo systemctl enable amazon-ssm-agent 
  #             sudo systemctl start amazon-ssm-agent
  #             EOF
  #       asg_desired_capacity          = 2
  #       additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]

  #       update_config = {
  #         max_unavailable_percentage = 50 # or set `max_unavailable`
  #       }
  #     }
  #   ]
  }

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/16",
    ]
  }
}

data "aws_iam_policy" "EC2RoleforSSM" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_policy" "worker_policy" {
  name        = "worker-policy-${var.cluster_name}"
  description = "Worker policy for the ALB Ingress"

  policy = file("iam-policy.json")
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "ingress" {
  name       = "ingress"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.2.7"
  set {
    name  = "clusterName"
    value = join("-", ["eks",var.cluster_name])
  }

  set {
    name  = "image.repository"
    value = "877085696533.dkr.ecr.af-south-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "hostNetwork"
    value = true
  }
}

resource "helm_release" "prometheus_monitor" {
  name       = "prometheus"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "19.2.2" 
  namespace = "default"

   set {
    name  = "hostNetwork"
    value = true
  }
}