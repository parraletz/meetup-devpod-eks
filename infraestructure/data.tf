data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

data "aws_iam_role" "eks_admin_role_name" {
  count = local.eks_admin_role_name != "" ? 1 : 0
  name  = local.eks_admin_role_name
}

data "aws_ecrpublic_authorization_token" "token" {}
