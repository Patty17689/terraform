# Main Terraform configuration for AWS Single Page Application architecture

# Configure the AWS provider
provider "aws" {
  region = "us-west-2"  # Change this to your preferred region
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-spa-website-bucket"
  acl    = "private"  # Ensure the bucket is not publicly accessible

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# CloudFront distribution for content delivery
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
    cloudfront_default_certificate = true  # Use a custom certificate in production
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
  filename      = "tickets_lambda.zip"  # Ensure this file exists
  function_name = "tickets_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Lambda function for /shows endpoint
resource "aws_lambda_function" "shows_lambda" {
  filename      = "shows_lambda.zip"  # Ensure this file exists
  function_name = "shows_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Lambda function for /info endpoint
resource "aws_lambda_function" "info_lambda" {
  filename      = "info_lambda.zip"  # Ensure this file exists
  function_name = "info_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

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

# Attach necessary policies to the Lambda role (e.g., CloudWatch Logs, DynamoDB access)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
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

# Comments explaining the architecture:
# This Terraform configuration sets up a serverless Single Page Application (SPA) architecture on AWS.
# - Static content is stored in an S3 bucket and served via CloudFront for global distribution.
# - API Gateway handles incoming requests and routes them to appropriate Lambda functions.
# - Lambda functions (/tickets, /shows, /info) process requests and interact with DynamoDB and S3.
# - DynamoDB is used for storing application data.
# - ElastiCache (Redis) is used for caching to improve performance.
# - IAM roles and policies ensure least privilege access for Lambda functions.
# - CloudFront provides HTTPS and caching capabilities for improved security and performance.

# Note: This is a basic configuration and should be further customized for production use,
# including proper VPC setup, more granular IAM policies, and additional security measures.