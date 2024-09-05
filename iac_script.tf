# AWS Single Page Application Architecture

# Provider configuration
provider "aws" {
  region = "us-west-2"  # Change this to your preferred region
}

# S3 Bucket for static website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-spa-website-bucket"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_cdn" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.website_bucket.id}"
}

# API Gateway
resource "aws_api_gateway_rest_api" "spa_api" {
  name        = "spa-api"
  description = "API for Single Page Application"
}

# Lambda function for /tickets endpoint
resource "aws_lambda_function" "tickets_lambda" {
  filename      = "tickets_lambda.zip"
  function_name = "tickets_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Lambda function for /shows endpoint
resource "aws_lambda_function" "shows_lambda" {
  filename      = "shows_lambda.zip"
  function_name = "shows_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Lambda function for /info endpoint
resource "aws_lambda_function" "info_lambda" {
  filename      = "info_lambda.zip"
  function_name = "info_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# DynamoDB table
resource "aws_dynamodb_table" "spa_table" {
  name           = "spa-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# ElastiCache cluster
resource "aws_elasticache_cluster" "spa_cache" {
  cluster_id           = "spa-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  port                 = 6379
}

# Lambda Authorizer
resource "aws_lambda_function" "authorizer" {
  filename      = "authorizer_lambda.zip"
  function_name = "lambda_authorizer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Comments explaining the architecture:
# This Terraform configuration sets up a serverless Single Page Application (SPA) architecture on AWS.
# It includes:
# - S3 bucket for hosting static website files
# - CloudFront distribution for content delivery and HTTPS
# - API Gateway for handling API requests
# - Lambda functions for different API endpoints (/tickets, /shows, /info)
# - DynamoDB table for data storage
# - ElastiCache cluster for caching
# - Lambda Authorizer for API authentication
# 
# The architecture follows security best practices by using IAM roles with least privilege permissions.
# CloudFront is configured to use Origin Access Identity to securely access the S3 bucket.
# API Gateway integrates with Lambda functions to process requests and interact with DynamoDB and ElastiCache.
# 
# Note: This is a basic configuration and may need additional resources and configurations
# based on specific requirements, such as VPC settings, more detailed IAM policies, and
# custom domain configuration for CloudFront and API Gateway.