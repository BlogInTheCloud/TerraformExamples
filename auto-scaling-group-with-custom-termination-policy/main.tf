provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project = "auto-scaling-group-demo"
    }
  }
}

locals {
  name   = "auto-scaling-group-with-custom-termination-policy"
  region = "us-east-1"
  ctp_lambda_name = "custom-termination-policy-lambda"
  tags = {
    Environment = "demo"
    Blog = "auto-scaling-group-with-custom-termination-policy"
  }

  user_data = <<-EOT
  #!/bin/bash
  echo "Hello World!"
  EOT
}



################################################################################
# Lambda function
################################################################################

data "aws_caller_identity" "current" {}

data "archive_file" "ctp_function" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/output/lambda.zip"
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${local.ctp_lambda_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.ctp_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role" "ctp_role" {
  name = "custom-termination-policy-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "custom_termination_policy_lambda" {
  filename          = data.archive_file.ctp_function.output_path
  function_name     = local.ctp_lambda_name
  role              = aws_iam_role.ctp_role.arn
  handler           = "index.handler"
  runtime           = "nodejs12.x"
  source_code_hash  = data.archive_file.ctp_function.output_base64sha256
  tags              = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.example,
  ]
}

resource "aws_lambda_permission" "allow_autoscaling" {
  statement_id  = "AllowExecutionFromAutoScaling"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_termination_policy_lambda.function_name
  principal     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"

  depends_on = [
    aws_lambda_function.custom_termination_policy_lambda,
  ]
}

################################################################################
# Auto Scaling Group
################################################################################

module "auto-scaling-group-with-custom-termination-policy" {
  source  = "terraform-aws-modules/autoscaling/aws"

  name = "external-${local.name}"

  vpc_zone_identifier = module.vpc.private_subnets
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1

  create_launch_template  = false
  launch_template         = aws_launch_template.this.name
  user_data               = base64encode(local.user_data)

  termination_policies = [
    aws_lambda_function.custom_termination_policy_lambda.arn
  ]

  tags = local.tags

  depends_on = [
    aws_launch_template.this,
    aws_lambda_function.custom_termination_policy_lambda,
  ]
}

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
