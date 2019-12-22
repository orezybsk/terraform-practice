resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-a"
  }
}

resource "aws_subnet" "public_a_0" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public_a_0" {
  vpc_id = aws_vpc.vpc_a.id
}

resource "aws_route_table_association" "public_a_0" {
  subnet_id      = aws_subnet.public_a_0.id
  route_table_id = aws_route_table.public_a_0.id
}

resource "aws_security_group" "security_group_a" {
  name   = "security-group-a"
  vpc_id = aws_vpc.vpc_a.id

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2-a" {
  ami                         = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a_0.id
  vpc_security_group_ids      = [aws_security_group.security_group_a.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_for_ssm.name

  user_data = <<EOF
    #!/bin/bash
    yum -y update
  EOF

  tags = {
    Name = "ec2-a"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  vpc_id             = aws_vpc.vpc_a.id
  subnet_ids         = [aws_subnet.public_a_0.id]
  transit_gateway_id = aws_ec2_transit_gateway.example.id
}
resource "aws_route" "public_a_0_transit_gw" {
  route_table_id         = aws_route_table.public_a_0.id
  transit_gateway_id     = aws_ec2_transit_gateway.example.id
  destination_cidr_block = "10.0.0.0/8"
}

resource "aws_internet_gateway" "vpc_a" {
  vpc_id = aws_vpc.vpc_a.id
}
resource "aws_route" "public_a_0_internet_gw" {
  route_table_id         = aws_route_table.public_a_0.id
  gateway_id             = aws_internet_gateway.vpc_a.id
  destination_cidr_block = "0.0.0.0/0"
}
