provider "aws" {
  region = var.aws_region
  profile = var.local_aws_profile
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
 # load_config_file       = true
}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  name                 = "k8s-${var.cluster_name}-vpc"
  cidr                 =  var.cidr #"10.0.0.0/16"
  azs                  =  data.aws_availability_zones.available.names
  private_subnets      =  var.private_subnets  #["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       =  var.public_subnets #["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
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

  cluster_name    = "eks-k8-${var.cluster_name}"
  cluster_version = var.cluster_version
  subnets         = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 50
  }
  enable_irsa = true
  write_kubeconfig   = true
  kubeconfig_output_path = "./"
  cluster_enabled_log_types = ["api","authenticator", "controllerManager"]
  map_users   = var.map_users
  manage_aws_auth       = true
  cluster_endpoint_private_access = "true"
  cluster_endpoint_public_access  = "true"
  kubeconfig_aws_authenticator_command = "aws"
  kubeconfig_aws_authenticator_command_args = ["eks", "get-token", "--cluster-name", var.cluster_name]
  kubeconfig_aws_authenticator_env_variables = {AWS_PROFILE = "mp"}
  #workers_additional_policies = [aws_iam_policy.worker_policy.arn, data.aws_iam_policy.EC2RoleforSSM.arn]
  workers_additional_policies = [data.aws_iam_policy.EC2RoleforSSM.arn]

  worker_groups_launch_template = [
    {
      name                    = join("-", ["eks-mixed-demand-spot", var.cluster_name])
      override_instance_types = "${var.instance_types}"
      spot_instance_pools     = 2 // how many spot pools per az, len matches instances types len
      asg_min_size            = "${var.asg_min_size}"
      asg_max_size            = "${var.asg_max_size}"
      asg_desired_capacity    = "${var.asg_desired_capacity}" 
      autoscaling_enabled     = true
      on_demand_base_capacity = "${var.on_demand_base_capacity}"
      on_demand_percentage_above_base_capacity = "${var.on_demand_base_capacity_above}"
      #bootstrap_extra_args    = "--container-runtime containerd"
      public_ip               = false
      root_encrypted          = true
      root_volume_size        = 25
    #  kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=`curl -s http://169.254.169.254/latest/meta-data/instance-life-cycle`"
     # additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      additional_userdata           = <<EOF
               cd /tmp 
               sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
               sudo systemctl enable amazon-ssm-agent 
               sudo systemctl start amazon-ssm-agent
               INSTANCEID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
               REGION=`curl http://169.254.169.254/latest/dynamic/instance-identity/document | grep region|awk -F\" '{print $4}'`
               aws ec2 modify-instance-attribute --instance-id=$INSTANCEID --no-source-dest-check --region $REGION
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

# resource "aws_security_group" "worker_group_mgmt_one" {
#   name_prefix = "worker_group_mgmt_one-${var.cluster_name}"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     from_port = 22
#     to_port   = 22
#     protocol  = "tcp"

#     cidr_blocks = [
#       "10.0.0.0/16",
#     ]
#   }
# }

# resource "aws_iam_policy" "worker_policy" {
#   name        = "worker-policy-${var.cluster_name}"
#   description = "Worker policy for the ALB Ingress"

#   policy = file("iam-policy.json")
# }

data "aws_iam_policy" "EC2RoleforSSM" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_policy" "eks_policy_alb_controller_ingress" {
  name      = "eks_sa_alb_controller_ingress-k8-${var.cluster_name}"
  description  = "service account policy for aws-load-balancer-controller"
  policy  = file("iam-policy.json")
  }  

# https://brennerm.github.io/posts/setting-up-eks-with-irsa-using-terraform.html

module "iam_assumable_role_with_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name = "k8-aws-load-balancer-controller-with-oidc_${var.cluster_name}"
  role_description = "assumable by alb controller ingress to interract with ALB resources"

  tags = {
    Role = "k8-ingress_role-with-oidc"
  }

  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = ["system:serviceaccount:default:sa-aws-load-balancer-controller-${var.cluster_name}"]

  role_policy_arns = [aws_iam_policy.eks_policy_alb_controller_ingress.arn]
  number_of_role_policy_arns = 1
}  

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name = "sa-aws-load-balancer-controller-${var.cluster_name}"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_assumable_role_with_oidc.iam_role_arn
    }
  }
  automount_service_account_token = true
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
    name  = "serviceAccount.create"
    value = false
  }


  set {
    name  = "serviceAccount.name"
    value = replace(kubernetes_service_account.aws_load_balancer_controller.id, "default/", "")
  }
}

resource "helm_release" "prometheus_monitors" {
  name       = "prometheus"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "19.2.2" 
  namespace = "default"
}