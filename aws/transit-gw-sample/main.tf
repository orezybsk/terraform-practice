# TODO: internet gateway, nat gateway は vpc-a だけに作成する
# TODO: vpc をもう１つ追加して３つにする

terraform {
  required_version = "0.12.18"

  backend "s3" {
    bucket = "orezybsk-terraform-practice"
    key    = "aws/transit-gw-sample"
    region = "ap-northeast-1"
  }
}

// provider を明示しない場合、alias を持たない provider がデフォルトで利用される
provider "aws" {
  region = "ap-northeast-1"
}

// Linux AMI の検索
// https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/finding-an-ami.html
data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????.?-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
