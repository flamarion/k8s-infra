terraform {
  required_version = "~> 0.12"
  backend "remote" {
    organization = "FlamaCorp"

    workspaces {
      name = "tf-aws-k8s-infra"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  version = "~> 2.59"
}

# VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                               = "${var.tag_prefix}-vpc",
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_route53_zone" "private" {
  name = "k8s.lab"

  vpc {
    vpc_id = aws_vpc.k8s_vpc.id
  }
}

resource "aws_vpc_dhcp_options" "k8s_lab" {
  domain_name         = "k8s.lab"
  domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "k8s_resolver" {
  vpc_id          = aws_vpc.k8s_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.k8s_lab.id
}

# Security Groups



# IAM Policies and Profiles

# Master
resource "aws_iam_role" "k8s_master_role" {
  name               = "k8s_master_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "k8s_master_profile" {
  name = "k8s_master_profile"
  role = aws_iam_role.k8s_master_role.name
}

resource "aws_iam_policy" "k8s_master_policy" {
  name   = "k8s_master_policy"
  path   = "/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DetachLoadBalancerFromSubnets",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancerPolicies",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
        "iam:CreateServiceLinkedRole",
        "kms:DescribeKey"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "master_policy_attach" {
  role       = aws_iam_role.k8s_master_role.name
  policy_arn = aws_iam_policy.k8s_master_policy.arn
}


# Worker
resource "aws_iam_role" "k8s_worker_role" {
  name               = "k8s_worker_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "k8s_worker_profile" {
  name = "k8s_worker_profile"
  role = aws_iam_role.k8s_worker_role.name
}

resource "aws_iam_policy" "k8s_worker_policy" {
  name   = "k8s_worker_policy"
  path   = "/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "worker_policy_attach" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = aws_iam_policy.k8s_worker_policy.arn
}

# Load Balancer


# Route53 DNS Record
# data "aws_route53_zone" "selected" {
#   name = "hashicorp-success.com."
# }

# resource "aws_route53_record" "k8s_api" {
#   zone_id = data.aws_route53_zone.selected.id
#   name    = "${var.dns_record_name}.hashicorp-success.com"
#   type    = "A"
#   alias {
#     name                   = module.k8s_nlb.this_lb_dns_name
#     zone_id                = module.k8s_nlb.this_lb_zone_id
#     evaluate_target_health = true
#   }
# }


# SSH Key Pair
# resource "aws_key_pair" "k8s_key" {
#   key_name   = "k8s-flamarion-demo"
#   public_key = file("~/.ssh/cloud.pub")
# }

# Master nodes



# Worker Nodes
