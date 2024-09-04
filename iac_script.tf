# Configure AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create VPC
resource "aws_vpc" "customer_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "customer-vpc"
  }
}

# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.customer_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "private-subnet"
  }
}

# Create EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "managed-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.private_subnet.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Create IAM role for EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
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

# Attach EKS cluster policy to IAM role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create Elastic Network Interface
resource "aws_network_interface" "eni" {
  subnet_id   = aws_subnet.private_subnet.id
  description = "Elastic Network Interface"

  tags = {
    Name = "eks-eni"
  }
}

# Create Route 53
resource "aws_route53_zone" "private_zone" {
  name = "example.com"

  vpc {
    vpc_id = aws_vpc.customer_vpc.id
  }
}

# Create Network Load Balancer
resource "aws_lb" "network_lb" {
  name               = "network-lb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.private_subnet.id]

  tags = {
    Name = "network-lb"
  }
}

# Create CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "eks-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

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
        RepositoryName = "eks-repo"
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
        ProjectName = "eks-build"
      }
    }
  }
}

# Create IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
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

# Create S3 bucket for artifact store
resource "aws_s3_bucket" "artifact_store" {
  bucket = "eks-artifact-store"
}

# Create ECR repository
resource "aws_ecr_repository" "ecr_repo" {
  name = "eks-ecr-repo"
}