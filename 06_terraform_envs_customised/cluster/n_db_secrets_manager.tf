resource "random_password" "master"{
  length           = 16
  special          = true
  override_special = "_!%^"
}


locals {
  name   = "test-mysql"
  tags = {
    Owner       = "user"
  }
}

resource "aws_secretsmanager_secret" "password" {
  name = "db-password-secret-${var.cluster_name}"
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