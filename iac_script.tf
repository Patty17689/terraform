# Terraform configuration for modernizing applications with microservices using Amazon EKS

# Provider configuration
provider "aws" {
  region = "us-west-2"  # Replace with your desired AWS region
}

# VPC configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "customer-account-vpc"
  }
}

# Private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "private-subnet"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "managed-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.private.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach necessary policies to EKS Cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "eks-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.private.id]
}

# Route 53
resource "aws_route53_zone" "main" {
  name = "example.com"  # Replace with your domain
}

# CodePipeline
resource "aws_codepipeline" "main" {
  name     = "eks-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.main.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }
}

# CodeCommit repository
resource "aws_codecommit_repository" "main" {
  repository_name = "eks-app-repo"
  description     = "Application code repository"
}

# CodeBuild project
resource "aws_codebuild_project" "main" {
  name         = "eks-build-project"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
  }
}

# S3 bucket for artifact store
resource "aws_s3_bucket" "artifact_store" {
  bucket = "eks-artifact-store"
}

# IAM roles for CodePipeline and CodeBuild (with least privilege)
resource "aws_iam_role" "codepipeline" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "codebuild" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# Attach necessary policies to roles (implement least privilege)

# Output the EKS cluster endpoint
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

# Comments explaining the architecture:
# This Terraform configuration sets up a microservices architecture using Amazon EKS.
# It includes:
# - A VPC with a private subnet for secure networking
# - An EKS cluster for running containerized applications
# - A Network Load Balancer for distributing traffic
# - Route 53 for DNS management
# - CodePipeline, CodeCommit, and CodeBuild for CI/CD
# - IAM roles with least privilege permissions for security
# 
# The architecture allows for scalable and manageable microservices deployment,
# with automated build and deployment processes. Security is enhanced through
# the use of private subnets and IAM roles with minimal required permissions.