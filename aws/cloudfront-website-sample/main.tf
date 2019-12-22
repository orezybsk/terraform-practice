// 【速報】TerraformがCloudFrontに対応しました
// https://dev.classmethod.jp/cloud/aws/terraform-v0-6-15-supports-cloudfront/
// terrafromでaws acm作成 cloudfrontの場合バージニアで作成しないといけないんだけどどうやるの？
// https://qiita.com/tos-miyake/items/f0e5f28f2a69e4d39422

// Terraform Settings
// https://www.terraform.io/docs/configuration/terraform.html
terraform {
  required_version = "0.12.18"
  required_providers {
    aws = "2.42.0"
  }

  backend "s3" {
    bucket = "orezybsk-terraform-practice"
    key    = "aws/cloudfront-website-sample"
    region = "ap-northeast-1"
  }
}

// provider を明示しない場合、alias を持たない provider がデフォルトで利用される
provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}


///////////////////////////////////////////////////////////////////////////////
// Route53 の Public Zone
// ※Route53 でドメインを取得したので作成済、resource ではなく data で定義する
//
data "aws_route53_zone" "dns_zone_apex" {
  name = var.dns_zone_apex
}


///////////////////////////////////////////////////////////////////////////////
// Route53 に Public Subdomain Zone を作成する
//
resource "aws_route53_zone" "dns_sub_domain_www" {
  name = var.dns_sub_domain_www
}


///////////////////////////////////////////////////////////////////////////////
// ACM で SSL証明書を発行する
//
resource "aws_acm_certificate" "dns_zone_apex" {
  domain_name               = data.aws_route53_zone.dns_zone_apex.name
  subject_alternative_names = ["*.${var.dns_zone_apex}"]
  validation_method         = "DNS"
  provider                  = aws.virginia

  lifecycle {
    create_before_destroy = true
  }
}

// TODO: 下の記述だと SSL証明書の発行完了まで待てていない時がある
resource "aws_route53_record" "dns_zone_apex_certificate" {
  name    = aws_acm_certificate.dns_zone_apex.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.dns_zone_apex.domain_validation_options.0.resource_record_type
  records = [aws_acm_certificate.dns_zone_apex.domain_validation_options.0.resource_record_value]
  zone_id = data.aws_route53_zone.dns_zone_apex.id
  ttl     = 60
}


///////////////////////////////////////////////////////////////////////////////
// Web サイトのコンテンツを入れる S3 Bucket を作成する
//
resource "aws_s3_bucket" "content_bucket" {
  bucket = var.s3_content_bucket_name
  acl    = "private"

  // コンテンツがアップロードされていても S3 Bucket を削除できるようにする
  force_destroy = true
}


///////////////////////////////////////////////////////////////////////////////
// CloudFront Distribution を作成する
//
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
}

data "aws_iam_policy_document" "cf_to_s3_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "${aws_s3_bucket.content_bucket.arn}",
      "${aws_s3_bucket.content_bucket.arn}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cf_to_s3" {
  bucket = aws_s3_bucket.content_bucket.id
  policy = data.aws_iam_policy_document.cf_to_s3_policy.json
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.content_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.content_bucket.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled         = true
  is_ipv6_enabled = false
  comment         = "comment"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.content_bucket.bucket_domain_name
    prefix          = "prefix"
  }

  aliases = [var.dns_zone_apex, var.dns_sub_domain_www]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.content_bucket.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  // Amazon CloudFront の料金
  // https://aws.amazon.com/jp/cloudfront/pricing/
  // の中の「価格クラス」参照
  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.dns_zone_apex.arn
    // vip を指定すると 600USD/月 かかる
    ssl_support_method  = "sni-only"
  }
}


///////////////////////////////////////////////////////////////////////////////
// Route53 にドメインを登録する
//
resource "aws_route53_record" "dns_zone_apex" {
  zone_id = data.aws_route53_zone.dns_zone_apex.zone_id
  name    = data.aws_route53_zone.dns_zone_apex.name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "dns_sub_domain_www" {
  zone_id = data.aws_route53_zone.dns_zone_apex.zone_id
  name    = aws_route53_zone.dns_sub_domain_www.name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
