terraform {
  required_version = "0.12.28"
}

provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// S3
//
resource "aws_s3_bucket" "glue_crawler_sample_bucket" {
  bucket        = "glue-crawler-sample-bucket"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "glue_crawler_sample_bucket" {
  bucket                  = aws_s3_bucket.glue_crawler_sample_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  provisioner "local-exec" {
    command     = format("aws s3 cp salesdata.csv s3://%s/input/salesdata.csv", aws_s3_bucket.glue_crawler_sample_bucket.bucket)
    interpreter = ["bash.exe", "-c"]
  }
}

///////////////////////////////////////////////////////////////////////////////
// Glue
//
resource "aws_glue_catalog_database" "salesdata" {
  depends_on = [aws_s3_bucket_public_access_block.glue_crawler_sample_bucket]
  name       = "salesdata"
}
data "aws_iam_policy_document" "glue_assume_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "salesdata_glue_crawler_role" {
  name               = "salesdata-glue-crawler-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role_policy.json
}
resource "aws_iam_role_policy_attachment" "AWSGlueServiceRole" {
  role       = aws_iam_role.salesdata_glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
data "aws_iam_policy_document" "full_access_glue_crawler_sample_bucket" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.glue_crawler_sample_bucket.arn}",
      "${aws_s3_bucket.glue_crawler_sample_bucket.arn}/*"
    ]
  }
}
resource "aws_iam_policy" "full_access_glue_crawler_sample_bucket" {
  name   = "full_access_glue_athena_sample_bucket"
  policy = data.aws_iam_policy_document.full_access_glue_crawler_sample_bucket.json
}
resource "aws_iam_role_policy_attachment" "full_access_glue_crawler_sample_bucket" {
  role       = aws_iam_role.salesdata_glue_crawler_role.name
  policy_arn = aws_iam_policy.full_access_glue_crawler_sample_bucket.arn
}
resource "aws_glue_crawler" "salesdata_glue_crawler" {
  database_name = aws_glue_catalog_database.salesdata.name
  name          = "salesdata-glue-crawler"
  role          = aws_iam_role.salesdata_glue_crawler_role.arn
  table_prefix  = "salesdata-"

  s3_target {
    path = "s3://${aws_s3_bucket.glue_crawler_sample_bucket.bucket}/input/"
  }

  // https://stackoverflow.com/questions/58034202/how-to-run-aws-glue-crawler-after-resource-update-created
  provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}"
  }
}
