terraform {
  required_version = "0.12.28"
}

provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// Glue Job
//
data "aws_iam_role" "amazon_reviews_glue_crawler_role" {
  name = "amazon-reviews-glue-crawler-role"
}
data "aws_s3_bucket" "glue_job_sample_bucket" {
  bucket = "glue-job-sample-bucket"
}
locals {
  amazon_reviews_partition_glue_job_py_location = format("s3://%s/script/amazon_reviews_partition_glue_job.py"
    , data.aws_s3_bucket.glue_job_sample_bucket.bucket
  )
}

resource "null_resource" "upload_script" {
  provisioner "local-exec" {
    command = format("aws s3 cp amazon_reviews_partition_glue_job.py %s"
      , local.amazon_reviews_partition_glue_job_py_location
    )
    interpreter = ["bash.exe", "-c"]
  }
}
resource "aws_glue_job" "amazon_reviews_partition_glue_job" {
  depends_on   = [null_resource.upload_script]
  name         = "amazon-reviews-partition-glue-job"
  role_arn     = data.aws_iam_role.amazon_reviews_glue_crawler_role.arn
  max_capacity = 2

  command {
    script_location = local.amazon_reviews_partition_glue_job_py_location
  }
}
// https://docs.aws.amazon.com/cli/latest/reference/glue/start-job-run.html
// resource "aws_glue_job" "amazon_reviews_glue_job" { ... } の中に provisioner "local-exec" { ... } を書いても
// うまく実行できなかったので外に出した
resource "null_resource" "start_glue_job" {
  depends_on = [aws_glue_job.amazon_reviews_partition_glue_job]
  provisioner "local-exec" {
    command     = format("aws glue start-job-run --job-name %s", aws_glue_job.amazon_reviews_partition_glue_job.name)
    interpreter = ["bash.exe", "-c"]
  }
}
