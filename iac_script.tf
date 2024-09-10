# AWS Single Page Application Architecture

# This Terraform configuration sets up a serverless architecture for a Single Page Application (SPA)
# using various AWS services. The architecture includes CloudFront for content delivery,
# S3 for static file hosting, API Gateway and Lambda for backend processing,
# DynamoDB for data storage, and ElastiCache for caching.

provider "aws" {
  region = "us-west-2"
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-spa-website-bucket"
  acl    = "private"

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
    cloudfront_default_certificate = true
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "spa_api" {
  name        = "spa-api"
  description = "API for SPA backend"
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

# IAM policy for Lambda to access DynamoDB and ElastiCache
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Custom policy for DynamoDB and ElastiCache access
resource "aws_iam_role_policy" "lambda_dynamodb_elasticache_policy" {
  name = "lambda_dynamodb_elasticache_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.spa_table.arn
      },
      {
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output the CloudFront distribution domain name
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.website_cdn.domain_name
}