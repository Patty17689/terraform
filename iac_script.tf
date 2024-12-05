# AWS Single Page Application Architecture

# This Terraform configuration sets up a serverless web application architecture on AWS
# It includes CloudFront for content delivery, S3 for static file hosting,
# API Gateway and Lambda for backend processing, DynamoDB for data storage,
# ElastiCache for caching, and Certificate Manager for SSL/TLS.

provider "aws" {
  region = "us-west-2"
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket = "my-spa-website-bucket"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

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
resource "aws_api_gateway_rest_api" "api" {
  name = "my-spa-api"
}

# Lambda function for /tickets endpoint
resource "aws_lambda_function" "tickets" {
  filename      = "tickets_lambda.zip"
  function_name = "tickets_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Lambda function for /shows endpoint
resource "aws_lambda_function" "shows" {
  filename      = "shows_lambda.zip"
  function_name = "shows_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Lambda function for /info endpoint
resource "aws_lambda_function" "info" {
  filename      = "info_lambda.zip"
  function_name = "info_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# DynamoDB table
resource "aws_dynamodb_table" "data" {
  name           = "my-spa-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ElastiCache cluster
resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "my-spa-cache"
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

# Attach policies to Lambda role (following least privilege principle)
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_s3_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_elasticache" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess"
  role       = aws_iam_role.lambda_role.name
}

# Certificate Manager (for custom domain SSL/TLS)
resource "aws_acm_certificate" "cert" {
  domain_name       = "example.com"
  validation_method = "DNS"
}

# Lambda Authorizer
resource "aws_lambda_function" "authorizer" {
  filename      = "authorizer_lambda.zip"
  function_name = "lambda_authorizer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "authorizer" {
  name                   = "lambda_authorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  authorizer_uri         = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.invocation_role.arn
}

# IAM role for API Gateway to invoke Lambda Authorizer
resource "aws_iam_role" "invocation_role" {
  name = "api_gateway_auth_invocation"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# Policy to allow API Gateway to invoke Lambda Authorizer
resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = aws_iam_role.invocation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.authorizer.arn
      }
    ]
  })
}