terraform {
  required_version = "0.12.28"
}

provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// S3
//
resource "aws_s3_bucket" "glue_job_sample_bucket" {
  bucket        = "glue-job-sample-bucket"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "glue_job_sample_bucket" {
  bucket                  = aws_s3_bucket.glue_job_sample_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  provisioner "local-exec" {
    command = format("aws s3 cp amazon_reviews_us_Camera_v1_00.tsv s3://%s/input/amazon_reviews_us_Camera_v1_00.tsv"
      , aws_s3_bucket.glue_job_sample_bucket.bucket
    )
    interpreter = ["bash.exe", "-c"]
  }
}
