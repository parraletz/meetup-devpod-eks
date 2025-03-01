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
  version = "20.23.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = { most_recent = true }
    coredns = { most_recent = true }

    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cloudwatch_log_group              = false
  create_cluster_security_group            = false
  create_node_security_group               = false
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      instance_types = [
        "m7i.2xlarge", "m7i.4xlarge", "m7i.8xlarge"
      ]

      create_security_group = false

      subnet_ids   = module.vpc.private_subnets
      max_size     = 5
      desired_size = 4
      min_size = 4

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os = "amazonlinux2eks"

      labels = {
        intent = "control-apps"
      }
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}




