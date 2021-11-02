terraform {
	backend "remote" {
		organization = "zeromano" # org name from step 2.
		workspaces {
			name = "monkeypesa" # name for your app's state.
		}
	}
}

module "dev_cluster" {
  source        = "./cluster"
  cluster_name  = "dev"
  asg_min_size  = 2
  asg_desired_capacity = 3
  instance_types      = ["t3.medium", "t3.large"]
  cluster_version = "1.20"
  
}

# module "staging_cluster" {
#   source        = "./cluster"
#   cluster_name  = "staging"
#   instance_type = "t2.micro"
# }

module "production_cluster" {
  source        = "./cluster"
  cluster_name  = "production"
  cidr                 = "10.0.0.0/16"
  private_subnets      = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  public_subnets       = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
  db_name              = "monkeypesa-prod-db"
  backup_retention_period = 35
  multiaz              = false
  asg_desired_capacity = 2
  asg_min_size         = 0
  asg_max_size         = 10
  on_demand_base_capacity= 2
  on_demand_base_capacity_above = 25
  instance_types      = ["t3.medium", "t3.large", "m5.large"]
  cluster_version = "1.20"
}

# locals {
#    cluster_id = module.dev_cluster.cluster_id

# }

output "dev_cluster_id" {
  description = "EKS cluster ID."
  value       = module.dev_cluster.cluster_id
}

output "dev_cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.dev_cluster.cluster_endpoint
}

output "dev_cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.dev_cluster.cluster_security_group_id
}

# output "kubectl_config" {
#   description = "kubectl config as generated by the module."
#   value       = module.eks.kubeconfig
# }

# output "config_map_aws_auth" {
#   description = "A kubernetes configuration to authenticate to this EKS cluster."
#   value       = module.eks.config_map_aws_auth
# }


output "dev_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.dev_cluster.cluster_name
}

# VPC
output "dev_vpc_id" {
  description = "The ID of the VPC"
  value       = module.dev_cluster.vpc_id
}

# Subnets
output "dev_private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.dev_cluster.private_subnets
}

output "dev_public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.dev_cluster.public_subnets
}

# NAT gateways
output "dev_nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.dev_cluster.nat_public_ips
}

#RDS
output "dev_db_instance_id" {
    description = "database instance id"
    value = module.dev_cluster.db_instance_id
}

output "dev_db_instance_host_address" {
  description = "rds db host instance address"
  value = module.dev_cluster.db_instance_address
}

output "dev_db_instance_host_endpoint" {
  description = "rds db host instance endpoint"
  value = module.dev_cluster.db_instance_host_endpoint
}

##PROD
output "prod_cluster_id" {
  description = "EKS cluster ID."
  value       = module.production_cluster.cluster_id
}

output "prod_cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.production_cluster.cluster_endpoint
}

output "prod_cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.production_cluster.cluster_security_group_id
}

# output "kubectl_config" {
#   description = "kubectl config as generated by the module."
#   value       = module.eks.kubeconfig
# }

# output "config_map_aws_auth" {
#   description = "A kubernetes configuration to authenticate to this EKS cluster."
#   value       = module.eks.config_map_aws_auth
# }


output "prod_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.production_cluster.cluster_name
}

# VPC
output "prod_vpc_id" {
  description = "The ID of the VPC"
  value       = module.production_cluster.vpc_id
}

# Subnets
output "prod_private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.production_cluster.private_subnets
}

output "prod_public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.production_cluster.public_subnets
}

# NAT gateways
output "prod_nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.production_cluster.nat_public_ips
}

#RDS
output "prod_db_instance_id" {
    description = "database instance id"
    value = module.production_cluster.db_instance_id
}

output "prod_db_instance_host_address" {
  description = "rds db host instance address"
  value = module.production_cluster.db_instance_address
}

output "prod_db_instance_host_endpoint" {
  description = "rds db host instance endpoint"
  value = module.production_cluster.db_instance_host_endpoint
}