terraform {
  required_version = "0.12.28"
}

provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// S3
//
data "aws_s3_bucket" "glue_job_sample_bucket" {
  bucket = "glue-job-sample-bucket"
}

///////////////////////////////////////////////////////////////////////////////
// Glue Crawler
//
resource "aws_glue_catalog_database" "amazon_reviews" {
  name = "amazon-reviews"
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
resource "aws_iam_role" "amazon_reviews_glue_crawler_role" {
  name               = "amazon-reviews-glue-crawler-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role_policy.json
}
resource "aws_iam_role_policy_attachment" "AWSGlueServiceRole" {
  role       = aws_iam_role.amazon_reviews_glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
data "aws_iam_policy_document" "full_access_glue_crawler_sample_bucket" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "${data.aws_s3_bucket.glue_job_sample_bucket.arn}",
      "${data.aws_s3_bucket.glue_job_sample_bucket.arn}/*"
    ]
  }
}
resource "aws_iam_policy" "full_access_glue_job_sample_bucket" {
  name   = "full-access-glue-job-sample-bucket"
  policy = data.aws_iam_policy_document.full_access_glue_crawler_sample_bucket.json
}
resource "aws_iam_role_policy_attachment" "full_access_glue_crawler_sample_bucket" {
  role       = aws_iam_role.amazon_reviews_glue_crawler_role.name
  policy_arn = aws_iam_policy.full_access_glue_job_sample_bucket.arn
}
resource "aws_glue_classifier" "amazon_reviews_classifier" {
  name = "amazon-reviews-classifier"

  csv_classifier {
    allow_single_column    = false
    contains_header        = "PRESENT"
    delimiter              = "\t"
    disable_value_trimming = false
    quote_symbol           = "'"
  }
}
resource "aws_glue_crawler" "amazon_reviews_glue_crawler" {
  database_name = aws_glue_catalog_database.amazon_reviews.name
  name          = "amazon-reviews-glue-crawler"
  role          = aws_iam_role.amazon_reviews_glue_crawler_role.arn
  table_prefix  = "amazon-reviews-"
  classifiers   = [aws_glue_classifier.amazon_reviews_classifier.name]

  s3_target {
    path = "s3://${data.aws_s3_bucket.glue_job_sample_bucket.bucket}/input/"
  }

  // https://stackoverflow.com/questions/58034202/how-to-run-aws-glue-crawler-after-resource-update-created
  provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}"
    interpreter = ["bash.exe", "-c"]
  }
}
