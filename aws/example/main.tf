// AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY は環境変数に設定した
// terraform init
// terraform plan
// terraform apply
// terraform destroy

provider "aws" {
  region = "ap-northeast-1"
}

// filter の指定条件は
// https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/finding-an-ami.html
// の「例: 現在の Amazon Linux 2 AMI を検索する」参照。
data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_vpc" "tp-example-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "tp-example-vpc"
  }
}

resource "aws_subnet" "tp-example-subnet" {
  cidr_block        = "10.0.0.0/24"
  vpc_id            = aws_vpc.tp-example-vpc.id
  availability_zone = "ap-northeast-1b"

  tags = {
    Name = "tp-example-subnet"
  }
}

resource "aws_internet_gateway" "tp-example-inetgw" {
  vpc_id = aws_vpc.tp-example-vpc.id

  tags = {
    Name = "tp-example-inetgw"
  }
}

resource "aws_route_table" "tp-example-routetable" {
  vpc_id = aws_vpc.tp-example-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tp-example-inetgw.id
  }

  tags = {
    Name = "tp-example-routetable"
  }
}

resource "aws_route_table_association" "tp-example-routetable-assoc" {
  route_table_id = aws_route_table.tp-example-routetable.id
  subnet_id      = aws_subnet.tp-example-subnet.id
}

resource "aws_security_group" "tp-example-sg" {
  name   = "tp-example-sg"
  vpc_id = aws_vpc.tp-example-vpc.id

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "tp-example-ec2" {
  ami                         = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.tp-example-subnet.id
  vpc_security_group_ids      = [aws_security_group.tp-example-sg.id]
  associate_public_ip_address = true
  key_name                    = "orezybsk-keypair"

  user_data = <<EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd.service
  EOF

  tags = {
    Name = "tp-example-ec2"
  }
}

output "public_dns" {
  value = aws_instance.tp-example-ec2.public_dns
}
