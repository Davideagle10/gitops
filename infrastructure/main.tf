module "networking" {
  source                     = "./networking"
  aws_region                 = var.aws_region
  owner                      = var.owner
  vpc_cidr_block             = var.vpc_cidr_block
  private_subnets_cidr_block = var.private_subnets_cidr_block
  public_subnets_cidr_block  = var.public_subnets_cidr_block
  cluster_name               = var.cluster_name 
}

module "eks" {
  source = "./eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  owner              = var.owner
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
}