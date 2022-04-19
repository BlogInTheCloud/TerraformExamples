provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project = "auto-scaling-group-demo"
    }
  }
}

locals {
  name   = "auto-scaling-group-basic"
  region = "us-east-1"
  tags = {
    Environment = "demo"
    Blog = "auto-scaling-group-setup"
  }

  user_data = <<-EOT
  #!/bin/bash
  echo "Hello World!"
  EOT
}


################################################################################
# Launch template
################################################################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${local.name}-launch-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}



################################################################################
# Auto Scaling Group
################################################################################


module "auto-scaling-group-demo" {
  source  = "terraform-aws-modules/autoscaling/aws"
  
  name = "external-${local.name}"

  vpc_zone_identifier = module.vpc.private_subnets
  security_groups     = [module.asg_sg.security_group_id]
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1

  create_launch_template  = false
  launch_template         = aws_launch_template.this.name
  user_data               = base64encode(local.user_data)

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = "10.99.0.0/18"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets  = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

module "asg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "A security group"
  vpc_id      = module.vpc.vpc_id

  egress_rules = ["all-all"]

  tags = local.tags
}
