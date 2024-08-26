# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"  # You can change this to your preferred region
}

# Create an S3 bucket
resource "aws_s3_bucket" "patdemo" {
  bucket = "patdemo"
}