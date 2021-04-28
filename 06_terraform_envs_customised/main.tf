module "dev_cluster" {
  source        = "./cluster"
  cluster_name  = "test"
  name = "tpe-vpc"
  instance_types = "t2.micro"
}

module "staging_cluster" {
  source        = "./cluster"
  cluster_name  = "uat"
  instance_types = "t2.micro"
  name = "uat-vpc"
}

module "production_cluster" {
  source        = "./cluster"
  cluster_name  = "production"
  name = "prod-vpc"
  instance_types = "t2.micro"
}