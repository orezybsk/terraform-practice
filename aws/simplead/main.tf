terraform {
  required_version = "0.12.21"
}

provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// VPC
//
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

///////////////////////////////////////////////////////////////////////////////
// Internet Gateway
//
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

///////////////////////////////////////////////////////////////////////////////
// Route Table
//
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id
}
resource "aws_route" "example" {
  route_table_id         = aws_route_table.example.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

///////////////////////////////////////////////////////////////////////////////
// Subnet (public_0)
//
resource "aws_subnet" "public_0" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1b"

  tags = {
    Name = "${var.project_name}-public-0"
  }
}
resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.example.id
}

///////////////////////////////////////////////////////////////////////////////
// Subnet (public_1)
//
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.project_name}-public-1"
  }
}
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.example.id
}

///////////////////////////////////////////////////////////////////////////////
// SimpleAD
//
resource "aws_directory_service_directory" "bar" {
  name     = "example.local"
  password = "SuperSecretPassw0rd"
  type     = "SimpleAD"
  size     = "Small"

  vpc_settings {
    vpc_id     = aws_vpc.example.id
    subnet_ids = [aws_subnet.public_0.id, aws_subnet.public_1.id]
  }

  tags = {
    Project = "${var.project_name}"
  }
}
