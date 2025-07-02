terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair"
  type        = string
}

resource "aws_iam_role" "splunk_instance" {
  name = "splunk-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Inline policy allowing the instance role to assume the admin role
resource "aws_iam_role_policy" "splunk_escalate" {
  name = "splunk-escalate"
  role = aws_iam_role.splunk_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Resource = aws_iam_role.admin_escalation.arn
    }]
  })
}

resource "aws_iam_instance_profile" "splunk" {
  name = "splunk-instance-profile"
  role = aws_iam_role.splunk_instance.name
}

# Admin role that the instance can escalate to
resource "aws_iam_role" "admin_escalation" {
  name = "splunk-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { AWS = aws_iam_role.splunk_instance.arn }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.admin_escalation.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "trail" {
  bucket_prefix = "splunk-trail-"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id

  policy = data.aws_iam_policy_document.trail.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trail" {
  statement {
    sid     = "AWSCloudTrailAclCheck20150319"
    effect  = "Allow"
    principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] }
    actions  = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
  }
  statement {
    sid     = "AWSCloudTrailWrite20150319"
    effect  = "Allow"
    principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] }
    actions  = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_cloudtrail" "lab" {
  name                          = "splunk-lab-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  enable_logging                = true
}

# EC2 instance running Splunk
resource "aws_instance" "splunk" {
  ami                    = data.aws_ami.amzn2.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.splunk.name

  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              wget -O /tmp/splunk.rpm 'https://download.splunk.com/products/splunk/releases/9.1.1/linux/splunk-9.1.1-cd9db20f8e23.x86_64.rpm'
              rpm -i /tmp/splunk.rpm
              /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
              /opt/splunk/bin/splunk enable boot-start
              EOT

  tags = {
    Name = "splunk-lab"
  }
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

output "splunk_public_ip" {
  value = aws_instance.splunk.public_ip
}

output "admin_role_arn" {
  value = aws_iam_role.admin_escalation.arn
}
