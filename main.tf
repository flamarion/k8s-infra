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
module "k8s_vpc" {
  source               = "github.com/flamarion/terraform-aws-vpc?ref=v0.0.4"
  az                   = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  # Resource Tags
  vpc_tags = {
    "Name"                             = "vpc-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
  public_subnet_tags = {
    "Name"                             = "public-subnet-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
  igw_tags = {
    "Name"                             = "internet-gateway-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
  public_rt_tags = {
    "Name"                             = "public-subnet-route-table-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}


# Security Groups

module "k8s_common_sg" {
  source      = "github.com/flamarion/terraform-aws-sg?ref=v0.0.4"
  name        = "k8s-common-sg-${var.owner}"
  description = "K8S LB SG"
  vpc_id      = module.k8s_vpc.vpc_id
  sg_tags = {
    "Name"                             = "k8s-lb-sg-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
  sg_rules_cidr = {
    ssh = {
      description       = "SSH"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = 22
      to_port           = 22
      protocol          = "tcp"
      security_group_id = module.k8s_common_sg.sg_id
    },
    k8s_subnets = {
      description       = "K8s"
      type              = "ingress"
      cidr_blocks       = module.k8s_vpc.public_subnets
      from_port         = -1
      to_port           = -1
      protocol          = "all"
      security_group_id = module.k8s_common_sg.sg_id
    },
    outbound = {
      description       = "Outbound is allowed"
      type              = "egress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = -1
      to_port           = -1
      protocol          = "all"
      security_group_id = module.k8s_common_sg.sg_id
    }
  }
}

module "k8s_master_sg" {
  source      = "github.com/flamarion/terraform-aws-sg?ref=v0.0.4"
  name        = "k8s-master-sg-${var.owner}"
  description = "K8S LB SG"
  vpc_id      = module.k8s_vpc.vpc_id
  sg_tags = {
    "Name"                             = "k8s-lb-sg-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
  sg_rules_cidr = {
    api = {
      description       = "K8s API"
      type              = "ingress"
      cidr_blocks       = ["0.0.0.0/0"]
      from_port         = 6443
      to_port           = 6443
      protocol          = "tcp"
      security_group_id = module.k8s_master_sg.sg_id
    }
  }
}

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

# SSH Key Pair
resource "aws_key_pair" "k8s_key_pair" {
  key_name   = "k8s-ssh-key-${var.owner}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCWTvOFNdwL7X3sVa3trlSYyQCZ1mAbTSMa7Z3V+0px4NU24ZcI93yh5UTAZjhHMh95hoc7069O/3Yj4V1v92oI+UdNF8ZcBY9BwtuzIlAVB7RLAyCzMdO91Jg4OMtUcCeM5beVKqW6Qp1AywbNCcbcfRBnTcfuRkZswjHLlMj+CsBaU23QiVE8tbARDCOTXCwErbxhcwmOnKE1dnhEZkslqFxsTYUZIQgj6ePB5cCBUGLb2n0PQ5NmVo3+xBsEVC3OaX1xjf0WPzF6+ppSEa2qm1BqqbMi9tMrObVZn37/Zu75OizSJrGrgRz3YTJixebS7nA309jDuJMzWj3HA/m3RWdtRVCnBIqpG75X4uzVg9TFRaNbF+tN37Lrdlp8tWKW4JeWlO9hNtPkZVYqXVqfuWMaiY+BZoVmvw4sPgAZRufFMj1gNxiYTCoOlVzyIZJZvUxum2dIVm/GxsZylP9N4WpZOuyb4UTuyOlMnXONFAgLD1z1lWx1+0cG18T+5PmeIzutYVE5tIPDc+dEW2ZvJKHDqAhk7JjG60UvbcdjXBhCDDEM3Crf0sptwcsfLavhF3aSy6d4NKDRL4LtC908Vrnz3zwuO0XQ5ZJyJzYh2U6VqTQQfcdLuQ4qMr0TIqv1f29+VPy7b9aXVQrQKeCs4aviTzI/SpwADm+1Swkm9w== flamarion@arvore"
}

# AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
#ami                         = "ami-0209a3524a56ed792"

# Install Kubernetes stuff
data "template_file" "k8s_tools_script" {
  template = file("${path.module}/templates/install-tools.sh.tpl")
}

# Master nodes
resource "aws_instance" "k8s_master" {
  count                       = length(module.k8s_vpc.public_subnets)
  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = element(module.k8s_vpc.az, count.index)
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  vpc_security_group_ids      = [module.k8s_master_sg.sg_id,module.k8s_common_sg.sg_id]
  subnet_id                   = element(module.k8s_vpc.public_subnets_id, count.index)
  user_data                   = data.template_file.k8s_tools_script.rendered
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k8s_master_profile.id
  root_block_device {
    volume_size = 50
  }
  tags = {
    "Name"                             = "k8s-master-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Worker Nodes
resource "aws_instance" "k8s_worker" {
  count                       = length(module.k8s_vpc.public_subnets)
  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = element(module.k8s_vpc.az, count.index)
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  vpc_security_group_ids      = [module.k8s_common_sg.sg_id]
  subnet_id                   = element(module.k8s_vpc.public_subnets_id, count.index)
  user_data                   = data.template_file.k8s_tools_script.rendered
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k8s_worker_profile.id
  root_block_device {
    volume_size = 50
  }
  tags = {
    "Name"                             = "k8s-worker-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Load Balancer
resource "aws_lb" "k8s_lb" {
  name               = "k8s-lb-${var.owner}"
  load_balancer_type = "network"
  subnets            = module.k8s_vpc.public_subnets_id
  tags = {
    "Name"                             = "k8s-lb-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_lb_target_group" "k8s_master_tg" {
  name     = "k8s-tg-${var.owner}"
  port     = 6443
  protocol = "TCP"
  vpc_id   = module.k8s_vpc.vpc_id
  tags = {
    "Name"                             = "k8s-tg-${var.owner}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_lb_target_group_attachment" "k8s_tg_att" {
  count            = length(module.k8s_vpc.public_subnets)
  target_group_arn = aws_lb_target_group.k8s_master_tg.arn
  target_id        = aws_instance.k8s_master[count.index].id
  port             = 6443

}

resource "aws_lb_listener" "k8s_master_listener" {
  load_balancer_arn = aws_lb.k8s_lb.arn
  port              = 6443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_master_tg.arn
  }
}
