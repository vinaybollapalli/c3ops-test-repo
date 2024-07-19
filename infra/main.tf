# Versions
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Providers 
provider "aws" {
  # assume_role {
  #   role_arn   = "arn:aws:iam::${var.aws_account_id}:role/terraform-automation"
  # }
  region = var.region
  # version = "5.48.0"
  profile = "default"
}

# Stat File
terraform {
  required_version = "1.5.7"
  backend "s3" {
    bucket = "cb-iac-terraform"
    key    = "accounts/cb-shared-services/terraform.tfstate"
    region = "us-east-1"
    #dynamodb_table = "cb-iac-terraform"
    #role_arn   = "arn:aws:iam:::role/terraform-automation"
  }
}

# Create a VPC in AWS part of region i.e. NV 
resource "aws_vpc" "cloudbinary_vpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = var.instance_tenancy
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name       = "cloudbinary_vpc"
    Created_By = "Terraform"
  }
}

# Create a Public-Subnet1 part of cloudbinary_vpc 
resource "aws_subnet" "cloudbinary_public_subnet1" {
  vpc_id                  = aws_vpc.cloudbinary_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name       = "cloudbinary_public_subnet1"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "cloudbinary_public_subnet2" {
  vpc_id                  = aws_vpc.cloudbinary_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name       = "cloudbinary_public_subnet2"
    created_by = "Terraform"
  }
}

resource "aws_subnet" "cloudbinary_private_subnet1" {
  vpc_id            = aws_vpc.cloudbinary_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name       = "cloudbinary_private_subnet1"
    created_by = "Terraform"
  }
}
resource "aws_subnet" "cloudbinary_private_subnet2" {
  vpc_id            = aws_vpc.cloudbinary_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name       = "cloudbinary_private_subnet2"
    created_by = "Terraform"
  }
}

# IGW
resource "aws_internet_gateway" "cloudbinary_igw" {
  vpc_id = aws_vpc.cloudbinary_vpc.id

  tags = {
    Name       = "cloudbinary_igw"
    Created_By = "Terraform"
  }
}

# RTB
resource "aws_route_table" "cloudbinary_rtb_public" {
  vpc_id = aws_vpc.cloudbinary_vpc.id

  tags = {
    Name       = "cloudbinary_rtb_public"
    Created_By = "Teerraform"
  }
}
resource "aws_route_table" "cloudbinary_rtb_private" {
  vpc_id = aws_vpc.cloudbinary_vpc.id

  tags = {
    Name       = "cloudbinary_rtb_private"
    Created_By = "Teerraform"
  }
}

# Create the internet Access 
resource "aws_route" "cloudbinary_rtb_igw" {
  route_table_id         = aws_route_table.cloudbinary_rtb_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cloudbinary_igw.id

}

resource "aws_route_table_association" "cloudbinary_subnet_association1" {
  subnet_id      = aws_subnet.cloudbinary_public_subnet1.id
  route_table_id = aws_route_table.cloudbinary_rtb_public.id
}
resource "aws_route_table_association" "cloudbinary_subnet_association2" {
  subnet_id      = aws_subnet.cloudbinary_public_subnet2.id
  route_table_id = aws_route_table.cloudbinary_rtb_public.id
}
resource "aws_route_table_association" "cloudbinary_subnet_association3" {
  subnet_id      = aws_subnet.cloudbinary_private_subnet1.id
  route_table_id = aws_route_table.cloudbinary_rtb_private.id
}
resource "aws_route_table_association" "cloudbinary_subnet_association4" {
  subnet_id      = aws_subnet.cloudbinary_private_subnet2.id
  route_table_id = aws_route_table.cloudbinary_rtb_private.id
}

# Elastic Ipaddress for NAT Gateway
resource "aws_eip" "cloudbinary_eip" {
  vpc = true
}

# Create Nat Gateway 
resource "aws_nat_gateway" "cloudbinary_gw" {
  allocation_id = aws_eip.cloudbinary_eip.id
  subnet_id     = aws_subnet.cloudbinary_public_subnet1.id

  tags = {
    Name      = "Nat Gateway"
    Createdby = "Terraform"
  }
}

# Allow internet access from NAT Gateway to Private Route Table
resource "aws_route" "cloudbinary_rtb_private_gw" {
  route_table_id         = aws_route_table.cloudbinary_rtb_private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.cloudbinary_gw.id
}

# Network Access Control List 
resource "aws_network_acl" "cloudbinary_nsg" {
  vpc_id = aws_vpc.cloudbinary_vpc.id
  subnet_ids = [
    "${aws_subnet.cloudbinary_public_subnet1.id}",
    "${aws_subnet.cloudbinary_public_subnet2.id}",
    "${aws_subnet.cloudbinary_private_subnet1.id}",
    "${aws_subnet.cloudbinary_private_subnet2.id}"
  ]

  # Allow ingress of ports from 1024 to 65535
  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  # Allow egress of ports from 1024 to 65535
  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  tags = {
    Name      = "cloudbinary_nsg"
    createdby = "Terraform"
  }
}

# EC2 instance Security group
resource "aws_security_group" "cloudbinary_linux_sg" {
  vpc_id      = aws_vpc.cloudbinary_vpc.id
  name        = "cloudbinary_linux_sg"
  description = "To Allow SSH From IPV4 Devices"

  # Allow Ingress / inbound Of port 22 
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  # Allow Ingress / inbound Of port 8080 
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
  }
  # Allow egress / outbound of all ports 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudbinary_sg_bastion"
    Description = "cloudbinary allow SSH - RDP"
    createdby   = "terraform"
  }

}

# EC2 instance Security group
resource "aws_security_group" "cloudbinary_web_sg" {
  vpc_id      = aws_vpc.cloudbinary_vpc.id
  name        = "cloudbinary_web_sg"
  description = "To Allow SSH From IPV4 Devices"

  # Allow Ingress / inbound Of port 22 
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  # Allow Ingress / inbound Of port 80 
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  # Allow Ingress / inbound Of port 8080 
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
  }
  # Allow egress / outbound of all ports 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudbinary_sg"
    Description = "cloudbinary allow SSH - HTTP and Jenkins"
    createdby   = "terraform"
  }

}

# Bastion - Windows 
resource "aws_instance" "cloudbinary_web" {
  ami                    = "ami-0d86c69530d0a048e"
  instance_type          = "t2.micro"
  key_name               = "cb_nv_9am"
  subnet_id              = aws_subnet.cloudbinary_public_subnet1.id
  vpc_security_group_ids = ["${aws_security_group.cloudbinary_linux_sg.id}"]
  tags = {
    Name      = "cloudbinary_Bastion"
    CreatedBy = "Terraform"
  }
}

# WebServer - Private Subnet 
resource "aws_instance" "cloudbinary_app" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  key_name               = "cb_nv_9am"
  subnet_id              = aws_subnet.cloudbinary_private_subnet1.id
  vpc_security_group_ids = ["${aws_security_group.cloudbinary_web_sg.id}"]
  #user_data              = file("/Users/ck/repos/c3ops-java-project/scripts/web.sh")
  tags = {
    Name      = "cloudbinary_webserver"
    CreatedBy = "Terraform"
  }
}

output "vpc_id" {
  value = aws_vpc.cloudbinary_vpc.id
}