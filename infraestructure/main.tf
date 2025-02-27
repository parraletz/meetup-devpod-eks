module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  version         = "~> 5.0.0"
  name            = "eks_vpc"
  cidr            = var.vpc_cidr
  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 6, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 6, k + 10)]


  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true
  

  manage_default_network_acl    = true
  default_network_acl_tags = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags = { Name = "${local.name}-default" }


  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = 1
    "kubernetes.io/cluster/${var.environment_name}" = "owned"
  }


  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = 1
    "kubernetes.io/cluster/${var.environment_name}" = "owned"
    "karpenter.sh/discovery"                        = local.name
  }
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.name
  cluster_version = var.cluster_version || "1.30"


  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    eks-pod-identity-agent = {}
    kube-proxy = {}
    vpc-cni = {}
  }


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}