module "streamforge" {
  source               = "../../modules/streamforge"
  aws_region           = var.aws_region
  environment          = var.environment
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  backend_image        = var.backend_image
  frontend_image       = var.frontend_image
  use_local_emulator   = var.use_local_emulator
  ec2_endpoint         = var.ec2_endpoint
  aws_endpoint         = var.aws_endpoint
  allowed_cidrs        = var.allowed_cidrs
}
