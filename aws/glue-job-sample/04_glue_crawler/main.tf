terraform {
  required_version = "0.12.28"
}

provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// Glue Crawler
//

data "aws_iam_role" "amazon_reviews_glue_crawler_role" {
  name = "amazon-reviews-glue-crawler-role"
}
data "aws_s3_bucket" "glue_job_sample_bucket" {
  bucket = "glue-job-sample-bucket"
}

resource "aws_glue_crawler" "amazon_reviews_output_glue_crawler" {
  database_name = "amazon-reviews"
  name          = "amazon-reviews-output-glue-crawler"
  role          = data.aws_iam_role.amazon_reviews_glue_crawler_role.arn
  table_prefix  = "amazon-reviews-"

  s3_target {
    path = "s3://${data.aws_s3_bucket.glue_job_sample_bucket.bucket}/output/"
  }

  // https://stackoverflow.com/questions/58034202/how-to-run-aws-glue-crawler-after-resource-update-created
  provisioner "local-exec" {
    command     = "aws glue start-crawler --name ${self.name}"
    interpreter = ["bash.exe", "-c"]
  }
}
