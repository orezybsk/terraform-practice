resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-a"
  }
}

resource "aws_subnet" "public_b_0" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
}
resource "aws_route_table" "public_b_0" {
  vpc_id = aws_vpc.vpc_b.id
}
resource "aws_route_table_association" "public_b_0" {
  subnet_id      = aws_subnet.public_b_0.id
  route_table_id = aws_route_table.public_b_0.id
}

resource "aws_subnet" "private_b_0" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}
resource "aws_route_table" "private_b_0" {
  vpc_id = aws_vpc.vpc_b.id
}
resource "aws_route_table_association" "private_b_0" {
  subnet_id      = aws_subnet.private_b_0.id
  route_table_id = aws_route_table.private_b_0.id
}

resource "aws_security_group" "security_group_b" {
  name   = "security-group-b"
  vpc_id = aws_vpc.vpc_b.id

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2-b" {
  ami                         = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_b_0.id
  vpc_security_group_ids      = [aws_security_group.security_group_b.id]
  associate_public_ip_address = false
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_for_ssm.name

  user_data = <<EOF
    #!/bin/bash
    yum -y update
    amazon-linux-extras install nginx1
    systemctl enable nginx.service
    systemctl start nginx.service
  EOF

  tags = {
    Name = "ec2-b"
  }
}

resource "aws_internet_gateway" "vpc_b" {
  vpc_id = aws_vpc.vpc_b.id
}
resource "aws_route" "public_b_0" {
  route_table_id         = aws_route_table.public_b_0.id
  gateway_id             = aws_internet_gateway.vpc_b.id
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_eip" "nat_gateway_b_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.vpc_b]
}
resource "aws_nat_gateway" "nat_gateway_b_0" {
  allocation_id = aws_eip.nat_gateway_b_0.id
  subnet_id     = aws_subnet.public_b_0.id
  depends_on    = [aws_internet_gateway.vpc_b]
}
resource "aws_route" "private_b_0" {
  route_table_id         = aws_route_table.private_b_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_b_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_security_group" "security_group_b_vpc_endpoint" {
  name   = "security_group_b_vpc_endpoint"
  vpc_id = aws_vpc.vpc_b.id

  ingress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_vpc_endpoint" "vpc_b_ssm_vpcgw" {
  vpc_id              = aws_vpc.vpc_b.id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  // vpc_endpoint_type = "Interface" の時は route_table_ids は設定できないので
  // subnet_ids を設定する
  subnet_ids         = [aws_subnet.private_b_0.id]
  security_group_ids = [aws_security_group.security_group_b_vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "vpc_b_ec2messages_vpcgw" {
  vpc_id              = aws_vpc.vpc_b.id
  service_name        = "com.amazonaws.ap-northeast-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_b_0.id]
  security_group_ids  = [aws_security_group.security_group_b_vpc_endpoint.id]
}
resource "aws_vpc_endpoint" "vpc_b_ssmmessages_vpcgw" {
  vpc_id              = aws_vpc.vpc_b.id
  service_name        = "com.amazonaws.ap-northeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_b_0.id]
  security_group_ids  = [aws_security_group.security_group_b_vpc_endpoint.id]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b" {
  vpc_id             = aws_vpc.vpc_b.id
  subnet_ids         = [aws_subnet.private_b_0.id]
  transit_gateway_id = aws_ec2_transit_gateway.example.id
}
resource "aws_route" "vpc_b" {
  route_table_id         = aws_route_table.private_b_0.id
  transit_gateway_id     = aws_ec2_transit_gateway.example.id
  destination_cidr_block = "10.0.0.0/8"
}
