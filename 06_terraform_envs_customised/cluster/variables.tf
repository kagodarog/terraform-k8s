

variable "aws_region" {
  default = "af-south-1"
}

variable "local_aws_profile" {
  default = "mp"
}

variable "cidr" {
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "instance_types" {
  default = ["t3.medium", "t3.large"]
}

variable "asg_min_size" {
  default = 1
}

variable "asg_max_size" {
  default = 4
}

variable "asg_desired_capacity" {
  default = 2
}

variable "on_demand_base_capacity" {
  default = 0
}

variable "on_demand_base_capacity_above" {
  default = 0
}


##RDS

variable "test_db_name" {
  default = "monkeypesa-init-db"
}

variable "prod_db_name" {
  default = "monkeypesa-prod-db"
}

variable "db_name" {
  default = "monkeypesa-dev-db"
}

variable "backup_retention_period" {
  default = 4
}

variable "multiaz" {
  default = false
}


##EKS
variable "cluster_name" {
  default = "monkeypesa-init-cluster"
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
