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

# Create Route 53 record
resource "aws_route53_record" "eks_record" {
  zone_id = "EXAMPLE_ZONE_ID"
  name    = "eks.example.com"
  type    = "A"

  alias {
    name                   = aws_eks_cluster.eks_cluster.endpoint
    zone_id                = aws_eks_cluster.eks_cluster.zone_id
    evaluate_target_health = true
  }
}

# Create CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "eks-deployment-pipeline"
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
        RepositoryName = "eks-app-repo"
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
        ProjectName = "eks-app-build"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "EKS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = aws_eks_cluster.eks_cluster.name
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
  bucket = "eks-pipeline-artifacts"
}

# Create ECR repository
resource "aws_ecr_repository" "app_repo" {
  name = "eks-app-repo"
}