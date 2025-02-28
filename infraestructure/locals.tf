locals {
  name                = var.environment_name
  region              = var.aws_region
  vpc_cidr            = var.vpc_cidr
  num_of_subnets = min(length(data.aws_availability_zones.available.names), 3)
  azs = slice(data.aws_availability_zones.available.names, 0, local.num_of_subnets)
  eks_admin_role_name = var.eks_admin_role_name
  node_group_name     = "managed-ondemand"
  node_iam_role_name  = module.eks_blueprints_addons.karpenter.node_iam_role_name
  cluster_version     = var.cluster_version
  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}