data "aws_secretsmanager_secret" "password" {
  name = "dev-db-password-secret"

}

data "aws_secretsmanager_secret_version" "password" {
  secret_id = data.aws_secretsmanager_secret.password.id
}

# output "secret_password_value" {
#   value = jsondecode(data.aws_secretsmanager_secret_version.password.secret_string)["key1"]
# }

resource "aws_security_group" "db-security-gp" {
  description = "rds db security group"
  name = "test-db-security-group" 
  vpc_id = module.vpc.vpc_id

  ingress  {
    cidr_blocks = [module.vpc.vpc_cidr_block]
    from_port = 3306
    protocol = "tcp"
    to_port = 3306
  } 

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    protocol = "-1"
    ipv6_cidr_blocks = ["::/0"]
    to_port = 0
  }
  
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.0"

  identifier = var.name

  engine            = "mysql"
  engine_version    = "5.7.33"
  instance_class    = "db.t3.small"
  allocated_storage = 15
  max_allocated_storage = 500

  name     = "demodb"
  username = jsondecode(data.aws_secretsmanager_secret_version.password.secret_string)["username"]
  password = jsondecode(data.aws_secretsmanager_secret_version.password.secret_string)["password"]
  port     = "3306"

  storage_encrypted = true

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["audit", "general"]
  

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
  monitoring_interval = "30"
  monitoring_role_name = "MyRDSMonitoringRole"
  create_monitoring_role = true

  tags = local.tags


  # DB subnet group
  subnet_ids =  module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.db-security-gp.id]

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Database Deletion Protection
  deletion_protection = true

  parameters = [
    {
      name = "character_set_client"
      value = "utf8mb4"
    },
    {
      name = "character_set_server"
      value = "utf8mb4"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}

