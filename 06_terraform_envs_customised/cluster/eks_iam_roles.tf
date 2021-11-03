data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ADMIN_ROLE_POLICY" {
    statement {
      actions = ["sts:AssumeRole"]
      resources = [ "aws_iam_role.ADMIN_ROLE.arn" ]
      effect = "Allow"
      sid = "AllowAssumeOrganizationAccountRole"
    }
}


resource "aws_iam_role" "ADMIN_ROLE" {
  name               = "ADMIN_ROLE-${var_cluster_name}"
  assume_role_policy = "${file("assumerolepolicy.json")}"
}

resource "aws_iam_policy" "admin_group_ekspolicy" {
  name        = "${var.cluster_name}-${random_pet.pet_name.id}-eks-user-policy"
  description = "${var.cluster_name}-eks-user-policy"
  policy = data.aws_iam_policy_document.ADMIN_ROLE_POLICY.json
}

resource "aws_iam_role_policy_attachment" "ADMIN_ROLE_attachment" {
  role       = aws_iam_role.ADMIN_ROLE.name
  policy_arn = aws_iam_policy.admin_group_ekspolicy.arn
}
