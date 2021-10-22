resource "random_password" "master"{
  length           = 16
  special          = true
  override_special = "_!%^"
}

variable "name" {
  default = "monkeypesa-init-db"
}

locals {
  name   = "test-mysql"
  region = "af-south-1"
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

resource "aws_secretsmanager_secret" "password" {
  name = "dev-db-password-secret"
  description = "db password secret"
  replica  {
    region = "eu-central-1"
  }
  tags = local.tags

}
resource "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.password.id
  secret_string = <<EOF
   {
    "username": "adminaccount",
    "password": "${random_password.master.result}"
   }
EOF
}